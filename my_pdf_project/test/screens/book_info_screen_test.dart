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

final _note1 = NoteModel(
  id: 'n1', bookId: 'b1', title: 'Title 1',
  content: 'Note one', updatedAt: DateTime(2025, 1, 1),
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
  @override Future<void> deleteNotes(List<String> noteIds) async {}
  @override Stream<List<NoteModel>> watchNotesByBookId(String bookId) => Stream.value(const []);
  @override Stream<List<BookshelfModel>> watchShelves(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooks(String o) => const Stream.empty();
  @override Stream<List<BookModel>> watchBooksByShelf(String s) => const Stream.empty();
  @override Stream<BookModel?> watchBook(String b) => Stream.value(_book);
}

Widget _buildScreen({
  List<NoteModel> notes = const [],
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/book/:id',
        builder: (_, state) => BookInfoScreen(bookId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('Home'))),
      GoRoute(path: '/book/new', builder: (_, _) => const Scaffold(body: Text('New Book'))),
      GoRoute(path: '/profile', builder: (_, _) => const Scaffold(body: Text('Profile'))),
      GoRoute(path: '/book/:id/reading', builder: (_, _) => const Scaffold(body: Text('Reading'))),
      GoRoute(path: '/book/:id/note', builder: (_, _) => const Scaffold(body: Text('Notes'))),
    ],
    initialLocation: '/book/b1',
  );

  return ProviderScope(
    overrides: [
      bookByIdProvider('b1').overrideWith((_) => Stream.value(_book)),
      notesByBookProvider('b1').overrideWith((_) => Stream.value(notes)),
      firestoreDataSourceProvider.overrideWithValue(_FakeDataSource()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Sets a tablet-sized viewport tall enough to contain the cover card +
/// notes section without scrolling. The default test surface (800x600) is
/// too short — the pencil and note cards land off-screen. We pick 800 wide
/// so the bottom-nav bar doesn't overflow at narrower phone widths
/// (production has a known 2px tight fit around 412px).
Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('BookInfoScreen (5.8)', () {
    testWidgets('shows book title', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // Title shown both in header and body now.
      expect(find.text('Cosmos'), findsAtLeastNWidgets(1));
    });

    testWidgets('inline pencil read button navigates to reading screen',
        (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      // Inline pencil sits inside the cover Stack — find by icon. The
      // 3-dot menu uses Icons.more_vert, so Icons.edit_outlined uniquely
      // identifies the pencil. Confirm "Reading" placeholder is not yet
      // visible (we're still on /book/b1).
      final pencil = find.byIcon(Icons.edit_outlined);
      expect(pencil, findsOneWidget);
      expect(find.text('Reading'), findsNothing);

      // Tap the pencil — production calls context.push('/book/b1/reading').
      await tester.tap(pencil);
      // Let the new route build and the cover thumbnail provider settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the reading-route placeholder is now mounted.
      expect(find.text('Reading'), findsOneWidget);
    });

    testWidgets('shows Add Note button', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(_buildScreen());
      // Notes stream is async — pump multiple frames so notesAsync moves
      // from loading to data and the Add Note button mounts.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Add Note'), findsOneWidget);
    });

    testWidgets('shows 3-dot options menu icon', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets(
        'enters selection mode on long-press and shows Cancel + Delete buttons',
        (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(_buildScreen(notes: [_note1]));
      // Pump a few frames so the notes stream resolves.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Note card preview uses the title. Confirm it rendered before
      // attempting the long-press.
      final noteCard = find.text('Title 1');
      expect(noteCard, findsOneWidget);

      await tester.longPress(noteCard);
      await tester.pump();

      // Selection top bar swap: the 3-dot icon disappears, Cancel + Delete
      // text buttons appear in its place.
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(
        find.descendant(of: find.byType(TextButton), matching: find.text('Cancel')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(TextButton), matching: find.text('Delete')),
        findsOneWidget,
      );
    });
  });
}
