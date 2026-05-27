import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/library/data/firestore_data_source.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';
import 'package:my_pdf/features/library/domain/note_model.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/features/reader/presentation/note_edit_screen.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _book = BookModel(
  id: 'b1',
  title: 'Cosmos',
  link: '',
  totalPages: 200,
  currentPage: 100,
  progress: 50,
  status: 'reading',
  shelfId: 's1',
  ownerId: 'u1',
);

final _existingNote = NoteModel(
  id: 'n1',
  bookId: 'b1',
  title: 'Old Title',
  content: 'Old content',
  updatedAt: DateTime(2025, 1, 1),
);

// ---------------------------------------------------------------------------
// Fake data source
// ---------------------------------------------------------------------------

class _FakeDataSource implements FirestoreDataSource {
  NoteModel? createdNote;
  String? updatedNoteId;
  String? updatedTitle;
  String? updatedContent;

  _FakeDataSource();

  @override
  Future<NoteModel> createNote({
    required String bookId,
    required String title,
    required String content,
  }) async {
    createdNote = NoteModel(
      id: 'n_new',
      bookId: bookId,
      title: title,
      content: content,
      updatedAt: DateTime(2025),
    );
    return createdNote!;
  }

  @override
  Future<void> updateNote(
    String noteId, {
    required String title,
    required String content,
  }) async {
    updatedNoteId = noteId;
    updatedTitle = title;
    updatedContent = content;
  }

  @override
  Future<NoteModel?> getNoteById(String noteId) async => _existingNote;

  // Stubs for unused interface members.
  @override
  Future<BookshelfModel> createShelf({
    required String name,
    required String ownerId,
  }) => throw UnimplementedError();
  @override
  Future<void> updateShelfName(String s, String n) =>
      throw UnimplementedError();
  @override
  Future<void> deleteShelf(String s) => throw UnimplementedError();
  @override
  Future<BookModel> createBook(BookModel b) => throw UnimplementedError();
  @override
  Future<String?> deleteBook(String b) => throw UnimplementedError();
  @override
  Future<void> updateReadingProgress({
    required String bookId,
    required int currentPage,
    required int totalPages,
  }) => throw UnimplementedError();
  @override
  Future<void> updateBookStatus(String b, String s) =>
      throw UnimplementedError();
  @override
  Future<void> updateBookTitle(String b, String t) =>
      throw UnimplementedError();
  @override
  Future<void> moveBook(String b, String s) => throw UnimplementedError();
  @override
  Future<void> updateUserProfile(String uid, {String? name}) =>
      throw UnimplementedError();
  @override
  Future<void> deleteNote(String noteId) async {}
  @override
  Future<void> deleteNotes(List<String> noteIds) async {}
  @override
  Stream<int> watchUserNotesCount(List<String> bookIds) => Stream.value(0);
  @override
  Stream<List<BookshelfModel>> watchShelves(String o) => const Stream.empty();
  @override
  Stream<List<BookModel>> watchBooks(String o) => const Stream.empty();
  @override
  Stream<List<BookModel>> watchBooksByShelf({
    required String shelfId,
    required String ownerId,
  }) => const Stream.empty();
  @override
  Stream<BookModel?> watchBook(String b) => Stream.value(_book);
  @override
  Stream<List<NoteModel>> watchNotesByBookId(String bookId) =>
      Stream.value(const []);
}

// ---------------------------------------------------------------------------
// Builder helpers
// ---------------------------------------------------------------------------

/// Wraps [NoteEditSheet] in a minimal GoRouter scaffold so [context.go] and
/// [Navigator.of(context).pop()] work inside the sheet.
Widget _buildSheet(_FakeDataSource ds, {String bookId = 'b1', String? noteId}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: ctx,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                // Mirror the real showNoteEditSheet caller so the sheet gets
                // the same sizing context in tests.
                builder: (innerCtx) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(innerCtx).viewInsets.bottom,
                  ),
                  child: FractionallySizedBox(
                    heightFactor: 0.9,
                    child: NoteEditSheet(bookId: bookId, noteId: noteId),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/book/new',
        builder: (_, _) => const Scaffold(body: Text('New')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('Profile')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      firestoreDataSourceProvider.overrideWithValue(ds),
      bookByIdProvider('b1').overrideWith((_) => Stream.value(_book)),
      notesByBookProvider('b1').overrideWith((_) => Stream.value(const [])),
      pdfThumbnailProvider(
        '',
      ).overrideWith((_) => Future<Uint8List?>.value(null)),
      if (noteId != null)
        noteByIdProvider(
          noteId,
        ).overrideWith((_) => Future.value(_existingNote)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  // Use a phone-sized tall window so the sheet (64px top bar + 309px PDF
  // preview + note content + nav bar) has enough room without overflowing.
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('NoteEditSheet — create mode', () {
    testWidgets('renders empty title and body fields', (tester) async {
      await tester.pumpWidget(_buildSheet(_FakeDataSource()));
      await _openSheet(tester);

      expect(find.text('Title of this thought…'), findsOneWidget);
      expect(find.text('Synthesize your insights here…'), findsOneWidget);
    });

    testWidgets('shows Done and Save Note buttons', (tester) async {
      await tester.pumpWidget(_buildSheet(_FakeDataSource()));
      await _openSheet(tester);

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Save Note'), findsOneWidget);
    });

    testWidgets('shows snackbar when saving with empty body', (tester) async {
      await tester.pumpWidget(_buildSheet(_FakeDataSource()));
      await _openSheet(tester);

      await tester.tap(find.text('Save Note'));
      await tester.pump();

      expect(find.text('Note cannot be empty.'), findsOneWidget);
    });

    testWidgets('calls createNote when content is provided', (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildSheet(ds));
      await _openSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'My insight text');
      await tester.tap(find.text('Save Note'));
      await tester.pumpAndSettle();

      expect(ds.createdNote, isNotNull);
      expect(ds.createdNote!.content, 'My insight text');
    });

    testWidgets('auto-names untitled note as Note (1)', (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildSheet(ds));
      await _openSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'Auto-name me');
      await tester.tap(find.text('Save Note'));
      await tester.pumpAndSettle();

      expect(ds.createdNote?.title, 'Note (1)');
    });

    testWidgets('uses provided title when given', (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildSheet(ds));
      await _openSheet(tester);

      await tester.enterText(find.byType(TextField).first, 'My Title');
      await tester.enterText(find.byType(TextField).last, 'Some content');
      await tester.tap(find.text('Save Note'));
      await tester.pumpAndSettle();

      expect(ds.createdNote?.title, 'My Title');
      expect(ds.createdNote?.content, 'Some content');
    });
  });

  group('NoteEditSheet — edit mode', () {
    testWidgets('pre-populates fields from existing note', (tester) async {
      await tester.pumpWidget(_buildSheet(_FakeDataSource(), noteId: 'n1'));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.text('Old Title'), findsOneWidget);
      expect(find.text('Old content'), findsOneWidget);
    });

    testWidgets('calls updateNote on save', (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildSheet(ds, noteId: 'n1'));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Updated content');
      await tester.tap(find.text('Save Note'));
      await tester.pumpAndSettle();

      expect(ds.updatedNoteId, 'n1');
      expect(ds.updatedContent, 'Updated content');
    });
  });
}
