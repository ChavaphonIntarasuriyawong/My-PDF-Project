import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';
import 'package:my_pdf/features/library/presentation/home_screen.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';

const _user = UserModel(uid: 'u1', name: 'Alice', email: 'a@b.com');

final _shelf = BookshelfModel(
  id: 's1',
  name: 'Science',
  ownerId: 'u1',
  createdAt: DateTime(2025),
);

const _book = BookModel(
  id: 'b1',
  title: 'Cosmos',
  link: 'https://pdf.url',
  totalPages: 100,
  currentPage: 50,
  progress: 50,
  status: 'reading',
  shelfId: 's1',
  ownerId: 'u1',
);

Widget _buildScreen({
  List<BookshelfModel> shelves = const [],
  List<BookModel> books = const [],
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/book/new',
        builder: (_, _) => const Scaffold(body: Text('New Book')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('Profile')),
      ),
      GoRoute(
        path: '/shelf/:id',
        builder: (_, _) => const Scaffold(body: Text('Shelf')),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (_, _) => const Scaffold(body: Text('Book')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((_) => Stream.value(_user)),
      userProfileProvider.overrideWith((_) => Stream.value(_user)),
      shelvesProvider.overrideWith((_) => Stream.value(shelves)),
      allBooksProvider.overrideWith((_) => Stream.value(books)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('HomeScreen (5.3)', () {
    testWidgets('shows MYPDF title and greeting', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('MYPDF'), findsOneWidget);
      expect(find.text('Your Digital Library'), findsOneWidget);
    });

    testWidgets('shows user name in greeting', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.textContaining('ALICE'), findsOneWidget);
    });

    testWidgets('shows shelf name when shelves provided', (tester) async {
      await tester.pumpWidget(_buildScreen(shelves: [_shelf]));
      await tester.pump();
      expect(find.text('Science'), findsOneWidget);
    });

    testWidgets('shows empty state when no books', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('No recently read books yet.'), findsOneWidget);
    });

    testWidgets('shows Recently Read header', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Recently Read'), findsOneWidget);
    });

    testWidgets('shows All shelf row', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('shows NEW SHELF button', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('NEW SHELF'), findsOneWidget);
    });

    testWidgets('book count shown next to All', (tester) async {
      await tester.pumpWidget(_buildScreen(books: [_book]));
      await tester.pump();
      expect(find.text('1'), findsWidgets);
    });
  });
}
