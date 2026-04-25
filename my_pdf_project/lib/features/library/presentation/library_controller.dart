import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/book_model.dart';
import '../domain/note_model.dart';
import 'library_providers.dart';

class LibraryController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  LibraryController(this._ref) : super(const AsyncValue.data(null));

  Future<bool> createShelf(String name, String ownerId) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(firestoreDataSourceProvider).createShelf(name: name, ownerId: ownerId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateShelfName(String shelfId, String name) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(firestoreDataSourceProvider).updateShelfName(shelfId, name);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteShelf(String shelfId) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(firestoreDataSourceProvider).deleteShelf(shelfId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<BookModel?> createBook(BookModel book) async {
    state = const AsyncValue.loading();
    try {
      final created = await _ref.read(firestoreDataSourceProvider).createBook(book);
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteBook(String bookId) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(firestoreDataSourceProvider).deleteBook(bookId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateProgress({
    required String bookId,
    required int currentPage,
    required int totalPages,
  }) async {
    try {
      await _ref.read(firestoreDataSourceProvider).updateReadingProgress(
        bookId: bookId,
        currentPage: currentPage,
        totalPages: totalPages,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateStatus(String bookId, String status) async {
    try {
      await _ref.read(firestoreDataSourceProvider).updateBookStatus(bookId, status);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<NoteModel?> saveNote({required String bookId, required String content}) async {
    try {
      return await _ref.read(firestoreDataSourceProvider).upsertNote(bookId: bookId, content: content);
    } catch (_) {
      return null;
    }
  }
}

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, AsyncValue<void>>((ref) => LibraryController(ref));
