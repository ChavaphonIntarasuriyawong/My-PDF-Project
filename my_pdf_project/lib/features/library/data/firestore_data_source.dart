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

  Future<void> deleteShelf(String shelfId) {
    return _db.collection('bookshelves').doc(shelfId).delete();
  }

  // --- Books ---

  Stream<List<BookModel>> watchBooks(String ownerId) {
    return _db
        .collection('books')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((s) => s.docs.map((d) => BookModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<BookModel>> watchBooksByShelf(String shelfId) {
    return _db
        .collection('books')
        .where('shelfId', isEqualTo: shelfId)
        .snapshots()
        .map((s) => s.docs.map((d) => BookModel.fromMap(d.id, d.data())).toList());
  }

  Future<BookModel> getBook(String bookId) async {
    final doc = await _db.collection('books').doc(bookId).get();
    return BookModel.fromMap(doc.id, doc.data()!);
  }

  Future<BookModel> createBook(BookModel book) async {
    final doc = _db.collection('books').doc();
    final newBook = BookModel(
      id: doc.id,
      title: book.title,
      link: book.link,
      coverUrl: book.coverUrl,
      totalPages: book.totalPages,
      currentPage: book.currentPage,
      progress: book.progress,
      status: book.status,
      shelfId: book.shelfId,
      ownerId: book.ownerId,
    );
    await doc.set(newBook.toMap());
    return newBook;
  }

  Future<void> updateBook(BookModel book) {
    return _db.collection('books').doc(book.id).update(book.toMap());
  }

  Future<void> updateReadingProgress({
    required String bookId,
    required int currentPage,
    required int totalPages,
  }) {
    final progress = totalPages > 0 ? currentPage / totalPages * 100 : 0.0;
    return _db.collection('books').doc(bookId).update({
      'currentPage': currentPage,
      'totalPages': totalPages,
      'progress': progress,
      'lastReadAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateBookStatus(String bookId, String status) {
    return _db.collection('books').doc(bookId).update({'status': status});
  }

  Future<void> deleteBook(String bookId) {
    return _db.collection('books').doc(bookId).delete();
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

  Future<NoteModel?> getNoteByBookId(String bookId) async {
    final snap = await _db.collection('notes').where('bookId', isEqualTo: bookId).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return NoteModel.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  Future<NoteModel> upsertNote({required String bookId, required String content}) async {
    final snap = await _db.collection('notes').where('bookId', isEqualTo: bookId).limit(1).get();
    if (snap.docs.isEmpty) {
      final doc = _db.collection('notes').doc();
      final note = NoteModel(id: doc.id, bookId: bookId, content: content, updatedAt: DateTime.now());
      await doc.set(note.toMap());
      return note;
    } else {
      final doc = snap.docs.first;
      await doc.reference.update({'content': content, 'updatedAt': DateTime.now().toIso8601String()});
      return NoteModel.fromMap(doc.id, {...doc.data(), 'content': content});
    }
  }
}
