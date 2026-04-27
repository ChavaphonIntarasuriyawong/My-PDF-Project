import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/library/data/firestore_data_source.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/presentation/library_controller.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';

class _FakeDataSource implements FirestoreDataSource {
  bool shouldThrow = false;
  BookModel? createdBook;

  void _maybeThrow() {
    if (shouldThrow) throw Exception('Firestore error');
  }

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
  Future<void> updateReadingProgress({required String bookId, required int currentPage, required int totalPages}) async =>
      _maybeThrow();

  @override
  Future<void> updateBookStatus(String bookId, String status) async => _maybeThrow();

  @override
  Future<void> updateBookTitle(String bookId, String title) async => _maybeThrow();

  @override
  Stream<List<BookModel>> watchBooks(String ownerId) => const Stream.empty();

  @override
  Stream<BookModel?> watchBook(String bookId) => const Stream.empty();

  @override
  Future<BookModel?> getBook(String bookId) async => throw UnimplementedError();

  @override
  Future<void> updateBook(BookModel book) async => _maybeThrow();
}

ProviderContainer _makeContainer(_FakeDataSource ds) {
  return ProviderContainer(
    overrides: [
      firestoreDataSourceProvider.overrideWithValue(ds),
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

    group('createBook', () {
      test('success returns created book', () async {
        final book = await container.read(libraryControllerProvider.notifier).createBook(_testBook);
        expect(book, isNotNull);
        expect(book!.title, 'My Book');
      });

      test('failure returns null', () async {
        ds.shouldThrow = true;
        final book = await container.read(libraryControllerProvider.notifier).createBook(_testBook);
        expect(book, isNull);
      });
    });

    group('deleteBook', () {
      test('success returns true', () async {
        final ok = await container.read(libraryControllerProvider.notifier).deleteBook('b1');
        expect(ok, isTrue);
      });

      test('failure returns false', () async {
        ds.shouldThrow = true;
        final ok = await container.read(libraryControllerProvider.notifier).deleteBook('b1');
        expect(ok, isFalse);
      });
    });

    group('updateProgress', () {
      test('success returns true', () async {
        final ok = await container.read(libraryControllerProvider.notifier).updateProgress(
          bookId: 'b1',
          currentPage: 42,
          totalPages: 100,
        );
        expect(ok, isTrue);
      });

      test('failure returns false', () async {
        ds.shouldThrow = true;
        final ok = await container.read(libraryControllerProvider.notifier).updateProgress(
          bookId: 'b1',
          currentPage: 42,
          totalPages: 100,
        );
        expect(ok, isFalse);
      });
    });

    group('updateStatus', () {
      test('success returns true', () async {
        final ok = await container.read(libraryControllerProvider.notifier).updateStatus('b1', 'finished');
        expect(ok, isTrue);
      });

      test('failure returns false', () async {
        ds.shouldThrow = true;
        final ok = await container.read(libraryControllerProvider.notifier).updateStatus('b1', 'finished');
        expect(ok, isFalse);
      });
    });

    group('renameBook', () {
      test('success returns true', () async {
        final ok = await container.read(libraryControllerProvider.notifier).renameBook('b1', 'New Name');
        expect(ok, isTrue);
      });

      test('failure returns false', () async {
        ds.shouldThrow = true;
        final ok = await container.read(libraryControllerProvider.notifier).renameBook('b1', 'New Name');
        expect(ok, isFalse);
      });
    });
  });
}
