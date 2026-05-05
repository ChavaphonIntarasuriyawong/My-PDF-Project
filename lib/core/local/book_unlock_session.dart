/// In-memory cache of book IDs the user has unlocked this session. Lifetime is
/// the process lifetime (intentionally NOT persisted to Hive) — closing or
/// killing the app re-locks every book. Cleared on logout (wired in Wave 4).
class BookUnlockSession {
  final Set<String> _unlocked = <String>{};

  bool isUnlocked(String bookId) => _unlocked.contains(bookId);
  void markUnlocked(String bookId) => _unlocked.add(bookId);
  void lock(String bookId) => _unlocked.remove(bookId);
  void clear() => _unlocked.clear();
}
