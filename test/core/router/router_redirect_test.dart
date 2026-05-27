// Router redirect contract tests.
//
// Exercises `computeRedirect()` — the pure function that encodes all of
// GoRouter's redirect logic — without spinning up GoRouter, Firebase, or any
// platform channels.
//
// Coverage matrix (15 cases):
//   Auth gate   : loading, logged-out on auth/non-auth routes
//   PIN gate    : no-pin-set, pin-not-entered, pin-unlocked
//   Bounce      : unlocked user cleared away from auth/pin screens
//   Book lock   : reading + note routes, locked/unlocked states
//   No-op       : regular routes when all gates pass

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/core/constants/app_router.dart';
import 'package:my_pdf/core/constants/app_routes.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

const _user = UserModel(uid: 'u1', name: 'Test', email: 'test@example.com');

/// Shorthand: logged-in, PIN-unlocked redirect for [loc].
/// Book/unlock stubs default to no-op (no locked books).
String? _redirect(
  String loc, {
  bool hasPinSet = true,
  bool pinUnlocked = true,
  BookModel? Function(String)? getBook,
  bool Function(String)? isBookUnlocked,
}) => computeRedirect(
  location: loc,
  authState: const AsyncValue.data(_user),
  hasPinSet: hasPinSet,
  pinUnlocked: pinUnlocked,
  getBook: getBook ?? (_) => null,
  isBookUnlocked: isBookUnlocked ?? (_) => false,
);

BookModel _lockedBook(String id) => BookModel(
  id: id,
  title: 'T',
  link: 'https://example.com/t.pdf',
  totalPages: 10,
  currentPage: 0,
  progress: 0,
  status: 'reading',
  shelfId: 's1',
  ownerId: 'u1',
  isLocked: true,
  lockHash: 'fakehash',
);

BookModel _unlockedBook(String id) => BookModel(
  id: id,
  title: 'T',
  link: 'https://example.com/t.pdf',
  totalPages: 10,
  currentPage: 0,
  progress: 0,
  status: 'reading',
  shelfId: 's1',
  ownerId: 'u1',
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
        getBook: (_) => null,
        isBookUnlocked: (_) => false,
      );
      expect(result, isNull);
    });

    test('logged-out on /login → null (stay on auth screen)', () {
      final result = computeRedirect(
        location: AppRoutes.login,
        authState: const AsyncValue.data(null),
        hasPinSet: false,
        pinUnlocked: false,
        getBook: (_) => null,
        isBookUnlocked: (_) => false,
      );
      expect(result, isNull);
    });

    test('logged-out on /register → null (stay on auth screen)', () {
      final result = computeRedirect(
        location: AppRoutes.register,
        authState: const AsyncValue.data(null),
        hasPinSet: false,
        pinUnlocked: false,
        getBook: (_) => null,
        isBookUnlocked: (_) => false,
      );
      expect(result, isNull);
    });

    test('logged-out on /home → /login', () {
      final result = computeRedirect(
        location: AppRoutes.home,
        authState: const AsyncValue.data(null),
        hasPinSet: false,
        pinUnlocked: false,
        getBook: (_) => null,
        isBookUnlocked: (_) => false,
      );
      expect(result, AppRoutes.login);
    });

    test('logged-out on reader route → /login', () {
      final result = computeRedirect(
        location: '/book/abc123/reading',
        authState: const AsyncValue.data(null),
        hasPinSet: false,
        pinUnlocked: false,
        getBook: (_) => null,
        isBookUnlocked: (_) => false,
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

  // ── Per-book lock gate ─────────────────────────────────────────────────────

  group('per-book lock gate', () {
    test(
      'reading route, locked book, not session-unlocked → /book/:id/lock',
      () {
        const bookId = 'book42';
        final result = _redirect(
          '/book/$bookId/reading',
          getBook: (id) => _lockedBook(id),
          isBookUnlocked: (_) => false,
        );
        expect(result, startsWith('/book/$bookId/lock'));
        final uri = Uri.parse(result!);
        expect(
          Uri.decodeComponent(uri.queryParameters['redirect']!),
          '/book/$bookId/reading',
          reason: 'redirect param must encode the original destination',
        );
      },
    );

    test('note route, locked book, not session-unlocked → /book/:id/lock', () {
      const bookId = 'book99';
      final result = _redirect(
        '/book/$bookId/note',
        getBook: (id) => _lockedBook(id),
        isBookUnlocked: (_) => false,
      );
      expect(result, startsWith('/book/$bookId/lock'));
    });

    test('reading route, locked book, IS session-unlocked → null (allow)', () {
      const bookId = 'book42';
      expect(
        _redirect(
          '/book/$bookId/reading',
          getBook: (id) => _lockedBook(id),
          isBookUnlocked: (_) => true,
        ),
        isNull,
      );
    });

    test('reading route, book NOT locked → null (allow)', () {
      const bookId = 'book42';
      expect(
        _redirect(
          '/book/$bookId/reading',
          getBook: (id) => _unlockedBook(id),
          isBookUnlocked: (_) => false,
        ),
        isNull,
      );
    });

    test('reading route, book stream not yet emitted (null) → null '
        '(let screen handle its own AsyncValue loading)', () {
      expect(
        _redirect(
          '/book/unknownId/reading',
          getBook: (_) => null,
          isBookUnlocked: (_) => false,
        ),
        isNull,
      );
    });
  });
}
