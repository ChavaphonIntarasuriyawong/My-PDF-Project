// Screen-level golden — LoginScreen, logged-out state.
//
// Notes:
// - authStateProvider stubbed to a never-emitting stream so the screen sits
//   in the unauthenticated visual state.
// - If this golden ever drifts due to font fallback differences across CI
//   runners, fall back to the component-level goldens
//   (gradient_button_*, status_badge_*) which do not depend on full screen
//   composition.
//
// Regenerate: flutter test --update-goldens test/golden/login_screen_golden_test.dart
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/core/errors/failures.dart';
import 'package:my_pdf/core/theme/app_theme.dart';
import 'package:my_pdf/features/auth/domain/auth_repository.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/auth/presentation/login_screen.dart';

class _StubRepo implements AuthRepository {
  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
  }) async => const Left(AuthFailure('stub'));

  @override
  Future<Either<Failure, UserModel>> register({
    required String name,
    required String email,
    required String password,
  }) async => const Left(AuthFailure('stub'));

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Stream<UserModel?> authStateChanges() => const Stream.empty();

  @override
  UserModel? get currentUser => null;
}

void main() {
  testWidgets('LoginScreen — logged out golden', (tester) async {
    tester.view.physicalSize = const Size(412 * 2, 896 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/register',
          builder: (_, _) => const Scaffold(body: Text('Register')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(_StubRepo())],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_screen.png'),
    );
  });
}
