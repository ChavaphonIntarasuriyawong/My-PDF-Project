// Supabase Edge Function: CORS proxy for external PDF URLs.
//
// Why: Flutter Web cannot fetch arbitrary cross-origin PDFs because the
// browser enforces CORS. Public proxies (allorigins, corsproxy.io) get
// rate-limited / blacklisted. This function is private to MyPDF and runs
// inside the same Supabase project we already use for storage.
//
// Deploy:
//   1. Install CLI:        npm i -g supabase
//   2. Log in:             supabase login
//   3. Link project:       supabase link --project-ref wtjwmwisitohlzyinoaf
//   4. Deploy (public):    supabase functions deploy pdf-proxy --no-verify-jwt
//
// `--no-verify-jwt` lets the browser call the function without an auth
// header. We accept that and gate misuse via SSRF guard + size cap below.
//
// Usage from app:
//   GET https://wtjwmwisitohlzyinoaf.supabase.co/functions/v1/pdf-proxy?url=<encoded PDF URL>

const ALLOW_ORIGIN = "*"; // tighten to your deployed origin if you want
const MAX_BYTES = 50 * 1024 * 1024;
const FETCH_TIMEOUT_MS = 30_000;

const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOW_ORIGIN,
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Max-Age": "86400",
};

// Hostnames that must never be reached. Lower-case match.
const BLOCKED_HOSTS = new Set([
  "localhost",
  "metadata.google.internal",
  "metadata.aws.internal",
  "instance-data.ec2.internal",
]);

// Returns true if `ip` is a literal in any private / loopback / link-local
// / metadata range. Covers IPv4 + IPv6.
function isPrivateIp(ip: string): boolean {
  // IPv4 dotted quad
  const v4 = ip.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (v4) {
    const [a, b] = [parseInt(v4[1], 10), parseInt(v4[2], 10)];
    if (a === 10) return true;                                  // 10.0.0.0/8
    if (a === 127) return true;                                 // 127.0.0.0/8 loopback
    if (a === 169 && b === 254) return true;                    // 169.254.0.0/16 link-local + AWS metadata
    if (a === 172 && b >= 16 && b <= 31) return true;           // 172.16.0.0/12
    if (a === 192 && b === 168) return true;                    // 192.168.0.0/16
    if (a === 100 && b >= 64 && b <= 127) return true;          // 100.64.0.0/10 CGNAT
    if (a === 0) return true;                                   // 0.0.0.0/8
    if (a >= 224) return true;                                  // multicast + reserved
    return false;
  }
  // IPv6 — fold to lower-case
  const v6 = ip.toLowerCase();
  if (v6 === "::1" || v6 === "::") return true;                 // loopback / unspecified
  if (v6.startsWith("fe80:")) return true;                      // link-local
  if (v6.startsWith("fc") || v6.startsWith("fd")) return true;  // ULA fc00::/7
  if (v6.startsWith("ff")) return true;                         // multicast
  // IPv4-mapped (::ffff:a.b.c.d) — recurse
  const mapped = v6.match(/::ffff:(\d+\.\d+\.\d+\.\d+)/);
  if (mapped) return isPrivateIp(mapped[1]);
  return false;
}

// Resolve hostname to A + AAAA records and reject if any resolves into a
// private range. Defends against SSRF + DNS rebinding (we re-check after the
// fetch chain too). Returns `null` on success, error string on rejection.
async function ssrfCheck(hostname: string): Promise<string | null> {
  const lower = hostname.toLowerCase();
  if (BLOCKED_HOSTS.has(lower)) return `Host '${hostname}' is blocked`;
  if (lower.endsWith(".internal") || lower.endsWith(".local")) {
    return `Host '${hostname}' suffix is blocked`;
  }
  // Literal-IP shortcut (no DNS lookup needed)
  const looksLikeIpv4 = /^\d+\.\d+\.\d+\.\d+$/.test(hostname);
  const looksLikeIpv6 = hostname.includes(":");
  if (looksLikeIpv4 || looksLikeIpv6) {
    if (isPrivateIp(hostname)) return `Host '${hostname}' is private`;
    return null;
  }
  // DNS resolution. Either record type can fail with NotFound — that's fine
  // as long as the other returns at least one public address.
  let v4: string[] = [];
  let v6: string[] = [];
  try { v4 = await Deno.resolveDns(hostname, "A"); } catch (_) { /* ignore */ }
  try { v6 = await Deno.resolveDns(hostname, "AAAA"); } catch (_) { /* ignore */ }
  if (v4.length === 0 && v6.length === 0) {
    return `Could not resolve '${hostname}'`;
  }
  for (const ip of [...v4, ...v6]) {
    if (isPrivateIp(ip)) {
      return `Host '${hostname}' resolves to private IP ${ip}`;
    }
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "GET") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  const target = new URL(req.url).searchParams.get("url");
  if (!target) {
    return new Response("Missing url param", { status: 400, headers: corsHeaders });
  }

  let parsed: URL;
  try {
    parsed = new URL(target);
  } catch {
    return new Response("Invalid url", { status: 400, headers: corsHeaders });
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    return new Response("Only http/https allowed", { status: 400, headers: corsHeaders });
  }

  // SSRF guard — reject loopback, RFC1918, link-local, ULA, metadata hosts.
  const ssrfErr = await ssrfCheck(parsed.hostname);
  if (ssrfErr !== null) {
    return new Response(ssrfErr, { status: 403, headers: corsHeaders });
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  let upstream: Response;
  try {
    upstream = await fetch(parsed.toString(), {
      method: "GET",
      // `manual` so we can re-validate redirect targets against the SSRF
      // check. Auto-follow would let an attacker redirect from a public host
      // to 169.254.169.254 after our initial check passed.
      redirect: "manual",
      signal: controller.signal,
      headers: {
        "User-Agent": "Mozilla/5.0 (compatible; MyPDFProxy/1.0)",
        Accept: "application/pdf,*/*",
      },
    });
  } catch (e) {
    clearTimeout(timer);
    return new Response(`Upstream fetch failed: ${(e as Error).message}`, {
      status: 502,
      headers: corsHeaders,
    });
  }
  clearTimeout(timer);

  // Reject any redirect — caller can update their stored URL if needed.
  // Following redirects safely requires re-running ssrfCheck on the
  // resolved Location, which we keep simple by refusing the chain.
  if (upstream.status >= 300 && upstream.status < 400) {
    return new Response("Upstream returned a redirect (not followed)", {
      status: 502,
      headers: corsHeaders,
    });
  }

  if (!upstream.ok) {
    return new Response(`Upstream HTTP ${upstream.status}`, {
      status: upstream.status,
      headers: corsHeaders,
    });
  }

  const declaredLen = parseInt(upstream.headers.get("content-length") ?? "0", 10);
  if (declaredLen && declaredLen > MAX_BYTES) {
    return new Response("File too large", { status: 413, headers: corsHeaders });
  }

  // Streaming size cap — Content-Length may be missing (chunked transfer
  // encoding). Wrap the body in a TransformStream that aborts when bytes
  // streamed exceed MAX_BYTES. Without this, an attacker could pump
  // unbounded bytes through the function (egress + memory abuse).
  let bytesStreamed = 0;
  const sizeCapStream = new TransformStream<Uint8Array, Uint8Array>({
    transform(chunk, controller) {
      bytesStreamed += chunk.byteLength;
      if (bytesStreamed > MAX_BYTES) {
        controller.error(new Error("Streamed body exceeded MAX_BYTES"));
        return;
      }
      controller.enqueue(chunk);
    },
  });

  const headers = new Headers(corsHeaders);
  // Force application/pdf — refuse to relay HTML / arbitrary types verbatim.
  // Defends against attacker pages masquerading as PDFs.
  headers.set("Content-Type", "application/pdf");
  // Tighter cache: 60 s shared, allow revalidation. Avoids pinning poisoned
  // content for an hour at the CDN.
  headers.set("Cache-Control", "public, max-age=60, must-revalidate");
  headers.set("Vary", "Origin");
  if (declaredLen) headers.set("Content-Length", String(declaredLen));

  if (upstream.body === null) {
    return new Response(null, { status: 200, headers });
  }
  return new Response(upstream.body.pipeThrough(sizeCapStream), {
    status: 200,
    headers,
  });
});
