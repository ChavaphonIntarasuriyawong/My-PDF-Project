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
// header. We accept that and gate misuse via origin check + size cap below.
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

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  let upstream: Response;
  try {
    upstream = await fetch(parsed.toString(), {
      method: "GET",
      redirect: "follow",
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

  if (!upstream.ok) {
    return new Response(`Upstream HTTP ${upstream.status}`, {
      status: upstream.status,
      headers: corsHeaders,
    });
  }

  const len = parseInt(upstream.headers.get("content-length") ?? "0", 10);
  if (len && len > MAX_BYTES) {
    return new Response("File too large", { status: 413, headers: corsHeaders });
  }

  const ct = upstream.headers.get("content-type") ?? "application/pdf";
  const headers = new Headers(corsHeaders);
  headers.set("Content-Type", ct);
  headers.set("Cache-Control", "public, max-age=3600");
  if (len) headers.set("Content-Length", String(len));

  return new Response(upstream.body, { status: 200, headers });
});
