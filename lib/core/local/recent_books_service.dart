import 'package:hive/hive.dart';

/// Tracks book IDs the user has recently opened in the reader, ordered
/// most-recent-first. Stored locally via Hive (no cloud sync) so the home
/// screen can surface a "Recently Opened" shortcut even offline.
class RecentBooksService {
  static const String boxName = 'app_prefs';
  static const String _key = 'recent_book_ids';
  static const int maxItems = 10;

  Box get _box => Hive.box(boxName);

  List<String> get ids =>
      List<String>.from(_box.get(_key, defaultValue: <String>[]) as List);

  Future<void> markOpened(String bookId) async {
    if (bookId.isEmpty) return;
    final list = ids;
    list.remove(bookId);
    list.insert(0, bookId);
    if (list.length > maxItems) {
      list.removeRange(maxItems, list.length);
    }
    await _box.put(_key, list);
  }

  Future<void> remove(String bookId) async {
    final list = ids;
    if (list.remove(bookId)) {
      await _box.put(_key, list);
    }
  }

  Future<void> clear() async {
    await _box.put(_key, <String>[]);
  }

  Stream<List<String>> watch() async* {
    yield ids;
    await for (final _ in _box.watch(key: _key)) {
      yield ids;
    }
  }
}
