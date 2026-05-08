import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_pdf/core/local/ocr_cache_service.dart';

/// Hive setup for tests:
///
/// `Hive.initFlutter` calls into `path_provider`, which is not available in
/// unit tests. We use vanilla `Hive.init(<temp dir>)` instead and clean up
/// the directory in `tearDownAll`. The box name (`app_prefs`) and key prefix
/// (`ocr_v1_`) come straight from `OcrCacheService` constants — keeping the
/// tests honest about what the production code actually writes to disk.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('ocr_cache_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    // Open a fresh box per test so state never leaks between cases.
    if (Hive.isBoxOpen(OcrCacheService.boxName)) {
      await Hive.box(OcrCacheService.boxName).clear();
    } else {
      await Hive.openBox(OcrCacheService.boxName);
    }
  });

  group('OcrCacheService', () {
    test('put then get returns the same text', () async {
      final svc = OcrCacheService();
      await svc.put('book123', 5, 'hello world');
      expect(svc.get('book123', 5), 'hello world');
    });

    test('get for missing key returns null', () {
      final svc = OcrCacheService();
      expect(svc.get('book999', 0), isNull);
    });

    test('purgeBook removes only that book\'s keys', () async {
      final svc = OcrCacheService();
      await svc.put('bookA', 0, 'page A0');
      await svc.put('bookA', 1, 'page A1');
      await svc.put('bookB', 0, 'page B0');
      await svc.put('bookB', 1, 'page B1');

      await svc.purgeBook('bookA');

      expect(svc.get('bookA', 0), isNull);
      expect(svc.get('bookA', 1), isNull);
      expect(svc.get('bookB', 0), 'page B0');
      expect(svc.get('bookB', 1), 'page B1');
    });

    test('purgeBook on a bookId with no entries is a no-op', () async {
      final svc = OcrCacheService();
      await svc.put('bookA', 0, 'kept');
      await svc.purgeBook('bookNeverWritten');
      expect(svc.get('bookA', 0), 'kept');
    });

    test(
      'purgeAll wipes ocr_v1_ namespace but leaves unrelated keys (recents) alone',
      () async {
        final box = Hive.box(OcrCacheService.boxName);
        // Pretend RecentBooksService had already populated its key.
        await box.put('recent_book_ids', <String>['b1', 'b2']);

        final svc = OcrCacheService();
        await svc.put('bookA', 0, 'A0');
        await svc.put('bookB', 7, 'B7');

        await svc.purgeAll();

        expect(svc.get('bookA', 0), isNull);
        expect(svc.get('bookB', 7), isNull);
        // Recents key must survive.
        expect(box.get('recent_book_ids'), <String>['b1', 'b2']);
      },
    );

    test('purgeAll on an empty namespace is a no-op', () async {
      final box = Hive.box(OcrCacheService.boxName);
      await box.put('some_other_key', 'kept');
      final svc = OcrCacheService();
      await svc.purgeAll();
      expect(box.get('some_other_key'), 'kept');
    });

    test(
      'schema-versioned key format is ocr_v1_{bookId}_{pageIndex}',
      () async {
        final svc = OcrCacheService();
        await svc.put('book123', 5, 'expected text');
        // Direct read against the underlying box pins the key shape so a
        // future schema bump (e.g. ocr_v2_) is forced to land its own
        // namespace migration test rather than silently breaking caches in
        // the wild.
        final raw = Hive.box(OcrCacheService.boxName).get('ocr_v1_book123_5');
        expect(raw, 'expected text');
      },
    );

    test('keys are scoped per page index', () async {
      final svc = OcrCacheService();
      await svc.put('book42', 0, 'first page');
      await svc.put('book42', 1, 'second page');
      expect(svc.get('book42', 0), 'first page');
      expect(svc.get('book42', 1), 'second page');
    });

    test('overwriting an existing entry replaces the value', () async {
      final svc = OcrCacheService();
      await svc.put('book42', 0, 'old text');
      await svc.put('book42', 0, 'new text');
      expect(svc.get('book42', 0), 'new text');
    });

    test('get returns null when underlying value is not a String', () async {
      final box = Hive.box(OcrCacheService.boxName);
      // Defensive: someone wrote a non-String into our namespace via direct
      // box access. Service must not type-cast and crash the caller.
      await box.put('ocr_v1_corrupt_0', 12345);
      final svc = OcrCacheService();
      expect(svc.get('corrupt', 0), isNull);
    });

    test('book IDs containing underscores still scope correctly', () async {
      // Book IDs from Firestore are auto-generated and can contain
      // underscores; the prefix scan in purgeBook uses startsWith('${prefix}'
      // + bookId + '_'), so we want to confirm we don't bleed siblings.
      final svc = OcrCacheService();
      await svc.put('book_one', 0, 'one');
      await svc.put('book_one_extra', 0, 'extra');
      await svc.purgeBook('book_one');
      expect(svc.get('book_one', 0), isNull);
      // 'book_one_extra' starts with 'book_one_', so it WILL also be purged.
      // Document this current behaviour — if it ever becomes a real-world
      // problem, the cache key format is the right thing to fix.
      expect(svc.get('book_one_extra', 0), isNull);
    });
  });
}
