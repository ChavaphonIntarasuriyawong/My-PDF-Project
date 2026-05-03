import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/features/profile/presentation/profile_screen.dart';

const _user = UserModel(uid: 'u1', name: 'Alice', email: 'alice@test.com');

BookModel _book(String status) => BookModel(
  id: status, title: 'Book', link: '',
  totalPages: 10, currentPage: 5, progress: 50,
  status: status, shelfId: 's1', ownerId: 'u1',
);

final _shelf = BookshelfModel(id: 'sh1', name: 'Shelf One', ownerId: 'u1', createdAt: DateTime(2024));

Widget _buildScreen({List<BookModel> books = const [], List<BookshelfModel> shelves = const []}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
    GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('Home'))),
    GoRoute(path: '/book/new', builder: (_, _) => const Scaffold(body: Text('New Book'))),
    GoRoute(path: '/profile/edit', builder: (_, _) => const Scaffold(body: Text('Edit Profile'))),
  ]);
  return ProviderScope(
    overrides: [
      userProfileProvider.overrideWith((_) => Stream.value(_user)),
      allBooksProvider.overrideWith((_) => Stream.value(books)),
      shelvesProvider.overrideWith((_) => Stream.value(shelves)),
      authStateProvider.overrideWith((_) => Stream.value(_user)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('ProfileScreen (5.4)', () {
    testWidgets('shows user name and email', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('alice@test.com'), findsOneWidget);
    });

    testWidgets('shows READ and SHELVES stat labels', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('READ'), findsOneWidget);
      expect(find.text('SHELVES'), findsOneWidget);
    });

    testWidgets('shows correct READ count', (tester) async {
      await tester.pumpWidget(_buildScreen(books: [
        _book('reading'),
        _book('finished'),
        _book('on_hold'),
      ]));
      await tester.pump();
      // READ = total books = 3
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('shows correct SHELVES count', (tester) async {
      await tester.pumpWidget(_buildScreen(shelves: [_shelf]));
      await tester.pump();
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('shows Personal Information and Logout rows', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('shows ACCOUNT SETTINGS section label', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('ACCOUNT SETTINGS'), findsOneWidget);
    });
  });
}
