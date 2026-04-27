import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/library/data/firestore_data_source.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';
import 'package:my_pdf/features/library/domain/note_model.dart';
import 'package:my_pdf/features/library/presentation/book_info_screen.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';

const _book = BookModel(
  id: 'b1', title: 'Cosmos', link: 'https://pdf.url',
  totalPages: 200, currentPage: 100, progress: 50,
  status: 'reading', shelfId: 's1', ownerId: 'u1',
);

class _FakeDataSource implements FirestoreDataSource {
  String? updatedStatus;

  @override Future<void> updateBookStatus(String b, String s) async => updatedStatus = s;
  @override Future<void> updateBookTitle(String b, String t) async {}
  @override Future<String?> deleteBook(String b) async => null;

  @override Future<BookshelfModel> createShelf({required String name, required String ownerId}) => throw UnimplementedError();
  @override Future<void> updateShelfName(String s, String n) => throw UnimplementedError();
  @override Future<void> deleteShelf(String s) => throw UnimplementedError();
  @override Future<BookModel> createBook(BookModel b) => throw UnimplementedError();
  @override Future<void> updateBook(BookModel b) => throw UnimplementedError();
  @override Future<void> updateReadingProgress({required String bookId, required int currentPage, required int totalPages}) => throw UnimplementedError();
  @override Future<void> moveBook(String b, String s) => throw UnimplementedError();
  @override Future<void> updateUserProfile(String uid, {String? name}) => throw UnimplementedError();

  @override
  Stream<int> watchUserNotesCount(List<String> bookIds) => Stream.value(0);
  @override Future<BookModel?> getBook(String b) => throw UnimplementedError();
  @override Future<NoteModel?> getNoteById(String n) => throw UnimplementedError();
  @override Future<NoteModel> createNote({required String bookId, required String title, required String content}) => throw UnimplementedError();
  @override Future<void> updateNote(String noteId, {required String title, required String content}) => throw UnimplementedError();
  @override Future<void> deleteNote(String noteId) => throw UnimplementedError();
  @override Stream<List<NoteModel>> watchNotesByBookId(String bookId) => const Stream.empty();
  @override Stream<List<BookshelfModel>> watchShelves(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooks(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooksByShelf(String s) => const Stream.empty();
  @override Stream<BookModel?> watchBook(String b) => Stream.value(_book);
}

Widget _buildScreen() {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/book/:id',
      builder: (_, state) => BookInfoScreen(bookId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('Home'))),
    GoRoute(path: '/book/new', builder: (_, _) => const Scaffold(body: Text('New Book'))),
    GoRoute(path: '/profile', builder: (_, _) => const Scaffold(body: Text('Profile'))),
    GoRoute(path: '/book/:id/reading', builder: (_, _) => const Scaffold(body: Text('Reading'))),
    GoRoute(path: '/book/:id/note', builder: (_, _) => const Scaffold(body: Text('Notes'))),
  ], initialLocation: '/book/b1');

  return ProviderScope(
    overrides: [
      bookByIdProvider('b1').overrideWith((_) => Stream.value(_book)),
      firestoreDataSourceProvider.overrideWithValue(_FakeDataSource()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('BookInfoScreen (5.8)', () {
    testWidgets('shows book title', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // Title shown both in header and body now.
      expect(find.text('Cosmos'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows reading progress text', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Reading Progress'), findsOneWidget);
      expect(find.text('100 / 200 pages'), findsOneWidget);
      expect(find.text('50% complete'), findsOneWidget);
    });

    testWidgets('shows pencil FAB to start reading', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('shows Add Note button', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Add Note'), findsOneWidget);
    });

    testWidgets('shows 3-dot options menu icon', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('shows status badge', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('READING'), findsOneWidget);
    });

    testWidgets('FAB tap is registered', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // Just check FAB exists and is tappable; don't test full navigation
      // (reading screen async PDF fetch makes pumpAndSettle hang).
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      final widget = tester.widget<FloatingActionButton>(fab);
      expect(widget.onPressed, isNotNull);
    });
  });
}
