import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Supabase Edge Function that proxies external PDF URLs and adds the
/// `Access-Control-Allow-Origin` header the browser needs. Set after
/// deploying `supabase/functions/pdf-proxy/index.ts` (see file header).
/// Leave empty to disable proxying — web will refuse non-Supabase URLs.
/// Format: `https://<project-ref>.supabase.co/functions/v1/pdf-proxy`
const String kCorsProxyBase =
    'https://wtjwmwisitohlzyinoaf.supabase.co/functions/v1/pdf-proxy';

bool isCorsFriendlyHost(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.supabase.co/') || lower.contains('.supabase.in/');
}

/// Fetches PDF bytes, routing through the CORS proxy on web for external
/// hosts. Mobile fetches direct (no CORS). Throws on non-200.
Future<http.Response> fetchPdfBytes(String url) async {
  if (!kIsWeb || isCorsFriendlyHost(url)) {
    final resp = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 180));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    return resp;
  }
  if (kCorsProxyBase.isEmpty) {
    throw Exception(
      'External PDF links can\'t be read on web yet (CORS proxy not configured). '
      'Upload the file instead, or open the book on the mobile app.',
    );
  }
  final proxyUrl = '$kCorsProxyBase?url=${Uri.encodeQueryComponent(url)}';
  final resp = await http
      .get(Uri.parse(proxyUrl))
      .timeout(const Duration(seconds: 180));
  if (resp.statusCode != 200) {
    throw Exception(
      'Proxy HTTP ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 200))}',
    );
  }
  return resp;
}
