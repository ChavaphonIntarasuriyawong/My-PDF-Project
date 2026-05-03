import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'recent_books_service.dart';

/// Tracks first-time book completion in the local Hive box so the reader can
/// fire a one-shot confetti + snackbar when the user lands on the last page.
/// Idempotent: revisiting the last page later returns `false` and renders
/// silently.
///
/// Stored alongside the recents list in box `app_prefs` (already opened in
/// `main.dart`). Per-book key is `finished_book_{bookId}` -> bool.
///
/// Deleting a book's recent entry intentionally does NOT clear this flag —
/// finished-state is a separate concern from rail visibility. There is no
/// UI to reset this flag in v1.
class BookFinishService {
  static const String boxName = RecentBooksService.boxName;

  static String _key(String bookId) => 'finished_book_$bookId';

  /// Box may not be open in test environments. Caller paths must tolerate
  /// null and degrade silently — markFinished returns false (no-celebrate).
  Box? get _box {
    try {
      return Hive.box(boxName);
    } catch (_) {
      return null;
    }
  }

  /// Returns `true` if this is the first time we've seen this book finish
  /// (caller should celebrate); `false` if the flag was already set, or if
  /// the Hive box isn't open (test envs).
  Future<bool> markFinished(String bookId) async {
    if (bookId.isEmpty) return false;
    final box = _box;
    if (box == null) return false;
    final already = box.get(_key(bookId), defaultValue: false) as bool;
    if (already) return false;
    await box.put(_key(bookId), true);
    return true;
  }

  bool isFinished(String bookId) {
    if (bookId.isEmpty) return false;
    final box = _box;
    if (box == null) return false;
    return box.get(_key(bookId), defaultValue: false) as bool;
  }
}

/// Provider lets tests inject a fake (mirrors `recentBooksServiceProvider`).
final bookFinishServiceProvider = Provider<BookFinishService>((ref) {
  return BookFinishService();
});
