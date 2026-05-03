import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_pdf/core/local/achievement_service.dart';
import 'package:my_pdf/core/local/recent_books_service.dart';

/// Achievement catalog (matches `AchievementService._catalog`):
///   * firstBook       — books finished >= 1
///   * bookworm        — books finished >= 5
///   * streak3 / 7 / 30 — max streak >= 3 / 7 / 30
///   * surpriseReader  — surprise-me used >= 5
///   * karaokeStar     — TTS used in >= 3 unique books
///
/// recordEvent returns the IDs unlocked during this call. Already-unlocked
/// badges are NOT reported again. Counters are monotonic where it matters
/// (max streak only grows).
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('achievement_test_');
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

  group('AchievementService.all', () {
    test('returns all 7 catalog entries, all locked initially', () {
      final list = AchievementService().all();
      expect(list, hasLength(7));
      expect(list.every((a) => !a.unlocked), isTrue);
      expect(list.every((a) => a.unlockedAt == null), isTrue);
    });

    test('catalog includes the expected ids in order', () {
      final ids = AchievementService().all().map((a) => a.id).toList();
      expect(ids, [
        AchievementIds.firstBook,
        AchievementIds.bookworm,
        AchievementIds.streak3,
        AchievementIds.streak7,
        AchievementIds.streak30,
        AchievementIds.surpriseReader,
        AchievementIds.karaokeStar,
      ]);
    });
  });

  group('AchievementService.recordEvent — bookFinished', () {
    test('first finish unlocks firstBook only', () {
      final svc = AchievementService();
      final unlocked = svc.recordEvent(AchievementEvent.bookFinished());
      expect(unlocked, [AchievementIds.firstBook]);
    });

    test('5th finish unlocks bookworm; firstBook not re-reported', () {
      final svc = AchievementService();
      svc.recordEvent(AchievementEvent.bookFinished()); // unlocks firstBook
      svc.recordEvent(AchievementEvent.bookFinished());
      svc.recordEvent(AchievementEvent.bookFinished());
      svc.recordEvent(AchievementEvent.bookFinished());
      final unlocked = svc.recordEvent(AchievementEvent.bookFinished());
      expect(unlocked, [AchievementIds.bookworm]);
    });

    test('6th finish reports nothing new', () {
      final svc = AchievementService();
      for (var i = 0; i < 5; i++) {
        svc.recordEvent(AchievementEvent.bookFinished());
      }
      expect(svc.recordEvent(AchievementEvent.bookFinished()), isEmpty);
    });
  });

  group('AchievementService.recordEvent — surpriseMeUsed', () {
    test('5th use unlocks surpriseReader', () {
      final svc = AchievementService();
      for (var i = 0; i < 4; i++) {
        expect(svc.recordEvent(AchievementEvent.surpriseMeUsed()), isEmpty);
      }
      final unlocked = svc.recordEvent(AchievementEvent.surpriseMeUsed());
      expect(unlocked, [AchievementIds.surpriseReader]);
    });
  });

  group('AchievementService.recordEvent — ttsUsedOnBook', () {
    test('3 distinct books unlock karaokeStar', () {
      final svc = AchievementService();
      expect(
          svc.recordEvent(AchievementEvent.ttsUsedOnBook('b1')), isEmpty);
      expect(
          svc.recordEvent(AchievementEvent.ttsUsedOnBook('b2')), isEmpty);
      final unlocked = svc.recordEvent(AchievementEvent.ttsUsedOnBook('b3'));
      expect(unlocked, [AchievementIds.karaokeStar]);
    });

    test('same bookId twice does not double-count', () {
      final svc = AchievementService();
      svc.recordEvent(AchievementEvent.ttsUsedOnBook('b1'));
      svc.recordEvent(AchievementEvent.ttsUsedOnBook('b1'));
      svc.recordEvent(AchievementEvent.ttsUsedOnBook('b2'));
      // Only 2 unique books — karaokeStar NOT unlocked.
      final unlockedAchievement =
          svc.all().firstWhere((a) => a.id == AchievementIds.karaokeStar);
      expect(unlockedAchievement.unlocked, isFalse);
    });

    test('empty bookId returns empty list with no side effects', () {
      final svc = AchievementService();
      expect(svc.recordEvent(AchievementEvent.ttsUsedOnBook('')), isEmpty);
      expect(
          svc.all().firstWhere((a) => a.id == AchievementIds.karaokeStar)
              .unlocked,
          isFalse);
    });
  });

  group('AchievementService.recordEvent — streakReached', () {
    test('3 day streak unlocks streak3 only', () {
      final svc = AchievementService();
      final unlocked = svc.recordEvent(AchievementEvent.streakReached(3));
      expect(unlocked, [AchievementIds.streak3]);
    });

    test('7 day streak unlocks streak3 + streak7 in order', () {
      final svc = AchievementService();
      final unlocked = svc.recordEvent(AchievementEvent.streakReached(7));
      expect(unlocked,
          containsAllInOrder([AchievementIds.streak3, AchievementIds.streak7]));
    });

    test('30 day streak unlocks all three streak badges', () {
      final svc = AchievementService();
      final unlocked = svc.recordEvent(AchievementEvent.streakReached(30));
      expect(unlocked, [
        AchievementIds.streak3,
        AchievementIds.streak7,
        AchievementIds.streak30,
      ]);
    });

    test('max streak is monotonic — lower value does not regress', () {
      final svc = AchievementService();
      svc.recordEvent(AchievementEvent.streakReached(10));
      final unlocked = svc.recordEvent(AchievementEvent.streakReached(2));
      // Already past 7, so nothing new; streak3/7 stay unlocked.
      expect(unlocked, isEmpty);
      final list = svc.all();
      expect(list.firstWhere((a) => a.id == AchievementIds.streak3).unlocked,
          isTrue);
      expect(list.firstWhere((a) => a.id == AchievementIds.streak7).unlocked,
          isTrue);
    });

    test('unlocked badges are not re-reported on later calls', () {
      final svc = AchievementService();
      svc.recordEvent(AchievementEvent.streakReached(7));
      // Hit 7 again — nothing new to unlock.
      expect(svc.recordEvent(AchievementEvent.streakReached(7)), isEmpty);
    });
  });

  group('AchievementService — unlock metadata', () {
    test('unlockedAt is populated when a badge unlocks', () {
      final svc = AchievementService();
      final before = DateTime.now();
      svc.recordEvent(AchievementEvent.bookFinished());
      final achievement =
          svc.all().firstWhere((a) => a.id == AchievementIds.firstBook);
      expect(achievement.unlocked, isTrue);
      expect(achievement.unlockedAt, isNotNull);
      expect(
          achievement.unlockedAt!
                  .isAfter(before.subtract(const Duration(seconds: 1))) ||
              achievement.unlockedAt!.isAtSameMomentAs(before),
          isTrue);
    });

    test('findById returns the requested achievement', () {
      final svc = AchievementService();
      svc.recordEvent(AchievementEvent.bookFinished());
      final found = svc.findById(AchievementIds.firstBook);
      expect(found, isNotNull);
      expect(found!.unlocked, isTrue);
      expect(svc.findById('does-not-exist'), isNull);
    });
  });

  group('Achievement (data class)', () {
    // copyWith is the only branchy code on the data class itself — exercised
    // here so the line stays in coverage for the >80% gate.
    test('copyWith preserves untouched fields', () {
      const a = Achievement(
        id: 'x',
        title: 'Test',
        description: 'desc',
        icon: Icons.bookmark,
        unlocked: false,
        unlockedAt: null,
        current: 0,
        target: 1,
      );
      final updated = a.copyWith(unlocked: true);
      expect(updated.id, 'x');
      expect(updated.title, 'Test');
      expect(updated.description, 'desc');
      expect(updated.icon, Icons.bookmark);
      expect(updated.unlocked, isTrue);
      expect(updated.unlockedAt, isNull);
    });

    test('copyWith overrides unlockedAt', () {
      const a = Achievement(
        id: 'x',
        title: 'Test',
        description: 'desc',
        icon: Icons.bookmark,
        unlocked: false,
        unlockedAt: null,
        current: 0,
        target: 1,
      );
      final ts = DateTime(2026, 5, 1);
      final updated = a.copyWith(unlocked: true, unlockedAt: ts);
      expect(updated.unlocked, isTrue);
      expect(updated.unlockedAt, ts);
    });
  });

  group('AchievementsNotifier (Riverpod surface)', () {
    test('initial state mirrors service.all()', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final list = container.read(achievementsProvider);
      expect(list, hasLength(7));
      expect(list.every((a) => !a.unlocked), isTrue);
    });

    test('record forwards event and refreshes state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(achievementsProvider.notifier);
      final unlocked = notifier.record(AchievementEvent.bookFinished());
      expect(unlocked, [AchievementIds.firstBook]);
      // State refreshed — firstBook now reads as unlocked.
      final firstBook = container
          .read(achievementsProvider)
          .firstWhere((a) => a.id == AchievementIds.firstBook);
      expect(firstBook.unlocked, isTrue);
    });

    test('record returns empty list when no new unlocks', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(achievementsProvider.notifier);
      notifier.record(AchievementEvent.bookFinished());
      // Second event of same kind — no new unlock until 5 books finished.
      final unlocked = notifier.record(AchievementEvent.bookFinished());
      expect(unlocked, isEmpty);
    });
  });

  group('Achievement progress (current / target / ratio)', () {
    test('locked badge reports 0/target on a fresh box', () {
      final list = AchievementService().all();
      final bookworm =
          list.firstWhere((a) => a.id == AchievementIds.bookworm);
      expect(bookworm.current, 0);
      expect(bookworm.target, 5);
      expect(bookworm.ratio, 0.0);
    });

    test('partial progress yields correct ratio', () {
      final svc = AchievementService();
      svc.recordEvent(AchievementEvent.bookFinished());
      svc.recordEvent(AchievementEvent.bookFinished());
      final bookworm =
          svc.all().firstWhere((a) => a.id == AchievementIds.bookworm);
      expect(bookworm.current, 2);
      expect(bookworm.target, 5);
      expect(bookworm.ratio, closeTo(0.4, 0.001));
    });

    test('unlocked badge reports ratio 1.0 even if counter resets', () {
      final svc = AchievementService();
      svc.recordEvent(AchievementEvent.bookFinished());
      final firstBook =
          svc.all().firstWhere((a) => a.id == AchievementIds.firstBook);
      expect(firstBook.unlocked, isTrue);
      expect(firstBook.ratio, 1.0);
    });

    test('streak badges share the maxStreak counter', () {
      final svc = AchievementService();
      svc.recordEvent(AchievementEvent.streakReached(5));
      final list = svc.all();
      final s3 = list.firstWhere((a) => a.id == AchievementIds.streak3);
      final s7 = list.firstWhere((a) => a.id == AchievementIds.streak7);
      final s30 = list.firstWhere((a) => a.id == AchievementIds.streak30);
      expect(s3.current, 5);
      expect(s7.current, 5);
      expect(s30.current, 5);
      expect(s3.unlocked, isTrue); // 5 >= 3
      expect(s7.unlocked, isFalse); // 5 < 7
      expect(s30.unlocked, isFalse);
      expect(s7.ratio, closeTo(5 / 7, 0.001));
    });

    test('TTS unique-book counter feeds karaokeStar progress', () {
      final svc = AchievementService();
      svc.recordEvent(AchievementEvent.ttsUsedOnBook('a'));
      svc.recordEvent(AchievementEvent.ttsUsedOnBook('a'));
      svc.recordEvent(AchievementEvent.ttsUsedOnBook('b'));
      final ks = svc.all().firstWhere(
          (a) => a.id == AchievementIds.karaokeStar);
      expect(ks.current, 2, reason: 'duplicate book id ignored');
      expect(ks.target, 3);
      expect(ks.ratio, closeTo(2 / 3, 0.001));
    });

    test('ratio clamps to 1.0 when current overshoots target', () {
      final svc = AchievementService();
      svc.recordEvent(AchievementEvent.streakReached(50));
      final s7 = svc.all().firstWhere(
          (a) => a.id == AchievementIds.streak7);
      // unlocked → ratio shortcuts to 1.0; current is the raw counter (50).
      expect(s7.unlocked, isTrue);
      expect(s7.current, 50);
      expect(s7.ratio, 1.0);
    });
  });
}
