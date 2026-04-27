import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/library/data/firestore_data_source.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/features/reader/presentation/reading_screen.dart';

const _book = BookModel(
  id: 'b1', title: 'Cosmos', link: 'https://pdf.url/cosmos.pdf',
  totalPages: 200, currentPage: 50, progress: 25,
  status: 'reading', ownerId: 'u1',
);

class _FakeDataSource implements FirestoreDataSource {
  int? savedPage;
  int? savedTotal;

  @override
  Future<void> updateReadingProgress({required String bookId, required int currentPage, required int totalPages}) async {
    savedPage = currentPage;
    savedTotal = totalPages;
  }

  @override Future<BookModel> createBook(BookModel b) => throw UnimplementedError();
  @override Future<String?> deleteBook(String b) => throw UnimplementedError();
  @override Future<void> updateBook(BookModel b) => throw UnimplementedError();
  @override Future<void> updateBookStatus(String b, String s) => throw UnimplementedError();
  @override Future<void> updateBookTitle(String b, String t) => throw UnimplementedError();
  @override Future<BookModel?> getBook(String b) => throw UnimplementedError();
  @override Stream<List<BookModel>> watchBooks(String o) => const Stream.empty();
  @override Stream<BookModel?> watchBook(String b) => Stream.value(_book);
}

Widget _buildScreen() {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/book/:id/reading',
      builder: (_, state) => ReadingScreen(bookId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/book/:id', builder: (_, _) => const Scaffold(body: Text('Book Info'))),
  ], initialLocation: '/book/b1/reading');

  return ProviderScope(
    overrides: [
      bookByIdProvider('b1').overrideWith((_) => Stream.value(_book)),
      firestoreDataSourceProvider.overrideWithValue(_FakeDataSource()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('ReadingScreen (5.10)', () {
    testWidgets('shows book title in top bar', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Cosmos'), findsOneWidget);
    });

    testWidgets('shows back arrow', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows loading indicator while PDF fetches', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // PDF download is async — spinner visible before it completes
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows LinearProgressIndicator for reading progress', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
