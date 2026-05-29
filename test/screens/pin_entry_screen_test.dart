import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:my_pdf/core/errors/failures.dart';
import 'package:my_pdf/core/local/app_pin_service.dart';
import 'package:my_pdf/features/auth/domain/auth_repository.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/auth/presentation/pin_entry_screen.dart';
import 'package:dartz/dartz.dart';

// ---------------------------------------------------------------------------
// Stub AppPinService — no-op clearPin so logout completes without Hive.
// ---------------------------------------------------------------------------

class _FakeAppPinService extends AppPinService {
  @override
  bool hasPinSet() => false;
  @override
  Future<void> setPin(String pin) async {}
  @override
  bool verifyPin(String pin) => false;
  @override
  Future<void> clearPin() async {}
}

// ---------------------------------------------------------------------------
// Stub AuthRepository — logout always succeeds, login/register unused.
// ---------------------------------------------------------------------------

class _StubAuthRepo implements AuthRepository {
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

// ---------------------------------------------------------------------------
// Minimal GoRouter with the two routes PinEntryScreen navigates to.
// ---------------------------------------------------------------------------

Widget _buildApp({List<Override> overrides = const []}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const PinEntryScreen()),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Login')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_StubAuthRepo()),
      appPinServiceProvider.overrideWithValue(_FakeAppPinService()),
      ...overrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Hive helpers
// ---------------------------------------------------------------------------

late Directory _hiveTmp;

Future<void> _openHive() async {
  _hiveTmp = await Directory.systemTemp.createTemp('pin_entry_test_');
  Hive.init(_hiveTmp.path);
  await Hive.openBox<dynamic>('app_prefs');
}

Future<void> _closeHive() async {
  await Hive.close();
  await _hiveTmp.delete(recursive: true);
}

// ---------------------------------------------------------------------------
// Test helper — tap 6 digit buttons.
// ---------------------------------------------------------------------------

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final ch in pin.characters) {
    await tester.tap(find.text(ch).last);
    await tester.pump();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PinEntryScreen — rendering', () {
    testWidgets('renders Welcome Back headline', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('shows Forgot PIN escape link', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.text('Forgot PIN? Sign out'), findsOneWidget);
    });
  });

  group('PinEntryScreen — wrong PIN', () {
    setUp(_openHive);
    tearDown(_closeHive);

    testWidgets('entering wrong PIN shows Incorrect PIN error', (tester) async {
      // No PIN is stored in Hive, so verifyPin always returns false.
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await _enterPin(tester, '999999');
      await tester.pump();

      expect(find.text('Incorrect PIN.'), findsOneWidget);
    });

    testWidgets('5 failed attempts trigger cooldown message', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        await _enterPin(tester, '000000');
        await tester.pump();
      }

      expect(find.textContaining('Too many attempts'), findsOneWidget);
    });

    testWidgets('numpad is disabled during cooldown', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Trigger cooldown.
      for (var i = 0; i < 5; i++) {
        await _enterPin(tester, '111111');
        await tester.pump();
      }

      // The PinNumpad buttons are disabled — tapping them does nothing.
      // Record the error text, try to tap a digit, check error text unchanged.
      final errorBefore = find.textContaining('Too many attempts');
      expect(errorBefore, findsOneWidget);

      await tester.tap(find.text('1').last);
      await tester.pump();

      // Still shows cooldown, not "Incorrect PIN."
      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(find.text('Incorrect PIN.'), findsNothing);
    });
  });

  group('PinEntryScreen — forgot PIN sign-out', () {
    testWidgets('tapping Forgot PIN navigates to login', (tester) async {
      // Use a taller window so "Forgot PIN? Sign out" (below the numpad) is
      // within the viewport and receives hit tests.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Forgot PIN? Sign out'));
      await tester.tap(find.text('Forgot PIN? Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });
  });
}
