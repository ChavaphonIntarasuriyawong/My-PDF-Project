import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/features/library/presentation/shelf_content_screen.dart';

final _shelf = BookshelfModel(
  id: 's1',
  name: 'Science',
  ownerId: 'u1',
  createdAt: DateTime(2025),
);

Widget _buildScreen({List<BookModel> books = const []}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/shelf/:id',
        builder: (_, state) =>
            ShelfContentScreen(shelfId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/book/new',
        builder: (_, _) => const Scaffold(body: Text('New Book')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('Profile')),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (_, _) => const Scaffold(body: Text('Book Info')),
      ),
    ],
    initialLocation: '/shelf/s1',
  );

  return ProviderScope(
    overrides: [
      shelvesProvider.overrideWith((_) => Stream.value([_shelf])),
      booksByShelfProvider('s1').overrideWith((_) => Stream.value(books)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('ShelfContentScreen (5.6)', () {
    testWidgets('shows shelf name in header', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Science'), findsOneWidget);
    });

    testWidgets('shows empty state when no books', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('No books in this shelf.'), findsOneWidget);
    });

    testWidgets('shows more_vert menu icon', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('shows popup menu with Edit and Delete on menu tap', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });
  });
}
