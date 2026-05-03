import 'package:my_pdf/core/local/recent_books_service.dart';

/// In-memory stub for tests so widget/controller tests don't need a real Hive
/// box. Implements the public API of `RecentBooksService` only — the private
/// `_box` getter on the real class is invisible across libraries, so it doesn't
/// need to be implemented here.
class FakeRecentBooksService implements RecentBooksService {
  final List<String> _ids = [];

  @override
  List<String> get ids => List.unmodifiable(_ids);

  @override
  Future<void> markOpened(String bookId) async {
    _ids.remove(bookId);
    _ids.insert(0, bookId);
  }

  @override
  Future<void> remove(String bookId) async {
    _ids.remove(bookId);
  }

  @override
  Future<void> clear() async {
    _ids.clear();
  }

  @override
  Stream<List<String>> watch() async* {
    yield ids;
  }
}
