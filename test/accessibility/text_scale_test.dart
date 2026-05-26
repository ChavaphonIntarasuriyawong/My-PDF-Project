// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/auth/domain/auth_repository.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/auth/presentation/login_screen.dart';
import 'package:dartz/dartz.dart';
import 'package:my_pdf/core/errors/failures.dart';

// ---------------------------------------------------------------------------
// Stub repository — same pattern as test/screens/login_screen_test.dart
// ---------------------------------------------------------------------------

class _FakeRepo implements AuthRepository {
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
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Stream<UserModel?> authStateChanges() => const Stream.empty();

  @override
  UserModel? get currentUser => null;
}

/// Builds LoginScreen wrapped in ProviderScope with an optional [textScaler]
/// applied via MediaQuery.
Widget _buildScreen({TextScaler textScaler = TextScaler.noScaling}) {
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
    overrides: [authRepositoryProvider.overrideWithValue(_FakeRepo())],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: textScaler),
          child: child!,
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Text-scale accessibility (R5)', () {
    testWidgets('LoginScreen at 1.0x scale renders without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(textScaler: TextScaler.noScaling));
      await tester.pump();

      // No FlutterError about RenderFlex overflow.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'LoginScreen at 1.5x text scale renders without RenderFlex overflow',
      (tester) async {
        await tester.pumpWidget(
          _buildScreen(textScaler: TextScaler.linear(1.5)),
        );
        await tester.pump();

        // takeException returns the first unhandled exception; a RenderFlex
        // overflow is reported as a FlutterError. Null means clean render.
        final exception = tester.takeException();
        expect(
          exception,
          isNot(isA<FlutterError>()),
          reason:
              'Expected no FlutterError (e.g. RenderFlex overflow) at 1.5x scale',
        );
      },
    );

    testWidgets('MediaQuery textScaler is propagated to LoginScreen at 1.5x', (
      tester,
    ) async {
      // Reference font size from a known AppTypography token (bodyMedium = 14).
      const referenceFontSize = 14.0;

      await tester.pumpWidget(_buildScreen(textScaler: TextScaler.linear(1.5)));
      await tester.pump();

      // Find the LoginScreen widget's element and read MediaQuery from it.
      final loginElement = tester.element(find.byType(LoginScreen));
      final scalerInTree = MediaQuery.of(loginElement).textScaler;

      // Confirm the scaler reached the LoginScreen's context.
      expect(
        scalerInTree.scale(referenceFontSize),
        greaterThan(referenceFontSize),
        reason:
            'textScaler must scale a reference font size above its baseline '
            'at 1.5x',
      );

      // Confirm the numerical result: 14 × 1.5 = 21.
      expect(
        scalerInTree.scale(referenceFontSize),
        closeTo(21.0, 0.01),
        reason: '1.5x scaler applied to 14sp should give ~21sp',
      );
    });

    testWidgets(
      'LoginScreen at 2.0x text scale renders without RenderFlex overflow',
      (tester) async {
        await tester.pumpWidget(
          _buildScreen(textScaler: TextScaler.linear(2.0)),
        );
        await tester.pump();

        final exception = tester.takeException();
        expect(
          exception,
          isNot(isA<FlutterError>()),
          reason:
              'Expected no FlutterError (e.g. RenderFlex overflow) at 2.0x scale',
        );
      },
    );
  });
}
