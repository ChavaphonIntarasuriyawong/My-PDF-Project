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
  @override Future<String?> deleteBook(String b) => throw UnimplementedError();
  @override Future<void> updateReadingProgress({required String bookId, required int currentPage, required int totalPages}) => throw UnimplementedError();
  @override Future<void> updateBookStatus(String b, String s) => throw UnimplementedError();
  @override Future<void> updateBookTitle(String b, String t) => throw UnimplementedError();
  @override Future<void> moveBook(String b, String s) => throw UnimplementedError();
  @override Future<void> updateUserProfile(String uid, {String? name}) => throw UnimplementedError();

  @override
  Stream<int> watchUserNotesCount(List<String> bookIds) => Stream.value(0);
  @override Future<NoteModel?> getNoteById(String n) => throw UnimplementedError();
  @override Future<NoteModel> createNote({required String bookId, required String title, required String content}) => throw UnimplementedError();
  @override Future<void> updateNote(String noteId, {required String title, required String content}) => throw UnimplementedError();
  @override Future<void> deleteNote(String noteId) => throw UnimplementedError();
  @override Future<void> deleteNotes(List<String> noteIds) async {}
  @override Stream<List<NoteModel>> watchNotesByBookId(String bookId) => const Stream.empty();
  @override Stream<List<BookshelfModel>> watchShelves(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooks(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooksByShelf({required String shelfId, required String ownerId}) => const Stream.empty();
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
    testWidgets('shows form fields and create button', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pump();
      expect(find.text('PUBLIC PDF URL'), findsOneWidget);
      expect(find.text('PDF FILE'), findsOneWidget);
      expect(find.text('Create PDF'), findsWidgets);
    });

    testWidgets('does not submit with empty fields', (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildScreen(ds));
      await tester.pump();
      await tester.ensureVisible(find.text('Create PDF').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create PDF').first);
      await tester.pump();
      expect(ds.createdBook, isNull);
    });

    // The "creates book and navigates on success" path used to live here as
    // skip:true. Replaced with a hermetic test that exercises the validation
    // branch we CAN reach without the network: a URL with no scheme → instant
    // "Invalid URL scheme" rejection (no http.get call). The successful
    // import branch requires injecting an http.Client into NewBookScreen — an
    // R1 production refactor — so it stays manual-QA-only per the comment in
    // _validateAndExtractMetadata.
    testWidgets('rejects URL with no scheme without calling datasource',
        (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildScreen(ds));
      await tester.pump();
      // Find the URL TextField — it's the first Text input on the screen.
      // LabeledTextField wraps a real TextField, so use byType and pick the
      // first one.
      final textFieldFinder = find.byType(TextField).first;
      await tester.enterText(textFieldFinder, 'not-a-real-url');
      // Tap the Create PDF button next to the URL field. There may be two
      // (one per import method); the URL one is rendered first.
      await tester.ensureVisible(find.text('Create PDF').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create PDF').first);
      await tester.pump();
      // Production logs a SnackBar — we don't assert its content (it varies
      // by error message style). Critical: no book was created downstream.
      expect(ds.createdBook, isNull);
    });

    testWidgets('rejects empty URL with snackbar (no datasource call)',
        (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildScreen(ds));
      await tester.pump();
      // Don't enter any URL — tap directly. Production short-circuits with
      // "Please paste a PDF URL." before any network code runs.
      await tester.ensureVisible(find.text('Create PDF').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create PDF').first);
      await tester.pump();
      expect(ds.createdBook, isNull);
      // The error snackbar is shown via ScaffoldMessenger.
      expect(find.text('Please paste a PDF URL.'), findsOneWidget);
    });

    testWidgets('shows shelf dropdown', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pump();
      expect(find.text('SHELF'), findsWidgets);
      // Default dropdown value when no shelf selected — see _ShelfDropdown.
      expect(find.text('All'), findsWidgets);
    });
  });
}
