import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/features/profile/presentation/profile_screen.dart';

const _user = UserModel(uid: 'u1', name: 'Alice', email: 'alice@test.com');

BookModel _book(String status) => BookModel(
  id: status, title: 'Book', link: '',
  totalPages: 10, currentPage: 5, progress: 50,
  status: status, shelfId: 's1', ownerId: 'u1',
);

Widget _buildScreen({List<BookModel> books = const []}) {
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

    testWidgets('shows Reading Stats section', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Reading Stats'), findsOneWidget);
    });

    testWidgets('shows correct stat counts', (tester) async {
      await tester.pumpWidget(_buildScreen(books: [
        _book('reading'), _book('reading'),
        _book('finished'),
        _book('on_hold'),
      ]));
      await tester.pump();
      // Total=4, Reading=2, Finished=1, On Hold=1
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('shows Edit Profile and Sign Out rows', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('avatar shows first letter of name', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('A'), findsOneWidget);
    });
  });
}
