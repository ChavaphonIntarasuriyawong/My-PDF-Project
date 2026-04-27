import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/book_model.dart';

class FirestoreDataSource {
  final FirebaseFirestore _db;

  FirestoreDataSource(this._db);

  // --- Books ---

  Stream<List<BookModel>> watchBooks(String ownerId) {
    return _db
        .collection('books')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((s) => s.docs.map((d) => BookModel.fromMap(d.id, d.data())).toList());
  }

  Future<BookModel?> getBook(String bookId) async {
    final doc = await _db.collection('books').doc(bookId).get();
    if (!doc.exists || doc.data() == null) return null;
    return BookModel.fromMap(doc.id, doc.data()!);
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
      ownerId: book.ownerId,
      author: book.author,
      year: book.year,
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

  Future<void> updateBookTitle(String bookId, String title) {
    return _db.collection('books').doc(bookId).update({'title': title});
  }

  Future<String?> deleteBook(String bookId) async {
    // Returns the deleted book's link (so callers can purge storage / cache).
    final bookDoc = await _db.collection('books').doc(bookId).get();
    final link = bookDoc.data()?['link'] as String?;
    await _db.collection('books').doc(bookId).delete();
    return link;
  }

  Stream<BookModel?> watchBook(String bookId) {
    return _db.collection('books').doc(bookId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return BookModel.fromMap(doc.id, doc.data()!);
    });
  }
}
