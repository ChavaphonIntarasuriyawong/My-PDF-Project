import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/core/local/app_pin_service.dart';
import 'package:my_pdf/core/local/app_pin_session.dart';
import 'package:my_pdf/features/auth/presentation/pin_setup_screen.dart';

// ---------------------------------------------------------------------------
// Minimal GoRouter — only routes PinSetupScreen needs.
// ---------------------------------------------------------------------------

Widget _buildApp({List<Override> overrides = const []}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const PinSetupScreen()),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Tap the digit buttons to enter a 6-digit PIN on the numpad.
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
  group('PinSetupScreen — rendering', () {
    testWidgets('renders Create Your PIN headline', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.text('Create Your PIN'), findsOneWidget);
    });

    testWidgets('shows step-1 label on launch', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.text('Enter a 6-digit PIN'), findsOneWidget);
    });
  });

  group('PinSetupScreen — 6-digit entry', () {
    testWidgets('typing 6 digits advances to confirm step', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await _enterPin(tester, '123456');
      await tester.pump();

      expect(find.text('Confirm your PIN'), findsOneWidget);
    });

    testWidgets('fewer than 6 digits stays on step 1', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await _enterPin(tester, '12345'); // only 5 digits
      await tester.pump();

      expect(find.text('Enter a 6-digit PIN'), findsOneWidget);
      expect(find.text('Confirm your PIN'), findsNothing);
    });
  });

  group('PinSetupScreen — confirm mismatch', () {
    testWidgets('mismatched confirm shows error and resets to step 1', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Step 1 — enter 123456.
      await _enterPin(tester, '123456');
      await tester.pump();

      // Step 2 — enter a different PIN.
      await _enterPin(tester, '654321');
      await tester.pumpAndSettle();

      expect(find.text("PINs don't match. Try again."), findsOneWidget);
      // Screen resets to step 1.
      expect(find.text('Enter a 6-digit PIN'), findsOneWidget);
    });
  });

  group('PinSetupScreen — successful setup', () {
    testWidgets('matching PINs unlock session and navigate to home', (
      tester,
    ) async {
      bool sessionUnlocked = false;

      await tester.pumpWidget(
        _buildApp(
          overrides: [
            // No-op AppPinService — skips Hive I/O so the test stays fully
            // inside fake-async and pumpAndSettle() can settle normally.
            appPinServiceProvider.overrideWithValue(_NoIoAppPinService()),
            appPinSessionProvider.overrideWith(
              (ref) =>
                  _TrackingPinSession(onUnlock: () => sessionUnlocked = true),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Step 1.
      await _enterPin(tester, '112233');
      await tester.pump();

      // Step 2 — same PIN.  _savePin() completes synchronously (no Hive I/O).
      await _enterPin(tester, '112233');
      await tester.pumpAndSettle();

      expect(sessionUnlocked, isTrue);
      expect(find.text('Home'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Stub AppPinService — setPin completes immediately without touching Hive.
// ---------------------------------------------------------------------------

class _NoIoAppPinService extends AppPinService {
  @override
  Future<void> setPin(String pin) async {}
}

// ---------------------------------------------------------------------------
// Stub AppPinSession (StateNotifier) that reports unlock calls.
// ---------------------------------------------------------------------------

class _TrackingPinSession extends AppPinSession {
  final VoidCallback onUnlock;
  _TrackingPinSession({required this.onUnlock});

  @override
  void unlock() {
    onUnlock();
    super.unlock();
  }
}
