// Screen-level golden — ProfileScreen.
//
// Regenerate: flutter test --update-goldens test/golden/profile_screen_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/core/theme/app_theme.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/features/profile/presentation/profile_screen.dart';

const _user = UserModel(uid: 'u1', name: 'Alice', email: 'alice@test.com');

void main() {
  testWidgets('ProfileScreen — populated golden', (tester) async {
    // 430×932 — see home_screen_golden_test.dart for rationale (avoids a
    // 2.2 px AppBottomNavBar overflow at 412 width).
    tester.view.physicalSize = const Size(430 * 2, 932 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/book/new',
          builder: (_, _) => const Scaffold(body: Text('New Book')),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (_, _) => const Scaffold(body: Text('Edit Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((_) => Stream.value(_user)),
          allBooksProvider.overrideWith((_) => Stream.value(const [])),
          shelvesProvider.overrideWith((_) => Stream.value(const [])),
          authStateProvider.overrideWith((_) => Stream.value(_user)),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(ProfileScreen),
      matchesGoldenFile('goldens/profile.png'),
    );
  });
}
