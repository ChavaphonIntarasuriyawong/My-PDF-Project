// Screen-level golden — HomeScreen, empty state.
//
// Empty book list keeps the screen deterministic (no thumbnails to render).
//
// Regenerate: flutter test --update-goldens test/golden/home_screen_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/core/theme/app_theme.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/library/presentation/home_screen.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';

const _user = UserModel(uid: 'u1', name: 'Alice', email: 'a@b.com');

void main() {
  testWidgets('HomeScreen — empty state golden', tags: 'golden', (
    tester,
  ) async {
    // 430×932 (iPhone 14 Pro Max logical) — wider than 412 to avoid a
    // pre-existing 2.2 px overflow in AppBottomNavBar when rendered at the
    // narrower 412 phone-frame width. Bug repros at 412 — see notes in
    // docs/qa/integration_test_matrix.md, Wave 4 follow-up.
    tester.view.physicalSize = const Size(430 * 2, 932 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((_) => Stream.value(_user)),
          userProfileProvider.overrideWith((_) => Stream.value(_user)),
          shelvesProvider.overrideWith((_) => const Stream.empty()),
          allBooksProvider.overrideWith((_) => Stream.value(const [])),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_empty.png'),
    );
  });
}
