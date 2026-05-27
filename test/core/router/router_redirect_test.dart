// Router redirect contract tests.
//
// Exercises `computeRedirect()` — the pure function that encodes all of
// GoRouter's redirect logic — without spinning up GoRouter, Firebase, or any
// platform channels.
//
// Coverage matrix (10 cases):
//   Auth gate   : loading, logged-out on auth/non-auth routes
//   PIN gate    : no-pin-set, pin-not-entered, pin-unlocked
//   Bounce      : unlocked user cleared away from auth/pin screens
//   No-op       : regular routes when all gates pass

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/core/constants/app_router.dart';
import 'package:my_pdf/core/constants/app_routes.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

const _user = UserModel(uid: 'u1', name: 'Test', email: 'test@example.com');

/// Shorthand: logged-in, PIN-unlocked redirect for [loc].
String? _redirect(
  String loc, {
  bool hasPinSet = true,
  bool pinUnlocked = true,
}) => computeRedirect(
  location: loc,
  authState: const AsyncValue.data(_user),
  hasPinSet: hasPinSet,
  pinUnlocked: pinUnlocked,
);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  // ── Auth gate ─────────────────────────────────────────────────────────────

  group('auth gate', () {
    test('loading auth state → null (wait, avoid login flash)', () {
      final result = computeRedirect(
        location: AppRoutes.home,
        authState: const AsyncValue.loading(),
        hasPinSet: true,
        pinUnlocked: true,
      );
      expect(result, isNull);
    });

    test('logged-out on /login → null (stay on auth screen)', () {
      final result = computeRedirect(
        location: AppRoutes.login,
        authState: const AsyncValue.data(null),
        hasPinSet: false,
        pinUnlocked: false,
      );
      expect(result, isNull);
    });

    test('logged-out on /register → null (stay on auth screen)', () {
      final result = computeRedirect(
        location: AppRoutes.register,
        authState: const AsyncValue.data(null),
        hasPinSet: false,
        pinUnlocked: false,
      );
      expect(result, isNull);
    });

    test('logged-out on /home → /login', () {
      final result = computeRedirect(
        location: AppRoutes.home,
        authState: const AsyncValue.data(null),
        hasPinSet: false,
        pinUnlocked: false,
      );
      expect(result, AppRoutes.login);
    });

    test('logged-out on reader route → /login', () {
      final result = computeRedirect(
        location: '/book/abc123/reading',
        authState: const AsyncValue.data(null),
        hasPinSet: false,
        pinUnlocked: false,
      );
      expect(result, AppRoutes.login);
    });
  });

  // ── App-level PIN gate ─────────────────────────────────────────────────────

  group('app-level PIN gate', () {
    test('no PIN set, on /home → /pin-setup', () {
      expect(
        _redirect(AppRoutes.home, hasPinSet: false, pinUnlocked: false),
        AppRoutes.pinSetup,
      );
    });

    test('no PIN set, already on /pin-setup → null (stay)', () {
      expect(
        _redirect(AppRoutes.pinSetup, hasPinSet: false, pinUnlocked: false),
        isNull,
      );
    });

    test('PIN set, not unlocked, on /home → /pin-entry', () {
      expect(
        _redirect(AppRoutes.home, hasPinSet: true, pinUnlocked: false),
        AppRoutes.pinEntry,
      );
    });

    test('PIN set, not unlocked, already on /pin-entry → null (stay)', () {
      expect(
        _redirect(AppRoutes.pinEntry, hasPinSet: true, pinUnlocked: false),
        isNull,
      );
    });

    test('PIN set, not unlocked, on reader route → /pin-entry', () {
      expect(
        _redirect('/book/abc/reading', hasPinSet: true, pinUnlocked: false),
        AppRoutes.pinEntry,
      );
    });
  });

  // ── Bounce unlocked user away from auth/pin screens ───────────────────────

  group('bounce unlocked user to /home', () {
    final gatedRoutes = [
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.pinSetup,
      AppRoutes.pinEntry,
    ];
    for (final route in gatedRoutes) {
      test('unlocked user on $route → /home', () {
        expect(_redirect(route), AppRoutes.home);
      });
    }
  });

  // ── Normal navigation — no redirect needed ────────────────────────────────

  group('no-op: unlocked user on regular routes', () {
    final passRoutes = [
      AppRoutes.home,
      AppRoutes.profile,
      AppRoutes.editProfile,
      '/shelf/s1',
      '/book/abc',
    ];
    for (final route in passRoutes) {
      test('$route → null (allow)', () {
        expect(_redirect(route), isNull);
      });
    }
  });
}
