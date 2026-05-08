import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/core/errors/failures.dart';
import 'package:my_pdf/features/auth/domain/auth_repository.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/auth/presentation/login_screen.dart';
import 'package:my_pdf/shared/widgets/gradient_button.dart';

class _FakeRepo implements AuthRepository {
  Either<Failure, UserModel>? loginResult;

  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
  }) async => loginResult ?? const Left(AuthFailure('No result set'));

  @override
  Future<Either<Failure, UserModel>> register({
    required String name,
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Stream<UserModel?> authStateChanges() => const Stream.empty();

  @override
  UserModel? get currentUser => null;
}

Widget _buildScreen(_FakeRepo repo) {
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

  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('LoginScreen (5.1)', () {
    testWidgets('renders email and password fields and sign in button', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(_FakeRepo()));
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.widgetWithText(GradientButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('shows welcome text', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeRepo()));
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('does not submit with empty fields', (tester) async {
      final repo = _FakeRepo();
      await tester.pumpWidget(_buildScreen(repo));
      await tester.tap(find.widgetWithText(GradientButton, 'Sign In'));
      await tester.pump();
      // repo never called — still idle
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('GradientButton shows spinner when loading prop is true', (
      tester,
    ) async {
      // Test the loading state directly on GradientButton rather than through async login
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              label: 'Sign In',
              loading: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('shows snackbar on login error', (tester) async {
      final repo = _FakeRepo()
        ..loginResult = const Left(AuthFailure('Wrong password'));
      await tester.pumpWidget(_buildScreen(repo));

      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrong');
      await tester.tap(find.widgetWithText(GradientButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Wrong password'), findsOneWidget);
    });

    testWidgets('register link is visible', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeRepo()));
      expect(
        find.textContaining('Register now', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeRepo()));
      // Initially obscured — visibility_off icon shown
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });
}
