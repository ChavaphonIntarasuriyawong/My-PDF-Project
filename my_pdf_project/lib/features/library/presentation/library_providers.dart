import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firestore_data_source.dart';
import '../domain/book_model.dart';
import '../domain/bookshelf_model.dart';
import '../domain/note_model.dart';
import '../../auth/presentation/auth_providers.dart';

final firestoreDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  return FirestoreDataSource(ref.watch(firestoreProvider));
});

final shelvesProvider = StreamProvider<List<BookshelfModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreDataSourceProvider).watchShelves(uid);
});

final booksByShelfProvider = StreamProvider.family<List<BookModel>, String>((ref, shelfId) {
  return ref.watch(firestoreDataSourceProvider).watchBooksByShelf(shelfId);
});

final allBooksProvider = StreamProvider<List<BookModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreDataSourceProvider).watchBooks(uid);
});

final noteByBookProvider = FutureProvider.family<NoteModel?, String>((ref, bookId) {
  return ref.watch(firestoreDataSourceProvider).getNoteByBookId(bookId);
});

final bookByIdProvider = StreamProvider.family<BookModel?, String>((ref, bookId) {
  return ref.watch(firestoreDataSourceProvider).watchBook(bookId);
});
