import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_pdf/core/local/recent_books_service.dart';
import 'package:my_pdf/core/local/streak_service.dart';

/// Streak rules:
///   * `recordOpen()` on a fresh box → count 1, no milestone
///   * Same-day repeat → count unchanged, no milestone
///   * Last open == yesterday → count + 1
///   * Last open older than yesterday → count resets to 1
///   * Crossing exactly 7 / 30 / 100 fires that milestone, once. Re-arriving
///     at the same milestone later (after a break) must not re-fire.
///   * `takePendingMilestone()` only returns + records when current count
///     is a milestone that has not been celebrated.
String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('streak_service_test_');
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

  group('StreakService.recordOpen', () {
    test('first open returns count 1, no milestone', () async {
      final svc = StreakService();
      final res = await svc.recordOpen();
      expect(res.count, 1);
      expect(res.justHitMilestone, isNull);
      expect(svc.current, 1);
      expect(svc.lastOpenIso, _isoDay(DateTime.now()));
    });

    test('same-day repeat is idempotent — no count change, no milestone',
        () async {
      final svc = StreakService();
      final r1 = await svc.recordOpen();
      final r2 = await svc.recordOpen();
      expect(r1.count, 1);
      expect(r2.count, 1);
      expect(r2.justHitMilestone, isNull);
    });

    test('open after yesterday increments count', () async {
      final box = Hive.box(RecentBooksService.boxName);
      // Seed prior state — count 2, last open yesterday.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await box.put('streak_count', 2);
      await box.put('streak_last_open_iso', _isoDay(yesterday));

      final svc = StreakService();
      final res = await svc.recordOpen();
      expect(res.count, 3);
      expect(res.justHitMilestone, isNull);
      expect(svc.current, 3);
    });

    test('open after gap (older than yesterday) resets count to 1', () async {
      final box = Hive.box(RecentBooksService.boxName);
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      await box.put('streak_count', 12);
      await box.put('streak_last_open_iso', _isoDay(twoDaysAgo));

      final svc = StreakService();
      final res = await svc.recordOpen();
      expect(res.count, 1, reason: 'broken streak resets to 1');
      expect(res.justHitMilestone, isNull);
    });

    test('unparseable lastOpenIso treated as broken streak → reset to 1',
        () async {
      final box = Hive.box(RecentBooksService.boxName);
      await box.put('streak_count', 5);
      await box.put('streak_last_open_iso', 'not-a-real-date');

      final svc = StreakService();
      final res = await svc.recordOpen();
      expect(res.count, 1);
    });

    test('hitting count 7 fires the streak_7 milestone once', () async {
      final box = Hive.box(RecentBooksService.boxName);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await box.put('streak_count', 6);
      await box.put('streak_last_open_iso', _isoDay(yesterday));

      final svc = StreakService();
      final res = await svc.recordOpen();
      expect(res.count, 7);
      expect(res.justHitMilestone, 7);
    });

    test('returning to a previously-celebrated milestone does not re-fire',
        () async {
      final box = Hive.box(RecentBooksService.boxName);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      // 7 already celebrated previously; user now lands on 7 again.
      await box.put('streak_count', 6);
      await box.put('streak_last_open_iso', _isoDay(yesterday));
      await box.put('streak_milestones_celebrated', '7');

      final svc = StreakService();
      final res = await svc.recordOpen();
      expect(res.count, 7);
      expect(res.justHitMilestone, isNull,
          reason: '7 is recorded as celebrated → no re-fire');
    });

    test('count 8 does not fire 7 milestone (only exact equality)', () async {
      final box = Hive.box(RecentBooksService.boxName);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await box.put('streak_count', 7);
      await box.put('streak_last_open_iso', _isoDay(yesterday));

      final svc = StreakService();
      final res = await svc.recordOpen();
      expect(res.count, 8);
      expect(res.justHitMilestone, isNull);
    });

    test('milestone is recorded as celebrated after firing', () async {
      final box = Hive.box(RecentBooksService.boxName);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await box.put('streak_count', 6);
      await box.put('streak_last_open_iso', _isoDay(yesterday));

      final svc = StreakService();
      await svc.recordOpen();
      final stored = box.get('streak_milestones_celebrated') as String?;
      expect(stored, '7');
    });
  });

  group('StreakService.takePendingMilestone', () {
    test('returns null when current is not a milestone', () async {
      final box = Hive.box(RecentBooksService.boxName);
      await box.put('streak_count', 5);

      final svc = StreakService();
      expect(await svc.takePendingMilestone(), isNull);
    });

    test('returns milestone and records it celebrated when matching', () async {
      final box = Hive.box(RecentBooksService.boxName);
      await box.put('streak_count', 7);

      final svc = StreakService();
      final hit = await svc.takePendingMilestone();
      expect(hit, 7);
      expect(box.get('streak_milestones_celebrated'), '7');
    });

    test('returns null when milestone already celebrated', () async {
      final box = Hive.box(RecentBooksService.boxName);
      await box.put('streak_count', 7);
      await box.put('streak_milestones_celebrated', '7');

      final svc = StreakService();
      expect(await svc.takePendingMilestone(), isNull);
    });
  });

  group('StreakService default reads', () {
    test('current returns 0 when nothing stored', () async {
      final svc = StreakService();
      expect(svc.current, 0);
      expect(svc.lastOpenIso, isNull);
    });
  });
}
