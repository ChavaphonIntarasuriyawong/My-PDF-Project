import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/book_model.dart';
import '../domain/bookshelf_model.dart';
import '../domain/note_model.dart';

class FirestoreDataSource {
  final FirebaseFirestore _db;

  FirestoreDataSource(this._db);

  // --- Bookshelves ---

  Stream<List<BookshelfModel>> watchShelves(String ownerId) {
    return _db
        .collection('bookshelves')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((s) => s.docs.map((d) => BookshelfModel.fromMap(d.id, d.data())).toList());
  }

  Future<BookshelfModel> createShelf({required String name, required String ownerId}) async {
    final doc = _db.collection('bookshelves').doc();
    final shelf = BookshelfModel(id: doc.id, name: name, ownerId: ownerId, createdAt: DateTime.now());
    await doc.set(shelf.toMap());
    return shelf;
  }

  Future<void> updateShelfName(String shelfId, String name) {
    return _db.collection('bookshelves').doc(shelfId).update({'name': name});
  }

  Future<void> deleteShelf(String shelfId) async {
    // Clear shelfId on books that belonged to this shelf (so they don't keep
    // a dangling pointer). Books are preserved — just unshelved.
    final books = await _db
        .collection('books')
        .where('shelfId', isEqualTo: shelfId)
        .get();
    // Firestore caps a single batch at 500 ops. Chunk so a shelf with many
    // books still deletes atomically per-batch (last batch carries the
    // shelf-doc delete to keep the operation observably consistent at end).
    const chunkSize = 499;
    final docs = books.docs;
    if (docs.isEmpty) {
      await _db.collection('bookshelves').doc(shelfId).delete();
      return;
    }
    for (var i = 0; i < docs.length; i += chunkSize) {
      final end = (i + chunkSize > docs.length) ? docs.length : i + chunkSize;
      final batch = _db.batch();
      for (final b in docs.sublist(i, end)) {
        batch.update(b.reference, {'shelfId': ''});
      }
      // Tack the shelf-doc delete onto the final batch.
      if (end >= docs.length) {
        batch.delete(_db.collection('bookshelves').doc(shelfId));
      }
      await batch.commit();
    }
  }

  // --- Books ---

  Stream<List<BookModel>> watchBooks(String ownerId) {
    return _db
        .collection('books')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((s) => s.docs.map((d) => BookModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<BookModel>> watchBooksByShelf({
    required String shelfId,
    required String ownerId,
  }) {
    return _db
        .collection('books')
        .where('ownerId', isEqualTo: ownerId)
        .where('shelfId', isEqualTo: shelfId)
        .snapshots()
        .map((s) => s.docs.map((d) => BookModel.fromMap(d.id, d.data())).toList());
  }

  Future<BookModel> createBook(BookModel book) async {
    final doc = _db.collection('books').doc();
    final newBook = BookModel(
      id: doc.id,
      title: book.title,
      link: book.link,
      totalPages: book.totalPages,
      currentPage: book.currentPage,
      progress: book.progress,
      status: book.status,
      shelfId: book.shelfId,
      ownerId: book.ownerId,
      author: book.author,
      year: book.year,
      needsOcr: book.needsOcr,
    );
    await doc.set(newBook.toMap());
    return newBook;
  }

  Future<void> updateReadingProgress({
    required String bookId,
    required int currentPage,
    required int totalPages,
  }) {
    // PDFView reports `totalPages: 0` during init. Skipping the totalPages +
    // progress fields when 0 prevents corrupting a previously-saved value
    // (which would reset progress to 0% and break auto-resume).
    final updates = <String, dynamic>{
      'currentPage': currentPage,
      'lastReadAt': DateTime.now().toIso8601String(),
    };
    if (totalPages > 0) {
      updates['totalPages'] = totalPages;
      updates['progress'] = currentPage / totalPages * 100;
    }
    return _db.collection('books').doc(bookId).update(updates);
  }

  Future<void> updateBookStatus(String bookId, String status) {
    return _db.collection('books').doc(bookId).update({'status': status});
  }

  Future<void> updateBookTitle(String bookId, String title) {
    return _db.collection('books').doc(bookId).update({'title': title});
  }

  /// Per-book PIN lock toggle (Wave 1).
  /// `lockHash` should be a salted SHA-256-crypt string from
  /// `BookLockHasher.hash()` when locking, or null when unlocking.
  /// Both fields are whitelisted in firestore.rules `books` update rule.
  Future<void> updateBookLock(
    String bookId, {
    required bool isLocked,
    required String? lockHash,
  }) {
    return _db.collection('books').doc(bookId).update({
      'isLocked': isLocked,
      'lockHash': lockHash,
    });
  }

  Future<String?> deleteBook(String bookId) async {
    // Cascade-delete the book's notes so they don't orphan in Firestore.
    // Returns the deleted book's link (so callers can purge storage / cache).
    final bookDoc = await _db.collection('books').doc(bookId).get();
    final link = bookDoc.data()?['link'] as String?;
    final notes = await _db
        .collection('notes')
        .where('bookId', isEqualTo: bookId)
        .get();
    final batch = _db.batch();
    for (final n in notes.docs) {
      batch.delete(n.reference);
    }
    batch.delete(_db.collection('books').doc(bookId));
    await batch.commit();
    return link;
  }

  Future<void> moveBook(String bookId, String newShelfId) {
    return _db.collection('books').doc(bookId).update({'shelfId': newShelfId});
  }

  Stream<BookModel?> watchBook(String bookId) {
    return _db.collection('books').doc(bookId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return BookModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> updateUserProfile(String uid, {String? name}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (updates.isNotEmpty) {
      await _db.collection('users').doc(uid).update(updates);
    }
  }

  // --- Notes ---

  Stream<List<NoteModel>> watchNotesByBookId(String bookId) {
    return _db
        .collection('notes')
        .where('bookId', isEqualTo: bookId)
        .snapshots()
        .map((s) => s.docs.map((d) => NoteModel.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
  }

  Future<NoteModel?> getNoteById(String noteId) async {
    final doc = await _db.collection('notes').doc(noteId).get();
    if (!doc.exists || doc.data() == null) return null;
    return NoteModel.fromMap(doc.id, doc.data()!);
  }

  Future<NoteModel> createNote({
    required String bookId,
    required String title,
    required String content,
  }) async {
    final doc = _db.collection('notes').doc();
    final note = NoteModel(
      id: doc.id,
      bookId: bookId,
      title: title,
      content: content,
      updatedAt: DateTime.now(),
    );
    await doc.set(note.toMap());
    return note;
  }

  Future<void> updateNote(String noteId, {required String title, required String content}) {
    return _db.collection('notes').doc(noteId).update({
      'title': title,
      'content': content,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteNote(String noteId) {
    return _db.collection('notes').doc(noteId).delete();
  }

  /// Batch-delete notes. Firestore caps a single batch at 500 ops, so we
  /// chunk to be safe even though typical selections are tiny.
  Future<void> deleteNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return;
    const chunkSize = 500;
    for (var i = 0; i < noteIds.length; i += chunkSize) {
      final end = (i + chunkSize > noteIds.length) ? noteIds.length : i + chunkSize;
      final batch = _db.batch();
      for (final id in noteIds.sublist(i, end)) {
        batch.delete(_db.collection('notes').doc(id));
      }
      await batch.commit();
    }
  }

  Stream<int> watchUserNotesCount(List<String> bookIds) {
    if (bookIds.isEmpty) return Stream.value(0);

    // Firestore whereIn caps at 30 entries — chunk and combine via stream merge.
    final chunks = <List<String>>[];
    for (var i = 0; i < bookIds.length; i += 30) {
      chunks.add(bookIds.sublist(i, i + 30 > bookIds.length ? bookIds.length : i + 30));
    }

    final counts = List<int>.filled(chunks.length, 0);
    final controller = StreamController<int>.broadcast();
    final subs = <StreamSubscription>[];

    for (var i = 0; i < chunks.length; i++) {
      final idx = i;
      final sub = _db
          .collection('notes')
          .where('bookId', whereIn: chunks[i])
          .snapshots()
          .listen((s) {
        counts[idx] = s.docs.length;
        controller.add(counts.fold<int>(0, (a, b) => a + b));
      });
      subs.add(sub);
    }

    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return controller.stream;
  }
}
