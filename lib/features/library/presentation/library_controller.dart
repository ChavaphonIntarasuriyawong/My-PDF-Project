import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      if (n.isEmpty) {
        throw DuplicateNameException('Title cannot be empty.');
      }
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
      final link =
          await _ref.read(firestoreDataSourceProvider).deleteBook(bookId);
      // Drop from local recents so the home rail doesn't show a dead pointer.
      await _ref.read(recentBooksServiceProvider).remove(bookId);
      // Best-effort storage + cache cleanup. Failures here are non-fatal —
      // book + notes are already removed from Firestore at this point.
      if (link != null && link.isNotEmpty) {
        unawaited(_purgeStorageAndCache(link));
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> _purgeStorageAndCache(String link) async {
    // Supabase: remove the bucket object if this book was an upload.
    final supaMarker = '/storage/v1/object/public/pdfs/';
    final idx = link.indexOf(supaMarker);
    if (idx >= 0) {
      final path = link.substring(idx + supaMarker.length);
      try {
        await Supabase.instance.client.storage.from('pdfs').remove([path]);
      } catch (_) {/* ignore — already gone or auth/policy */}
    }
    // Local: drop the cached download / thumbnail.
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final cached = File('${docs.path}/pdf_${link.hashCode.abs()}.pdf');
      if (await cached.exists()) await cached.delete();
      final thumb =
          File('${docs.path}/thumbs/thumb_${link.hashCode.abs()}.jpg');
      if (await thumb.exists()) await thumb.delete();
    } catch (_) {/* ignore */}
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
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateStatus(String bookId, String status) async {
    try {
      await _ref.read(firestoreDataSourceProvider).updateBookStatus(bookId, status);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> renameBook(String bookId, String newTitle) async {
    try {
      final existing = _ref.read(allBooksProvider).valueOrNull ?? [];
      final n = _norm(newTitle);
      if (n.isEmpty) {
        throw DuplicateNameException('Title cannot be empty.');
      }
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
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<NoteModel?> createNote({
    required String bookId,
    required String title,
    required String content,
  }) async {
    try {
      return await _ref
          .read(firestoreDataSourceProvider)
          .createNote(bookId: bookId, title: title, content: content);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> updateNote(String noteId, {required String title, required String content}) async {
    try {
      await _ref.read(firestoreDataSourceProvider)
          .updateNote(noteId, title: title, content: content);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteNote(String noteId) async {
    try {
      await _ref.read(firestoreDataSourceProvider).deleteNote(noteId);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Batch-delete several notes — used by the multi-select UX on book info.
  Future<bool> deleteNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return true;
    try {
      await _ref.read(firestoreDataSourceProvider).deleteNotes(noteIds);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, AsyncValue<void>>((ref) => LibraryController(ref));
