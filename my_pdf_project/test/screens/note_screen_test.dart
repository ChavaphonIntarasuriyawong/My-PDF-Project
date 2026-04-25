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
import 'package:my_pdf/shared/widgets/gradient_button.dart';

const _book = BookModel(
  id: 'b1', title: 'Cosmos', link: '',
  totalPages: 200, currentPage: 100, progress: 50,
  status: 'reading', shelfId: 's1', ownerId: 'u1',
);

final _note = NoteModel(id: 'n1', bookId: 'b1', content: 'Existing note', updatedAt: DateTime(2025));

class _FakeDataSource implements FirestoreDataSource {
  NoteModel? savedNote;

  @override
  Future<NoteModel> upsertNote({required String bookId, required String content}) async {
    savedNote = NoteModel(id: 'n1', bookId: bookId, content: content, updatedAt: DateTime.now());
    return savedNote!;
  }

  @override Future<BookshelfModel> createShelf({required String name, required String ownerId}) => throw UnimplementedError();
  @override Future<void> updateShelfName(String s, String n) => throw UnimplementedError();
  @override Future<void> deleteShelf(String s) => throw UnimplementedError();
  @override Future<BookModel> createBook(BookModel b) => throw UnimplementedError();
  @override Future<void> deleteBook(String b) => throw UnimplementedError();
  @override Future<void> updateBook(BookModel b) => throw UnimplementedError();
  @override Future<void> updateReadingProgress({required String bookId, required int currentPage, required int totalPages}) => throw UnimplementedError();
  @override Future<void> updateBookStatus(String b, String s) => throw UnimplementedError();
  @override Future<void> moveBook(String b, String s) => throw UnimplementedError();
  @override Future<void> updateUserProfile(String uid, {String? name}) => throw UnimplementedError();
  @override Future<BookModel> getBook(String b) => throw UnimplementedError();
  @override Future<NoteModel?> getNoteByBookId(String b) async => _note;
  @override Stream<List<BookshelfModel>> watchShelves(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooks(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooksByShelf(String s) => const Stream.empty();
  @override Stream<BookModel?> watchBook(String b) => Stream.value(_book);
}

Widget _buildScreen(_FakeDataSource ds) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/book/:id/note',
      builder: (_, state) => NoteScreen(bookId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/book/:id', builder: (_, _) => const Scaffold(body: Text('Book Info'))),
  ], initialLocation: '/book/b1/note');

  return ProviderScope(
    overrides: [
      bookByIdProvider('b1').overrideWith((_) => Stream.value(_book)),
      noteByBookProvider('b1').overrideWith((_) async => _note),
      firestoreDataSourceProvider.overrideWithValue(ds),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('NoteScreen (5.9)', () {
    testWidgets('shows Notes header and book title', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pumpAndSettle();
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Cosmos'), findsOneWidget);
    });

    testWidgets('shows page info', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pumpAndSettle();
      expect(find.text('Page 100 of 200'), findsOneWidget);
    });

    testWidgets('pre-fills existing note content', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller?.text, 'Existing note');
    });

    testWidgets('shows Save Note button', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(GradientButton, 'Save Note'), findsOneWidget);
    });

    testWidgets('saves note and shows snackbar', (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildScreen(ds));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'New note content');
      await tester.tap(find.widgetWithText(GradientButton, 'Save Note'));
      await tester.pumpAndSettle();
      expect(ds.savedNote?.content, 'New note content');
      expect(find.text('Note saved'), findsOneWidget);
    });

    testWidgets('shows My Notes section label', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pumpAndSettle();
      expect(find.text('My Notes'), findsOneWidget);
    });
  });
}
