import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_pdf/core/local/book_finish_service.dart';
import 'package:my_pdf/core/local/recent_books_service.dart';

/// `BookFinishService` is a one-shot first-finish tracker:
///   * markFinished returns true the first time per bookId, false thereafter
///   * empty bookId is rejected (no celebration, no flag set)
///   * isFinished tells the caller whether the flag is set
///   * Per-book flags do NOT interfere with each other
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('book_finish_test_');
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

  group('BookFinishService', () {
    test('markFinished returns true on first call', () async {
      final svc = BookFinishService();
      expect(await svc.markFinished('b1'), isTrue);
    });

    test('markFinished returns false on second call (idempotent)', () async {
      final svc = BookFinishService();
      await svc.markFinished('b1');
      expect(await svc.markFinished('b1'), isFalse);
    });

    test('markFinished rejects empty bookId', () async {
      final svc = BookFinishService();
      expect(await svc.markFinished(''), isFalse);
      expect(svc.isFinished(''), isFalse);
    });

    test('isFinished returns false before markFinished', () {
      final svc = BookFinishService();
      expect(svc.isFinished('never-touched'), isFalse);
    });

    test('isFinished returns true after markFinished', () async {
      final svc = BookFinishService();
      await svc.markFinished('b42');
      expect(svc.isFinished('b42'), isTrue);
    });

    test('different books have independent flags', () async {
      final svc = BookFinishService();
      expect(await svc.markFinished('b1'), isTrue);
      expect(await svc.markFinished('b2'), isTrue,
          reason: 'b2 not affected by b1');
      expect(svc.isFinished('b1'), isTrue);
      expect(svc.isFinished('b2'), isTrue);
      expect(svc.isFinished('b3'), isFalse);
    });

    test('flag persists across service instances (via shared Hive box)',
        () async {
      await BookFinishService().markFinished('persisted');
      // Fresh instance reads the same Hive box.
      expect(BookFinishService().isFinished('persisted'), isTrue);
    });
  });

  group('BookFinishService — Hive box closed (degraded test env)', () {
    // The service tolerates a missing Hive box (test environments / cold-start
    // races) by returning safe defaults. Validate that contract: close the box,
    // assert markFinished returns false silently, then re-open for tearDown.
    test('markFinished returns false when box is not open', () async {
      // Close the shared box BEFORE making the call. Reopen in addTearDown so
      // the global tearDownAll (Hive.close) doesn't blow up.
      await Hive.box(RecentBooksService.boxName).close();
      addTearDown(() async {
        if (!Hive.isBoxOpen(RecentBooksService.boxName)) {
          await Hive.openBox(RecentBooksService.boxName);
        }
      });
      final svc = BookFinishService();
      expect(await svc.markFinished('b9'), isFalse);
      expect(svc.isFinished('b9'), isFalse);
    });
  });
}
