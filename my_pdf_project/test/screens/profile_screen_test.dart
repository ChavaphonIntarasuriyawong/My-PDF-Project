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
  status: status, ownerId: 'u1',
);

Widget _buildScreen({List<BookModel> books = const []}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
    GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('Home'))),
    GoRoute(path: '/book/new', builder: (_, _) => const Scaffold(body: Text('New Book'))),
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

    testWidgets('shows READ stat label', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('READ'), findsOneWidget);
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

    testWidgets('shows Logout row', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('shows ACCOUNT SETTINGS section label', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('ACCOUNT SETTINGS'), findsOneWidget);
    });
  });
}
