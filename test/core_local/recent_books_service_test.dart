import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_pdf/core/local/recent_books_service.dart';

/// Hive-backed service tests. We use `Hive.init` with a temp directory rather
/// than `Hive.initFlutter` because the latter requires a `WidgetsFlutterBinding`
/// (path_provider channel call). The temp dir approach matches what the
/// `hive` package itself does in its own integration tests.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('recent_books_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(RecentBooksService.boxName);
  });

  tearDown(() async {
    await Hive.box(RecentBooksService.boxName).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('RecentBooksService', () {
    test('ids returns empty list when nothing stored', () {
      final service = RecentBooksService();
      expect(service.ids, isEmpty);
    });

    test('markOpened inserts id at front of list', () async {
      final service = RecentBooksService();
      await service.markOpened('b1');
      expect(service.ids, ['b1']);
      await service.markOpened('b2');
      expect(service.ids, ['b2', 'b1']);
      await service.markOpened('b3');
      expect(service.ids, ['b3', 'b2', 'b1']);
    });

    test('markOpened with empty bookId is a no-op', () async {
      final service = RecentBooksService();
      await service.markOpened('');
      expect(service.ids, isEmpty);
    });

    test('LRU dedupe — re-marking moves an existing id to front', () async {
      final service = RecentBooksService();
      await service.markOpened('b1');
      await service.markOpened('b2');
      await service.markOpened('b3');
      expect(service.ids, ['b3', 'b2', 'b1']);
      await service.markOpened('b1');
      expect(service.ids, ['b1', 'b3', 'b2']);
    });

    test('caps at maxItems (10) — inserting 11th drops oldest', () async {
      final service = RecentBooksService();
      for (var i = 1; i <= 11; i++) {
        await service.markOpened('b$i');
      }
      expect(service.ids.length, 10);
      // b1 was inserted first, then bumped to position 9 by subsequent writes.
      // After 11 inserts, the earliest (b1) should be evicted.
      expect(service.ids.contains('b1'), isFalse);
      expect(service.ids.first, 'b11');
      expect(service.ids.last, 'b2');
    });

    test('cap holds when re-marking near the limit', () async {
      final service = RecentBooksService();
      for (var i = 1; i <= 10; i++) {
        await service.markOpened('b$i');
      }
      expect(service.ids.length, 10);
      // Re-mark an existing id — should NOT exceed cap.
      await service.markOpened('b1');
      expect(service.ids.length, 10);
      expect(service.ids.first, 'b1');
    });

    test('remove deletes existing id and persists', () async {
      final service = RecentBooksService();
      await service.markOpened('b1');
      await service.markOpened('b2');
      await service.remove('b1');
      expect(service.ids, ['b2']);
    });

    test('remove is no-op when id not present', () async {
      final service = RecentBooksService();
      await service.markOpened('b1');
      await service.remove('does-not-exist');
      expect(service.ids, ['b1']);
    });

    test('clear empties the list', () async {
      final service = RecentBooksService();
      await service.markOpened('b1');
      await service.markOpened('b2');
      await service.clear();
      expect(service.ids, isEmpty);
    });

    test('ids returned list does not share state with future writes', () async {
      // Service.ids returns a new List each call (List.from on stored value)
      // — verify that mutating the result or doing more writes works as expected.
      final service = RecentBooksService();
      await service.markOpened('b1');
      final snapshot = service.ids;
      await service.markOpened('b2');
      // First snapshot should remain unchanged.
      expect(snapshot, ['b1']);
      expect(service.ids, ['b2', 'b1']);
    });

    test('watch yields current ids on subscribe', () async {
      final service = RecentBooksService();
      await service.markOpened('b1');
      // Validate the initial yield only. The `await for box.watch(key:)`
      // continuation is exercised at runtime by the home rail; under flutter_test
      // it requires real binding-driven event-loop ticks the unit test harness
      // doesn't reliably provide (broadcast watcher events arrive after
      // StreamIterator pauses). Initial-yield contract is what consumers depend
      // on for first paint, so that's what we lock in here.
      final first = await service
          .watch()
          .first
          .timeout(const Duration(seconds: 2));
      expect(first, ['b1']);
    });

  });
}
