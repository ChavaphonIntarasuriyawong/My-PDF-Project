import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'recent_books_service.dart';

/// Catalog of unlockable achievement IDs. Kept as raw strings (not an enum)
/// because they double as Hive keys (`achv_unlocked_<id>`) and have to round-
/// trip through string storage. The catalog itself is built in
/// [AchievementService.catalog].
class AchievementIds {
  AchievementIds._();
  static const String firstBook = 'first_book';
  static const String bookworm = 'bookworm';
  static const String streak3 = 'streak_3';
  static const String streak7 = 'streak_7';
  static const String streak30 = 'streak_30';
  static const String surpriseReader = 'surprise_reader';
  static const String karaokeStar = 'karaoke_star';
}

/// Snapshot of one achievement at a point in time.
@immutable
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
    required this.unlockedAt,
  });

  Achievement copyWith({bool? unlocked, DateTime? unlockedAt}) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      icon: icon,
      unlocked: unlocked ?? this.unlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

/// Discriminator tag for [AchievementEvent]. Public so the service body and
/// callers can switch on it without exposing the private factory shape.
enum AchievementEventKind {
  bookFinished,
  surpriseMeUsed,
  ttsUsedOnBook,
  streakReached,
}

/// Discriminated input for [AchievementService.recordEvent]. Each event
/// carries the optional payload its corresponding counter needs (book id for
/// TTS unique-set tracking, day count for streaks).
@immutable
class AchievementEvent {
  final AchievementEventKind kind;
  final String? bookId;
  final int? streakDays;
  const AchievementEvent._(this.kind,
      {this.bookId, this.streakDays});

  factory AchievementEvent.bookFinished() =>
      const AchievementEvent._(AchievementEventKind.bookFinished);
  factory AchievementEvent.surpriseMeUsed() =>
      const AchievementEvent._(AchievementEventKind.surpriseMeUsed);
  factory AchievementEvent.ttsUsedOnBook(String bookId) =>
      AchievementEvent._(AchievementEventKind.ttsUsedOnBook, bookId: bookId);
  factory AchievementEvent.streakReached(int days) =>
      AchievementEvent._(AchievementEventKind.streakReached, streakDays: days);
}

/// Local-only, Hive-backed badge tracker.
///
/// All counters and unlock flags live in the existing `app_prefs` box so we
/// don't touch Hive's box registry. Each counter increments via a thin
/// `recordEvent` API; on every event we evaluate every catalog entry against
/// the latest counters and persist the unlock + ISO timestamp once.
///
/// Counters are local-only and not synced to Firestore. Re-installing the app
/// resets them (acceptable per spec — sharing across devices is out of scope).
class AchievementService {
  static const String boxName = RecentBooksService.boxName;

  // ── Counter / set keys (all stored in `app_prefs`) ─────────────────
  static const String _kBooksFinished = 'achv_counter_books_finished';
  static const String _kSurpriseMe = 'achv_counter_surprise_me';
  static const String _kTtsBooks = 'achv_set_tts_books';
  static const String _kMaxStreak = 'achv_max_streak';

  static String _unlockedKey(String id) => 'achv_unlocked_$id';
  static String _unlockedAtKey(String id) => 'achv_unlocked_at_$id';

  /// Box may not be open in test environments. Read paths fall back to defaults
  /// and write paths no-op silently — mirrors the pattern in [BookFinishService].
  Box? get _box {
    try {
      return Hive.box(boxName);
    } catch (_) {
      return null;
    }
  }

  /// Static catalog, ordered to match the spec. Listed here rather than in a
  /// separate constants file because the unlock conditions are tightly coupled
  /// to the counters this service owns.
  static const List<_CatalogEntry> _catalog = [
    _CatalogEntry(
      id: AchievementIds.firstBook,
      title: 'First Steps',
      description: 'Finish your first book',
      icon: Icons.auto_stories,
    ),
    _CatalogEntry(
      id: AchievementIds.bookworm,
      title: 'Bookworm',
      description: 'Finish 5 books',
      icon: Icons.menu_book,
    ),
    _CatalogEntry(
      id: AchievementIds.streak3,
      title: 'Streak Starter',
      description: '3 day reading streak',
      icon: Icons.local_fire_department,
    ),
    _CatalogEntry(
      id: AchievementIds.streak7,
      title: 'On Fire',
      description: '7 day reading streak',
      icon: Icons.whatshot,
    ),
    _CatalogEntry(
      id: AchievementIds.streak30,
      title: 'Inferno',
      description: '30 day reading streak',
      icon: Icons.local_fire_department,
    ),
    _CatalogEntry(
      id: AchievementIds.surpriseReader,
      title: 'Surprise Reader',
      description: 'Use Surprise Me 5 times',
      icon: Icons.casino,
    ),
    _CatalogEntry(
      id: AchievementIds.karaokeStar,
      title: 'Karaoke Star',
      description: 'Use TTS in 3 different books',
      icon: Icons.subtitles,
    ),
  ];

  /// Catalog entries paired with their current unlock state from Hive.
  /// Returns the same length and order on every call.
  List<Achievement> all() {
    final box = _box;
    return [
      for (final e in _catalog)
        Achievement(
          id: e.id,
          title: e.title,
          description: e.description,
          icon: e.icon,
          unlocked: box?.get(_unlockedKey(e.id), defaultValue: false) as bool? ??
              false,
          unlockedAt: () {
            final raw = box?.get(_unlockedAtKey(e.id)) as String?;
            return raw == null ? null : DateTime.tryParse(raw);
          }(),
        ),
    ];
  }

  /// Increments / updates the relevant counter for [event] and returns the
  /// IDs of any achievements that crossed their unlock threshold during this
  /// call. Already-unlocked badges are NOT reported again.
  ///
  /// Side-effect-free in test envs without a Hive box (returns empty list).
  List<String> recordEvent(AchievementEvent event) {
    final box = _box;
    if (box == null) return const [];

    switch (event.kind) {
      case AchievementEventKind.bookFinished:
        final n = (box.get(_kBooksFinished, defaultValue: 0) as int) + 1;
        box.put(_kBooksFinished, n);
        break;
      case AchievementEventKind.surpriseMeUsed:
        final n = (box.get(_kSurpriseMe, defaultValue: 0) as int) + 1;
        box.put(_kSurpriseMe, n);
        break;
      case AchievementEventKind.ttsUsedOnBook:
        final id = event.bookId ?? '';
        if (id.isEmpty) return const [];
        final raw = box.get(_kTtsBooks, defaultValue: '') as String;
        final set = raw.isEmpty
            ? <String>{}
            : raw.split(',').where((s) => s.isNotEmpty).toSet();
        if (!set.add(id)) return const []; // already counted, no new unlocks
        box.put(_kTtsBooks, set.join(','));
        break;
      case AchievementEventKind.streakReached:
        final days = event.streakDays ?? 0;
        final prev = box.get(_kMaxStreak, defaultValue: 0) as int;
        if (days > prev) box.put(_kMaxStreak, days);
        break;
    }

    return _evaluateUnlocks(box);
  }

  /// Walks the catalog and unlocks any badge whose threshold is now satisfied.
  /// Returns IDs unlocked during this evaluation pass — caller surfaces them
  /// as a one-shot toast.
  List<String> _evaluateUnlocks(Box box) {
    final newly = <String>[];
    final booksFinished = box.get(_kBooksFinished, defaultValue: 0) as int;
    final surpriseMe = box.get(_kSurpriseMe, defaultValue: 0) as int;
    final ttsRaw = box.get(_kTtsBooks, defaultValue: '') as String;
    final ttsBooks = ttsRaw.isEmpty
        ? 0
        : ttsRaw.split(',').where((s) => s.isNotEmpty).length;
    final maxStreak = box.get(_kMaxStreak, defaultValue: 0) as int;

    bool meets(String id) {
      switch (id) {
        case AchievementIds.firstBook:
          return booksFinished >= 1;
        case AchievementIds.bookworm:
          return booksFinished >= 5;
        case AchievementIds.streak3:
          return maxStreak >= 3;
        case AchievementIds.streak7:
          return maxStreak >= 7;
        case AchievementIds.streak30:
          return maxStreak >= 30;
        case AchievementIds.surpriseReader:
          return surpriseMe >= 5;
        case AchievementIds.karaokeStar:
          return ttsBooks >= 3;
      }
      return false;
    }

    for (final e in _catalog) {
      final already = box.get(_unlockedKey(e.id), defaultValue: false) as bool;
      if (already) continue;
      if (!meets(e.id)) continue;
      box.put(_unlockedKey(e.id), true);
      box.put(_unlockedAtKey(e.id), DateTime.now().toIso8601String());
      newly.add(e.id);
    }
    return newly;
  }

  /// Lookup helper for toast / dialog rendering — title + icon only.
  Achievement? findById(String id) {
    for (final a in all()) {
      if (a.id == id) return a;
    }
    return null;
  }
}

@immutable
class _CatalogEntry {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  const _CatalogEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Bare service singleton.
final achievementServiceProvider = Provider<AchievementService>((ref) {
  return AchievementService();
});

/// Reactive list of achievements. UI consumers `ref.watch` this; the notifier
/// republishes `service.all()` after each event.
class AchievementsNotifier extends StateNotifier<List<Achievement>> {
  final AchievementService _service;
  AchievementsNotifier(this._service) : super(_service.all());

  /// Records [event] and refreshes state. Returns IDs unlocked during this
  /// call so the caller can surface a one-shot snackbar.
  List<String> record(AchievementEvent event) {
    final unlocked = _service.recordEvent(event);
    if (mounted) {
      state = _service.all();
    }
    return unlocked;
  }
}

final achievementsProvider =
    StateNotifierProvider<AchievementsNotifier, List<Achievement>>((ref) {
  return AchievementsNotifier(ref.watch(achievementServiceProvider));
});
