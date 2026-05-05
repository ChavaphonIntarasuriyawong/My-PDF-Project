@Tags(['ocr-pipeline'])
@Skip(
    'Wave 4 — blocked by Wave 3 source issue: '
    'lib/features/library/data/ocr_data_source.dart imports `dart:js_interop` '
    'and `package:web` unconditionally at the top of the file, so any VM-side '
    'test that transitively imports `library_providers.dart` (which holds the '
    '`ocrPageTextProvider` we want to exercise) fails to compile. '
    'Un-skip after Wave 5 splits the datasource into platform-conditional '
    'imports (e.g. ocr_data_source_io.dart + ocr_data_source_web.dart with a '
    'conditional `export`).')
library;

import 'package:flutter_test/flutter_test.dart';

// Intentionally empty until the source-side conditional-import refactor lands.
// When it does, the test should:
//
//   1. Open a temp Hive box for `app_prefs` so `OcrCacheService` works.
//   2. Build a `ProviderContainer` with overrides:
//        - `ocrCacheServiceProvider` -> real service against the temp box
//        - `pdfPageImageProvider`    -> always returns Uint8List.fromList([1,2,3])
//        - `ocrDataSourceProvider`   -> _FakeOcrDataSource (call counter)
//   3. Tests:
//        a) Cache hit short-circuits OCR
//             - Pre-populate cache via OcrCacheService.put.
//             - Read ocrPageTextProvider.future -> assert fake.callCount == 0.
//        b) Cache miss runs OCR + writes cache
//             - Empty cache, fake returns 'fake ocr text'.
//             - First read -> assert fake.callCount == 1, result == cleaned text.
//             - Second read of same key -> assert fake.callCount stays at 1.
//        c) Empty OCR result is cached
//             - Fake returns ''.
//             - Read provider -> result == ''.
//             - Cache.get(...) returns '' (NOT null), so re-read does not call fake again.
//        d) `bookOcrProgressProvider` defaults to null and is left alone by
//            ocrPageTextProvider (provider only updates from the reading
//            screen's background sweep — verify the family read does not
//            mutate it).
//
// Reference fake (top-level so the test can spawn instances):
//
//   class _FakeOcrDataSource implements OcrDataSource {
//     int callCount = 0;
//     String response = 'fake ocr text';
//     @override
//     Future<String> recognize(Uint8List bytes, {String langs = 'eng+tha'}) async {
//       callCount++;
//       return response;
//     }
//     @override
//     Future<void> dispose() async {}
//   }
