import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/core/network/pdf_fetcher.dart';

/// Pure-Dart unit tests for the host classification helper that drives the
/// mobile-vs-web routing fork in `fetchPdfBytes`. We do NOT exercise the live
/// `fetchPdfBytes` here — `flutter_test` blocks real network calls and the
/// production helper takes its `http.Client` from the package-level `http.get`
/// (no injection seam). Coverage of the network path lives in manual QA per
/// docs/projectscope.md. The classification fork itself is the only piece we
/// can hermetically reach, so we lock its truth table down here.
void main() {
  group('isCorsFriendlyHost', () {
    group('Supabase hosts (CORS-friendly, fetched direct on web)', () {
      test('matches .supabase.co with path', () {
        expect(
          isCorsFriendlyHost('https://abc.supabase.co/storage/v1/object/pdfs/file.pdf'),
          isTrue,
        );
      });

      test('matches .supabase.in with path', () {
        expect(
          isCorsFriendlyHost('https://abc.supabase.in/storage/v1/object/pdfs/file.pdf'),
          isTrue,
        );
      });

      test('matches uppercase host (case-insensitive)', () {
        expect(
          isCorsFriendlyHost('https://ABC.SUPABASE.CO/path/to/file.pdf'),
          isTrue,
        );
      });

      test('matches mixed-case host', () {
        expect(
          isCorsFriendlyHost('https://Abc.Supabase.Co/path/file.pdf'),
          isTrue,
        );
      });

      test('matches Edge Function URL on supabase.co', () {
        // The proxy itself lives on supabase.co — verify it classifies as
        // CORS-friendly so we don't double-proxy.
        expect(
          isCorsFriendlyHost('https://wtjwmwisitohlzyinoaf.supabase.co/functions/v1/pdf-proxy?url=x'),
          isTrue,
        );
      });

      test('matches deep-nested storage path', () {
        expect(
          isCorsFriendlyHost(
              'https://project-ref.supabase.co/storage/v1/object/public/pdfs/u1/123_abc.pdf'),
          isTrue,
        );
      });
    });

    group('External hosts (need proxy on web)', () {
      test('arxiv.org is external', () {
        expect(
          isCorsFriendlyHost('https://arxiv.org/pdf/2401.00001v1.pdf'),
          isFalse,
        );
      });

      test('drive.google.com is external', () {
        expect(
          isCorsFriendlyHost('https://drive.google.com/uc?export=download&id=abc'),
          isFalse,
        );
      });

      test('cdn.example.org is external', () {
        expect(
          isCorsFriendlyHost('https://cdn.example.org/files/whitepaper.pdf'),
          isFalse,
        );
      });

      test('bare http URL on external host is external', () {
        expect(
          isCorsFriendlyHost('http://example.com/file.pdf'),
          isFalse,
        );
      });
    });

    group('Adversarial / lookalike hosts (must NOT match)', () {
      test('supabase.co.attacker.com is not classified as Supabase', () {
        // The test relies on the trailing `/` in the literal `.supabase.co/`.
        // A spoofed host like `supabase.co.attacker.com/path` would have the
        // path start with `/` after the domain — we want to confirm the
        // matching does NOT inadvertently allow this. The current helper is
        // a `contains` check, so this DOES match (security note below).
        // We capture the current behavior so any tightening is visible.
        final url = 'https://supabase.co.attacker.com/file.pdf';
        // Today this returns true because the substring `.supabase.co/` doesn't
        // appear. Confirm.
        expect(
          isCorsFriendlyHost(url),
          isFalse,
          reason: 'spoofed host without `.supabase.co/` substring stays external',
        );
      });

      test('host containing literal ".supabase.co" without trailing slash', () {
        // E.g. a query string trick like `https://example.com?x=.supabase.co/`
        // — this currently MATCHES because the helper is a substring check. We
        // intentionally encode the current behavior (loose match) so that any
        // future tightening produces a visible diff in this test.
        final url = 'https://example.com/?ref=.supabase.co/';
        expect(
          isCorsFriendlyHost(url),
          isTrue,
          reason: 'documented current behavior — substring match treats query '
              'strings the same as hosts; tighten to URI parsing if any flow '
              'starts trusting this output for security boundaries',
        );
      });

      test('empty url is external (false)', () {
        expect(isCorsFriendlyHost(''), isFalse);
      });

      test('local:// URL is external (false)', () {
        // local:// is rejected upstream by `pdfPathProvider`, but the
        // classification helper still gets called on the raw string.
        expect(isCorsFriendlyHost('local://abc.pdf'), isFalse);
      });
    });
  });

  group('kCorsProxyBase configuration', () {
    test('is set to a Supabase Edge Function URL or empty string', () {
      // Either configured (deploy-time string) or empty (proxy disabled).
      // Reject any other shape so a half-edited URL is caught at test time.
      if (kCorsProxyBase.isEmpty) return;
      expect(kCorsProxyBase, startsWith('https://'));
      expect(kCorsProxyBase, contains('.supabase.co/functions/v1/'));
      expect(kCorsProxyBase, endsWith('pdf-proxy'));
    });

    test('proxy URL itself classifies as CORS-friendly', () {
      // If proxy is configured, it must be on a Supabase host so the
      // direct-fetch fast-path inside `fetchPdfBytes` doesn't recurse
      // through the proxy back through itself.
      if (kCorsProxyBase.isEmpty) return;
      expect(isCorsFriendlyHost(kCorsProxyBase), isTrue);
    });
  });
}
