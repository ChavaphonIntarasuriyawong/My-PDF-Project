import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/core/errors/failures.dart';
import 'package:my_pdf/features/auth/domain/auth_repository.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/auth/presentation/register_screen.dart';
import 'package:my_pdf/shared/widgets/gradient_button.dart';

class _FakeRepo implements AuthRepository {
  Either<Failure, UserModel>? registerResult;

  @override
  Future<Either<Failure, UserModel>> login({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserModel>> register({required String name, required String email, required String password}) async =>
      registerResult ?? const Left(AuthFailure('No result'));

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Stream<UserModel?> authStateChanges() => const Stream.empty();

  @override
  UserModel? get currentUser => null;
}

Widget _buildScreen(_FakeRepo repo) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const RegisterScreen()),
    GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('Home'))),
  ]);
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('RegisterScreen (5.2)', () {
    testWidgets('renders username, email, password fields and sign up button', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeRepo()));
      expect(find.text('USERNAME'), findsOneWidget);
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.widgetWithText(GradientButton, 'Sign Up'), findsOneWidget);
    });

    testWidgets('shows Join the Collection heading', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeRepo()));
      expect(find.text('Join the Collection'), findsOneWidget);
    });

    testWidgets('does not submit with empty fields', (tester) async {
      final repo = _FakeRepo();
      await tester.pumpWidget(_buildScreen(repo));
      await tester.tap(find.widgetWithText(GradientButton, 'Sign Up'));
      await tester.pump();
      expect(find.text('Join the Collection'), findsOneWidget);
    });

    testWidgets('shows error snackbar on failure', (tester) async {
      final repo = _FakeRepo()..registerResult = const Left(AuthFailure('Email taken'));
      await tester.pumpWidget(_buildScreen(repo));
      await tester.enterText(find.byType(TextField).at(0), 'Alice');
      await tester.enterText(find.byType(TextField).at(1), 'alice@test.com');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.ensureVisible(find.widgetWithText(GradientButton, 'Sign Up'));
      await tester.tap(find.widgetWithText(GradientButton, 'Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Email taken'), findsOneWidget);
    });

    testWidgets('password toggle works', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeRepo()));
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('Sign In link is visible', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeRepo()));
      expect(find.textContaining('Sign In', findRichText: true), findsOneWidget);
    });
  });
}
