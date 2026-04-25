import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/library/data/firestore_data_source.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';
import 'package:my_pdf/features/library/domain/note_model.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/features/library/presentation/new_book_screen.dart';
import 'package:my_pdf/shared/widgets/gradient_button.dart';

const _user = UserModel(uid: 'u1', name: 'Alice', email: 'a@b.com');

class _FakeDataSource implements FirestoreDataSource {
  BookModel? createdBook;

  @override
  Future<BookModel> createBook(BookModel book) async {
    createdBook = BookModel(
      id: 'new-id', title: book.title, link: book.link,
      totalPages: 0, currentPage: 0, progress: 0,
      status: 'reading', shelfId: book.shelfId, ownerId: book.ownerId,
    );
    return createdBook!;
  }

  @override Future<BookshelfModel> createShelf({required String name, required String ownerId}) => throw UnimplementedError();
  @override Future<void> updateShelfName(String s, String n) => throw UnimplementedError();
  @override Future<void> deleteShelf(String s) => throw UnimplementedError();
  @override Future<void> deleteBook(String b) => throw UnimplementedError();
  @override Future<void> updateBook(BookModel b) => throw UnimplementedError();
  @override Future<void> updateReadingProgress({required String bookId, required int currentPage, required int totalPages}) => throw UnimplementedError();
  @override Future<void> updateBookStatus(String b, String s) => throw UnimplementedError();
  @override Future<void> moveBook(String b, String s) => throw UnimplementedError();
  @override Future<void> updateUserProfile(String uid, {String? name}) => throw UnimplementedError();
  @override Future<BookModel> getBook(String b) => throw UnimplementedError();
  @override Future<NoteModel?> getNoteByBookId(String b) => throw UnimplementedError();
  @override Future<NoteModel> upsertNote({required String bookId, required String content}) => throw UnimplementedError();
  @override Stream<List<BookshelfModel>> watchShelves(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooks(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooksByShelf(String s) => const Stream.empty();
  @override Stream<BookModel?> watchBook(String b) => const Stream.empty();
}

Widget _buildScreen(_FakeDataSource ds) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const NewBookScreen()),
    GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('Home'))),
    GoRoute(path: '/profile', builder: (_, _) => const Scaffold(body: Text('Profile'))),
    GoRoute(path: '/book/:id', builder: (_, _) => const Scaffold(body: Text('Book Info'))),
  ]);
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((_) => Stream.value(_user)),
      shelvesProvider.overrideWith((_) => Stream.value([])),
      firestoreDataSourceProvider.overrideWithValue(ds),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('NewBookScreen (5.5)', () {
    testWidgets('shows Add Book title and form fields', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pump();
      expect(find.text('Add PDF Link'), findsOneWidget);
      expect(find.text('PDF LINK'), findsOneWidget);
      expect(find.text('BOOK TITLE'), findsOneWidget);
      expect(find.widgetWithText(GradientButton, 'Add to Library'), findsOneWidget);
    });

    testWidgets('does not submit with empty fields', (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildScreen(ds));
      await tester.pump();
      await tester.tap(find.widgetWithText(GradientButton, 'Add to Library'));
      await tester.pump();
      expect(ds.createdBook, isNull);
    });

    testWidgets('creates book and navigates on success', (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildScreen(ds));
      await tester.pump();
      // field 0 = PDF Link (first), field 1 = Book Title (second)
      await tester.enterText(find.byType(TextField).at(0), 'https://pdf.url/cosmos.pdf');
      await tester.enterText(find.byType(TextField).at(1), 'Cosmos');
      await tester.ensureVisible(find.widgetWithText(GradientButton, 'Add to Library'));
      await tester.tap(find.widgetWithText(GradientButton, 'Add to Library'));
      await tester.pumpAndSettle();
      expect(ds.createdBook?.title, 'Cosmos');
      expect(find.text('Book Info'), findsOneWidget);
    });

    testWidgets('shows shelf dropdown', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pump();
      expect(find.text('SHELF'), findsOneWidget);
      expect(find.text('None (Unshelved)'), findsWidgets);
    });
  });
}
