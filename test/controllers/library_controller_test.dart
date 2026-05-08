import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/library/data/firestore_data_source.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';
import 'package:my_pdf/features/library/domain/note_model.dart';
import 'package:my_pdf/features/library/presentation/library_controller.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';

import '../_helpers/fake_recent_books.dart';

class _FakeDataSource implements FirestoreDataSource {
  bool shouldThrow = false;
  BookshelfModel? createdShelf;
  BookModel? createdBook;
  NoteModel? savedNote;

  void _maybeThrow() {
    if (shouldThrow) throw Exception('Firestore error');
  }

  @override
  Future<BookshelfModel> createShelf({
    required String name,
    required String ownerId,
  }) async {
    _maybeThrow();
    createdShelf = BookshelfModel(
      id: 'new-shelf',
      name: name,
      ownerId: ownerId,
      createdAt: DateTime.now(),
    );
    return createdShelf!;
  }

  @override
  Future<void> updateShelfName(String shelfId, String name) async =>
      _maybeThrow();

  @override
  Future<void> deleteShelf(String shelfId) async => _maybeThrow();

  @override
  Future<BookModel> createBook(BookModel book) async {
    _maybeThrow();
    createdBook = book.copyWith();
    return createdBook!;
  }

  @override
  Future<String?> deleteBook(String bookId) async {
    _maybeThrow();
    return null;
  }

  @override
  Future<void> updateReadingProgress({
    required String bookId,
    required int currentPage,
    required int totalPages,
  }) async => _maybeThrow();

  @override
  Future<void> updateBookStatus(String bookId, String status) async =>
      _maybeThrow();

  @override
  Future<void> updateBookTitle(String bookId, String title) async =>
      _maybeThrow();

  @override
  Future<void> updateBookLock(
    String bookId, {
    required bool isLocked,
    required String? lockHash,
  }) async => _maybeThrow();

  @override
  Future<NoteModel> createNote({
    required String bookId,
    required String title,
    required String content,
  }) async {
    _maybeThrow();
    savedNote = NoteModel(
      id: 'n1',
      bookId: bookId,
      title: title,
      content: content,
      updatedAt: DateTime.now(),
    );
    return savedNote!;
  }

  @override
  Future<void> updateNote(
    String noteId, {
    required String title,
    required String content,
  }) async => _maybeThrow();

  @override
  Future<void> deleteNote(String noteId) async => _maybeThrow();

  List<List<String>> deleteNotesCalls = [];

  @override
  Future<void> deleteNotes(List<String> noteIds) async {
    deleteNotesCalls.add(List.of(noteIds));
    _maybeThrow();
  }

  @override
  Future<NoteModel?> getNoteById(String noteId) async => null;

  @override
  Stream<List<NoteModel>> watchNotesByBookId(String bookId) =>
      const Stream.empty();

  @override
  Stream<List<BookshelfModel>> watchShelves(String ownerId) =>
      const Stream.empty();

  @override
  Stream<List<BookModel>> watchBooks(String ownerId) => const Stream.empty();

  @override
  Stream<List<BookModel>> watchBooksByShelf({
    required String shelfId,
    required String ownerId,
  }) => const Stream.empty();

  @override
  Stream<BookModel?> watchBook(String bookId) => const Stream.empty();

  @override
  Future<void> moveBook(String bookId, String newShelfId) async =>
      _maybeThrow();

  @override
  Future<void> updateUserProfile(String uid, {String? name}) async =>
      _maybeThrow();

  @override
  Stream<int> watchUserNotesCount(List<String> bookIds) => Stream.value(0);
}

ProviderContainer _makeContainer(_FakeDataSource ds) {
  return ProviderContainer(
    overrides: [
      firestoreDataSourceProvider.overrideWithValue(ds),
      recentBooksServiceProvider.overrideWithValue(FakeRecentBooksService()),
    ],
  );
}

const _testBook = BookModel(
  id: 'b1',
  title: 'My Book',
  link: 'https://pdf.url',
  totalPages: 100,
  currentPage: 0,
  progress: 0,
  status: 'reading',
  shelfId: 's1',
  ownerId: 'u1',
);

void main() {
  group('LibraryController', () {
    late _FakeDataSource ds;
    late ProviderContainer container;

    setUp(() {
      ds = _FakeDataSource();
      container = _makeContainer(ds);
    });

    tearDown(() => container.dispose());

    test('initial state is data(null)', () {
      final state = container.read(libraryControllerProvider);
      expect(state, isA<AsyncData>());
    });

    group('createShelf', () {
      test('success returns true', () async {
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .createShelf('History', 'u1');
        expect(ok, isTrue);
        expect(ds.createdShelf?.name, 'History');
        expect(container.read(libraryControllerProvider), isA<AsyncData>());
      });

      test('failure returns false and sets error state', () async {
        ds.shouldThrow = true;
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .createShelf('History', 'u1');
        expect(ok, isFalse);
        expect(container.read(libraryControllerProvider), isA<AsyncError>());
      });
    });

    group('createBook', () {
      test('success returns created book', () async {
        final book = await container
            .read(libraryControllerProvider.notifier)
            .createBook(_testBook);
        expect(book, isNotNull);
        expect(book!.title, 'My Book');
      });

      test('failure returns null', () async {
        ds.shouldThrow = true;
        final book = await container
            .read(libraryControllerProvider.notifier)
            .createBook(_testBook);
        expect(book, isNull);
      });
    });

    group('deleteBook', () {
      test('success returns true', () async {
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .deleteBook('b1');
        expect(ok, isTrue);
      });

      test('failure returns false', () async {
        ds.shouldThrow = true;
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .deleteBook('b1');
        expect(ok, isFalse);
      });
    });

    group('updateProgress', () {
      test('success returns true', () async {
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .updateProgress(bookId: 'b1', currentPage: 42, totalPages: 100);
        expect(ok, isTrue);
      });

      test('failure returns false', () async {
        ds.shouldThrow = true;
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .updateProgress(bookId: 'b1', currentPage: 42, totalPages: 100);
        expect(ok, isFalse);
      });
    });

    group('updateStatus', () {
      test('success returns true', () async {
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .updateStatus('b1', 'finished');
        expect(ok, isTrue);
      });

      test('failure returns false', () async {
        ds.shouldThrow = true;
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .updateStatus('b1', 'finished');
        expect(ok, isFalse);
      });
    });

    group('createNote', () {
      test('success returns note', () async {
        final note = await container
            .read(libraryControllerProvider.notifier)
            .createNote(bookId: 'b1', title: 'Insight', content: 'Great book');
        expect(note, isNotNull);
        expect(note!.content, 'Great book');
        expect(note.title, 'Insight');
        expect(note.bookId, 'b1');
      });

      test('failure returns null', () async {
        ds.shouldThrow = true;
        final note = await container
            .read(libraryControllerProvider.notifier)
            .createNote(bookId: 'b1', title: 'T', content: 'Content');
        expect(note, isNull);
      });
    });

    group('updateNote', () {
      test('success returns true', () async {
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .updateNote('n1', title: 'New', content: 'updated');
        expect(ok, isTrue);
      });

      test('failure returns false', () async {
        ds.shouldThrow = true;
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .updateNote('n1', title: 'New', content: 'updated');
        expect(ok, isFalse);
      });
    });

    group('deleteNote', () {
      test('success returns true', () async {
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .deleteNote('n1');
        expect(ok, isTrue);
      });

      test('failure returns false', () async {
        ds.shouldThrow = true;
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .deleteNote('n1');
        expect(ok, isFalse);
      });
    });

    group('deleteNotes', () {
      test('forwards ids to datasource and returns true on success', () async {
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .deleteNotes(['n1', 'n2']);
        expect(ok, isTrue);
        expect(ds.deleteNotesCalls, [
          ['n1', 'n2'],
        ]);
      });

      test('failure returns false', () async {
        ds.shouldThrow = true;
        final ok = await container
            .read(libraryControllerProvider.notifier)
            .deleteNotes(['n1', 'n2']);
        expect(ok, isFalse);
      });

      test(
        'empty list short-circuits to true without calling datasource',
        () async {
          final ok = await container
              .read(libraryControllerProvider.notifier)
              .deleteNotes(const []);
          expect(ok, isTrue);
          expect(ds.deleteNotesCalls, isEmpty);
        },
      );
    });
  });
}
