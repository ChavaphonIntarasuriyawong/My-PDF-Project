import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/book_model.dart';
import '../domain/note_model.dart';
import 'library_providers.dart';

class DuplicateNameException implements Exception {
  final String message;
  DuplicateNameException(this.message);
  @override
  String toString() => message;
}

class LibraryController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  LibraryController(this._ref) : super(const AsyncValue.data(null));

  String _norm(String s) => s.trim().toLowerCase();

  Future<bool> createShelf(String name, String ownerId) async {
    state = const AsyncValue.loading();
    try {
      final existing = _ref.read(shelvesProvider).valueOrNull ?? [];
      final n = _norm(name);
      if (existing.any((s) => _norm(s.name) == n)) {
        throw DuplicateNameException('A shelf named "$name" already exists.');
      }
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
      final existing = _ref.read(shelvesProvider).valueOrNull ?? [];
      final n = _norm(name);
      if (existing.any((s) => s.id != shelfId && _norm(s.name) == n)) {
        throw DuplicateNameException('A shelf named "$name" already exists.');
      }
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
      final existing = _ref.read(allBooksProvider).valueOrNull ?? [];
      final n = _norm(book.title);
      if (existing.any((b) => _norm(b.title) == n)) {
        throw DuplicateNameException('A book titled "${book.title}" already exists.');
      }
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

  Future<bool> renameBook(String bookId, String newTitle) async {
    try {
      final existing = _ref.read(allBooksProvider).valueOrNull ?? [];
      final n = _norm(newTitle);
      if (existing.any((b) => b.id != bookId && _norm(b.title) == n)) {
        throw DuplicateNameException('A book titled "$newTitle" already exists.');
      }
      await _ref.read(firestoreDataSourceProvider)
          .updateBookTitle(bookId, newTitle);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> moveBook(String bookId, String newShelfId) async {
    try {
      await _ref.read(firestoreDataSourceProvider).moveBook(bookId, newShelfId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<NoteModel?> createNote({required String bookId, required String content}) async {
    try {
      return await _ref.read(firestoreDataSourceProvider).createNote(bookId: bookId, content: content);
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateNoteContent(String noteId, String content) async {
    try {
      await _ref.read(firestoreDataSourceProvider).updateNoteContent(noteId, content);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteNote(String noteId) async {
    try {
      await _ref.read(firestoreDataSourceProvider).deleteNote(noteId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, AsyncValue<void>>((ref) => LibraryController(ref));
