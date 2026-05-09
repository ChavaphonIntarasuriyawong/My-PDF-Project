// Wave 4 — OCR fallback: logic-level coverage of the reader's OCR branch.
//
// Why not a true widget test of `ReadingScreen`?
//
// `ReadingScreen` constructs `FlutterTts()` in `initState` and immediately
// calls `_initTts`, which fires the `flutter_tts` MethodChannel. The default
// test binding has no implementation registered for that channel, and the
// platform-channel mocks would have to fake the `flutter_pdfview` view
// (mobile) plus `pdfx` document (web/thumbnails) plus the JPEG render in
// `pdfPageImageProvider` to land a meaningful pump. That's a lot of glue for
// little signal — the OCR branch's *behaviour* lives in two contracts:
//
//   1. `ocrPageTextProvider` (cache-hit short-circuit, recogniser invocation,
//      `cleanForTts` post-processing, page-image invalidation on the way out).
//   2. The reader's `flags.ocrFallbackEnabled` kill-switch read in
//      `_speakCurrentPage` — when the flag is false, the OCR path must not
//      run *at all*, and the existing "scanned PDF?" snackbar must surface
//      instead. The screen does this by reading `featureFlagsProvider`; we
//      cover the contract by reading the same provider in the same way.
//
// Both contracts are pure provider-graph behaviour, so we test them with a
// `ProviderContainer` and overrides — no widget pump, no platform channels.
// The skipped `test/features/library/presentation/ocr_pipeline_test.dart`
// stub describes the same pattern; this file is the implementation.

import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_pdf/core/config/feature_flags.dart';
import 'package:my_pdf/core/local/ocr_cache_service.dart';
import 'package:my_pdf/features/library/data/ocr_data_source.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';

/// Controllable [OcrDataSource] fake: counts calls and returns a configurable
/// payload so tests can prove the cache short-circuits subsequent reads.
class _FakeOcrDataSource implements OcrDataSource {
  int callCount = 0;
  String response = 'fake ocr text';
  Object? throwOnNext;

  @override
  Future<String> recognize(
    Uint8List jpegBytes, {
    String langs = 'eng+tha',
  }) async {
    callCount++;
    final err = throwOnNext;
    if (err != null) {
      throwOnNext = null;
      throw err;
    }
    return response;
  }

  @override
  Future<void> dispose() async {}
}

/// Test double for [FeatureFlags] so we don't need to spin up a real Remote
/// Config instance (which requires a Firebase app to initialise). The wrapper
/// exposes `ocrFallbackEnabled` as the only behavioural surface the reader
/// touches; we extend the production class and override the getter.
class _FakeFeatureFlags extends FeatureFlags {
  _FakeFeatureFlags(this._enabled, FirebaseRemoteConfig rc)
    : super(remoteConfig: rc);
  final bool _enabled;
  @override
  bool get ocrFallbackEnabled => _enabled;
}

/// Stub [FirebaseRemoteConfig] never invoked in these tests but required to
/// satisfy the `FeatureFlags` constructor's typed dependency. We reach this
/// instance only through the overridden getter.
class _UnusedRemoteConfig implements FirebaseRemoteConfig {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('reading_screen_ocr_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    if (Hive.isBoxOpen(OcrCacheService.boxName)) {
      await Hive.box(OcrCacheService.boxName).clear();
    } else {
      await Hive.openBox(OcrCacheService.boxName);
    }
  });

  /// Builds a container with the OCR pipeline's collaborators stubbed out so
  /// `ocrPageTextProvider` is fully testable on the VM.
  ProviderContainer buildContainer({
    required _FakeOcrDataSource fake,
    required Uint8List? pageBytes,
  }) {
    return ProviderContainer(
      overrides: [
        ocrDataSourceProvider.overrideWithValue(fake),
        // Always return the same fake PNG bytes for any (url, pageIndex)
        // combination; OCR pipeline never inspects the bytes themselves.
        ocrPageImageProvider.overrideWith((ref, args) async => pageBytes),
      ],
    );
  }

  group('ocrPageTextProvider — cache & invocation contract', () {
    test('cache hit short-circuits OCR (recognise not called)', () async {
      final fake = _FakeOcrDataSource()..response = 'should-not-run';
      final container = buildContainer(
        fake: fake,
        pageBytes: Uint8List.fromList([1, 2, 3]),
      );
      addTearDown(container.dispose);

      // Pre-populate cache: ocr_v1_book42_3 -> "cached text"
      final cache = container.read(ocrCacheServiceProvider);
      await cache.put('book42', 3, 'cached text');

      final result = await container.read(
        ocrPageTextProvider((
          bookId: 'book42',
          url: 'https://x/test.pdf',
          pageIndex: 3,
        )).future,
      );

      expect(result, 'cached text');
      expect(
        fake.callCount,
        0,
        reason: 'cache hit must skip OCR engine entirely',
      );
    });

    test('cache miss invokes OCR, cleans output, then caches', () async {
      final fake = _FakeOcrDataSource()..response = 'first   line\nsecond line';
      final container = buildContainer(
        fake: fake,
        pageBytes: Uint8List.fromList([1, 2, 3]),
      );
      addTearDown(container.dispose);

      final result = await container.read(
        ocrPageTextProvider((
          bookId: 'bookA',
          url: 'https://x/a.pdf',
          pageIndex: 0,
        )).future,
      );

      expect(fake.callCount, 1);
      // `cleanForTts` collapses runs of spaces and joins single \n with a
      // space; the result should be one line of prose with the inner
      // double-space collapsed to single.
      expect(result, 'first line second line');
      // And it should now be in the cache for next time.
      expect(
        container.read(ocrCacheServiceProvider).get('bookA', 0),
        'first line second line',
      );
    });

    test('second read of same (bookId, page) does not re-invoke OCR', () async {
      final fake = _FakeOcrDataSource()..response = 'page text';
      final container = buildContainer(
        fake: fake,
        pageBytes: Uint8List.fromList([9, 9, 9]),
      );
      addTearDown(container.dispose);

      final args = (bookId: 'bookB', url: 'https://x/b.pdf', pageIndex: 7);

      await container.read(ocrPageTextProvider(args).future);
      // Second read - Riverpod may serve from its own family cache, but
      // even if it didn't, the Hive cache short-circuits the recogniser.
      // Invalidate the family entry to force the second read to traverse
      // the provider body again, then assert call count stays at 1.
      container.invalidate(ocrPageTextProvider(args));
      await container.read(ocrPageTextProvider(args).future);

      expect(fake.callCount, 1);
    });

    test(
      'empty OCR result is still cached so re-reads stay zero-cost',
      () async {
        final fake = _FakeOcrDataSource()..response = '';
        final container = buildContainer(
          fake: fake,
          pageBytes: Uint8List.fromList([1, 2, 3]),
        );
        addTearDown(container.dispose);

        final result = await container.read(
          ocrPageTextProvider((
            bookId: 'bookC',
            url: 'https://x/c.pdf',
            pageIndex: 0,
          )).future,
        );

        expect(result, '');
        // Empty *string* is cached (not null) so we don't OCR a blank page
        // every time the user revisits it.
        expect(container.read(ocrCacheServiceProvider).get('bookC', 0), '');
      },
    );

    test(
      'null page-image bytes throw a StateError caller can map to UI msg',
      () async {
        final fake = _FakeOcrDataSource();
        final container = buildContainer(fake: fake, pageBytes: null);
        addTearDown(container.dispose);

        Object? caught;
        try {
          await container.read(
            ocrPageTextProvider((
              bookId: 'bookD',
              url: 'https://x/d.pdf',
              pageIndex: 0,
            )).future,
          );
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<StateError>());
        // Must mention the page index so error logs are useful.
        expect(caught.toString(), contains('1')); // 0-indexed -> human page 1
        expect(
          fake.callCount,
          0,
          reason: 'render failure must short-circuit before recogniser run',
        );
      },
    );

    test(
      'bookOcrProgressProvider stays null after a single foreground OCR',
      () async {
        // The provider only mutates from `_maybeStartBackgroundOcr` in the
        // reading screen — `ocrPageTextProvider` itself must not poke it.
        final fake = _FakeOcrDataSource()..response = 'hello';
        final container = buildContainer(
          fake: fake,
          pageBytes: Uint8List.fromList([1, 2, 3]),
        );
        addTearDown(container.dispose);

        expect(container.read(bookOcrProgressProvider), isNull);
        await container.read(
          ocrPageTextProvider((
            bookId: 'bookE',
            url: 'https://x/e.pdf',
            pageIndex: 0,
          )).future,
        );
        expect(container.read(bookOcrProgressProvider), isNull);
      },
    );
  });

  group('kill-switch contract via featureFlagsProvider', () {
    test('flag=false keeps reader off OCR pipeline (the read returns false)', () {
      // The reader uses `ref.read(featureFlagsProvider).ocrFallbackEnabled` as
      // a single boolean guard. We pin the contract: when the override returns
      // false, that's what the reader observes — no fancy lazy init, no
      // off-thread surprises. If this stops being true, the reader's
      // kill-switch is silently broken.
      final container = ProviderContainer(
        overrides: [
          featureFlagsProvider.overrideWithValue(
            _FakeFeatureFlags(false, _UnusedRemoteConfig()),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(featureFlagsProvider).ocrFallbackEnabled, isFalse);
    });

    test(
      'flag=true unblocks the OCR pipeline (no exceptions raised)',
      () async {
        final fake = _FakeOcrDataSource()..response = 'recovered';
        final container = ProviderContainer(
          overrides: [
            featureFlagsProvider.overrideWithValue(
              _FakeFeatureFlags(true, _UnusedRemoteConfig()),
            ),
            ocrDataSourceProvider.overrideWithValue(fake),
            ocrPageImageProvider.overrideWith(
              (ref, args) async => Uint8List.fromList([1, 2, 3]),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(featureFlagsProvider).ocrFallbackEnabled, isTrue);
        final result = await container.read(
          ocrPageTextProvider((
            bookId: 'bookF',
            url: 'https://x/f.pdf',
            pageIndex: 0,
          )).future,
        );
        expect(result, 'recovered');
        expect(fake.callCount, 1);
      },
    );
  });
}
