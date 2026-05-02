import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'recent_books_service.dart';

/// Snapshot returned by [StreakService.recordOpen]. The caller (reader screen)
/// pushes [count] into the reactive [streakStateProvider] and, if
/// [justHitMilestone] is non-null, queues a celebration for the next time
/// the home screen rebuilds.
class StreakResult {
  /// New streak count after recording today.
  final int count;

  /// One of {7, 30, 100} if today's open just crossed that boundary; else null.
  /// The milestone is recorded as celebrated immediately so consumers never
  /// need to worry about double-firing.
  final int? justHitMilestone;

  const StreakResult({required this.count, this.justHitMilestone});
}

/// Tracks consecutive-day reading streaks, persisted in local Hive box
/// `app_prefs` (already opened in `main.dart`). Stores three keys:
///
///   * `streak_count` (int)         — current consecutive-day count
///   * `streak_last_open_iso` (String) — ISO date with no time, e.g. "2026-05-01"
///   * `streak_milestones_celebrated` (String) — comma-separated list of
///     milestones that have already triggered confetti, e.g. "7,30"
///
/// "Today" is computed in local time — DST jumps and timezone changes can
/// produce off-by-one streaks at the boundary, but persisting the local-day
/// string is the simplest user-visible model.
class StreakService {
  static const String boxName = RecentBooksService.boxName;

  static const String _kCount = 'streak_count';
  static const String _kLast = 'streak_last_open_iso';
  static const String _kMilestones = 'streak_milestones_celebrated';

  /// Milestone breakpoints, in ascending order. The first one the new count
  /// matches is reported by [recordOpen]. Stored as celebrated so we never
  /// re-fire even if the user time-travels.
  static const List<int> milestones = [7, 30, 100];

  /// Box may not be open in test environments that omit Hive setup. Callers
  /// must tolerate null — every read path falls back to defaults, every
  /// write path no-ops silently.
  Box? get _box {
    try {
      return Hive.box(boxName);
    } catch (_) {
      return null;
    }
  }

  String _todayIso() {
    final now = DateTime.now();
    // ISO yyyy-MM-dd, no time. DateTime.toIso8601String() includes the
    // time portion which we don't want as a per-day key.
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// True if [a] is the calendar day before [b] in local time.
  bool _isYesterday(DateTime a, DateTime b) {
    final aDay = DateTime(a.year, a.month, a.day);
    final bDay = DateTime(b.year, b.month, b.day);
    return bDay.difference(aDay).inDays == 1;
  }

  int get current {
    final box = _box;
    if (box == null) return 0;
    return box.get(_kCount, defaultValue: 0) as int;
  }

  String? get lastOpenIso => _box?.get(_kLast) as String?;

  Set<int> _readMilestones() {
    final box = _box;
    if (box == null) return <int>{};
    final raw = box.get(_kMilestones, defaultValue: '') as String;
    if (raw.isEmpty) return <int>{};
    return raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
  }

  Future<void> _writeMilestones(Set<int> set) async {
    final box = _box;
    if (box == null) return;
    final list = set.toList()..sort();
    await box.put(_kMilestones, list.join(','));
  }

  /// Idempotent per day: subsequent calls on the same day after the first one
  /// return the existing count with no milestone (already counted today).
  /// In test envs without an open Hive box this is a no-op returning 0.
  Future<StreakResult> recordOpen() async {
    final box = _box;
    if (box == null) return const StreakResult(count: 0);
    final today = _todayIso();
    final lastIso = box.get(_kLast) as String?;
    final priorCount = box.get(_kCount, defaultValue: 0) as int;

    int newCount;
    if (lastIso == today) {
      // Already counted today — no-op.
      return StreakResult(count: priorCount);
    } else if (lastIso != null) {
      final lastDate = DateTime.tryParse(lastIso);
      final nowDate = DateTime.now();
      if (lastDate != null && _isYesterday(lastDate, nowDate)) {
        newCount = priorCount + 1;
      } else {
        // Older than yesterday or unparseable — streak broken, restart at 1.
        newCount = 1;
      }
    } else {
      // First-ever open.
      newCount = 1;
    }

    await box.put(_kCount, newCount);
    await box.put(_kLast, today);

    // Milestone? Only fire when crossing the boundary (newCount equals exactly
    // the milestone) and it hasn't been celebrated before. Catches the case
    // where a user blasts through 7→8→…→30 without re-celebrating 7 next year.
    final celebrated = _readMilestones();
    int? justHit;
    for (final m in milestones) {
      if (newCount == m && !celebrated.contains(m)) {
        celebrated.add(m);
        justHit = m;
        break;
      }
    }
    if (justHit != null) {
      await _writeMilestones(celebrated);
    }

    return StreakResult(count: newCount, justHitMilestone: justHit);
  }

  /// Returns the next un-celebrated milestone if [current] matches one, then
  /// records it as celebrated. Used by the home screen to fire confetti the
  /// first time the user navigates back after the increment lands. Returns
  /// null if there's nothing pending.
  ///
  /// Note: [recordOpen] also marks the milestone celebrated, so this method
  /// is mainly defensive for cold-starts where the home screen mounts after
  /// recordOpen fired in the reader (the StreakResult was already consumed —
  /// nothing pending here). Kept for the rare path where a milestone landed
  /// while home wasn't mounted.
  Future<int?> takePendingMilestone() async {
    if (_box == null) return null;
    final c = current;
    if (!milestones.contains(c)) return null;
    final celebrated = _readMilestones();
    if (celebrated.contains(c)) return null;
    celebrated.add(c);
    await _writeMilestones(celebrated);
    return c;
  }
}

/// Bare service singleton — overridable for tests.
final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService();
});

/// Reactive int holding the current streak count. Reader's `initState` wires
/// `recordOpen()` and pushes the new count into this notifier; the home pill
/// watches it for live updates without a Hive watcher.
class StreakStateNotifier extends StateNotifier<int> {
  final StreakService _service;
  // Last milestone we surfaced via [pendingMilestone] — cleared by
  // [consumeMilestone] once the home screen has shown its confetti.
  int? _pendingMilestone;

  StreakStateNotifier(this._service) : super(_service.current);

  /// Records today's open and updates state. Returns the result so the caller
  /// can decide whether to fire reader-screen-side confetti for milestones
  /// (we currently surface that on the home screen instead, via
  /// [pendingMilestone]).
  Future<StreakResult> recordOpen() async {
    final res = await _service.recordOpen();
    if (mounted) state = res.count;
    if (res.justHitMilestone != null) {
      _pendingMilestone = res.justHitMilestone;
    }
    return res;
  }

  int? get pendingMilestone => _pendingMilestone;

  void consumeMilestone() {
    _pendingMilestone = null;
  }
}

final streakStateProvider = StateNotifierProvider<StreakStateNotifier, int>((
  ref,
) {
  return StreakStateNotifier(ref.watch(streakServiceProvider));
});
