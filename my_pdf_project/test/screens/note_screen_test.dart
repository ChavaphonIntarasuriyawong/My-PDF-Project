import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/library/data/firestore_data_source.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';
import 'package:my_pdf/features/library/domain/note_model.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/features/reader/presentation/note_screen.dart';

const _book = BookModel(
  id: 'b1', title: 'Cosmos', link: '',
  totalPages: 200, currentPage: 100, progress: 50,
  status: 'reading', shelfId: 's1', ownerId: 'u1',
);

final _note1 = NoteModel(id: 'n1', bookId: 'b1', title: 'Title 1', content: 'Note one', updatedAt: DateTime(2025, 1, 1));
final _note2 = NoteModel(id: 'n2', bookId: 'b1', title: 'Title 2', content: 'Note two', updatedAt: DateTime(2025, 1, 2));

class _FakeDataSource implements FirestoreDataSource {
  String? deletedNoteId;
  final List<NoteModel> notes;

  _FakeDataSource({this.notes = const []});

  @override
  Stream<List<NoteModel>> watchNotesByBookId(String bookId) => Stream.value(notes);

  @override
  Future<void> deleteNote(String noteId) async {
    deletedNoteId = noteId;
  }

  @override Future<NoteModel?> getNoteById(String n) => throw UnimplementedError();
  @override Future<NoteModel> createNote({required String bookId, required String title, required String content}) => throw UnimplementedError();
  @override Future<void> updateNote(String noteId, {required String title, required String content}) => throw UnimplementedError();
  @override Future<BookshelfModel> createShelf({required String name, required String ownerId}) => throw UnimplementedError();
  @override Future<void> updateShelfName(String s, String n) => throw UnimplementedError();
  @override Future<void> deleteShelf(String s) => throw UnimplementedError();
  @override Future<BookModel> createBook(BookModel b) => throw UnimplementedError();
  @override Future<String?> deleteBook(String b) => throw UnimplementedError();
  @override Future<void> updateBook(BookModel b) => throw UnimplementedError();
  @override Future<void> updateReadingProgress({required String bookId, required int currentPage, required int totalPages}) => throw UnimplementedError();
  @override Future<void> updateBookStatus(String b, String s) => throw UnimplementedError();
  @override Future<void> updateBookTitle(String b, String t) => throw UnimplementedError();
  @override Future<void> moveBook(String b, String s) => throw UnimplementedError();
  @override Future<void> updateUserProfile(String uid, {String? name}) => throw UnimplementedError();
  @override Stream<int> watchUserNotesCount(List<String> bookIds) => Stream.value(0);
  @override Future<BookModel?> getBook(String b) => throw UnimplementedError();
  @override Stream<List<BookshelfModel>> watchShelves(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooks(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooksByShelf(String s) => const Stream.empty();
  @override Stream<BookModel?> watchBook(String b) => Stream.value(_book);
}

Widget _buildScreen(_FakeDataSource ds, {List<NoteModel> notes = const []}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/book/:id/note',
      builder: (_, state) => NoteScreen(bookId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/book/:id', builder: (_, _) => const Scaffold(body: Text('Book Info'))),
    GoRoute(path: '/book/:id/note/edit', builder: (_, _) => const Scaffold(body: Text('Edit'))),
  ], initialLocation: '/book/b1/note');

  return ProviderScope(
    overrides: [
      bookByIdProvider('b1').overrideWith((_) => Stream.value(_book)),
      notesByBookProvider('b1').overrideWith((_) => Stream.value(notes)),
      firestoreDataSourceProvider.overrideWithValue(ds),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('NoteScreen (5.9)', () {
    testWidgets('shows book title in header', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pumpAndSettle();
      expect(find.text('Cosmos'), findsOneWidget);
    });

    testWidgets('shows empty state when no notes', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pumpAndSettle();
      expect(find.textContaining('No notes yet'), findsOneWidget);
    });

    testWidgets('shows Add Note FAB', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pumpAndSettle();
      expect(find.text('Add Note'), findsOneWidget);
    });

    testWidgets('lists multiple notes', (tester) async {
      final ds = _FakeDataSource(notes: [_note1, _note2]);
      await tester.pumpWidget(_buildScreen(ds, notes: [_note1, _note2]));
      await tester.pumpAndSettle();
      expect(find.text('Note one'), findsOneWidget);
      expect(find.text('Note two'), findsOneWidget);
    });
  });
}
