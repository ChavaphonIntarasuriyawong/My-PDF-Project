import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/local/app_pin_service.dart';
import '../../core/local/app_pin_session.dart';
import '../../features/auth/domain/user_model.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/pin_entry_screen.dart';
import '../../features/auth/presentation/pin_setup_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/library/presentation/book_info_screen.dart';
import '../../features/library/presentation/home_screen.dart';
import '../../features/library/presentation/new_book_screen.dart';
import '../../features/library/presentation/shelf_content_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reader/presentation/note_screen.dart';
import '../../features/reader/presentation/reading_screen.dart';
import 'app_routes.dart';

part 'app_router.g.dart';

/// Pure redirect logic — extracted so the router body stays thin and this
/// function can be unit-tested without spinning up GoRouter or Firebase.
@visibleForTesting
String? computeRedirect({
  required String location,
  required AsyncValue<UserModel?> authState,
  required bool hasPinSet,
  required bool pinUnlocked,
}) {
  // Don't redirect while auth is still resolving — avoids /login flash on
  // cold start for users with a cached Firebase session.
  if (authState.isLoading) return null;

  final isLoggedIn = authState.valueOrNull != null;
  final isAuthRoute =
      location == AppRoutes.login || location == AppRoutes.register;
  final isPinSetup = location == AppRoutes.pinSetup;
  final isPinEntry = location == AppRoutes.pinEntry;

  // ── Not logged in ──────────────────────────────────────────────────────────
  if (!isLoggedIn) return isAuthRoute ? null : AppRoutes.login;

  // ── Logged in — app-level PIN gate ─────────────────────────────────────────
  if (!hasPinSet) return isPinSetup ? null : AppRoutes.pinSetup;
  if (!pinUnlocked) return isPinEntry ? null : AppRoutes.pinEntry;

  // ── PIN unlocked — bounce away from auth/pin screens ───────────────────────
  if (isAuthRoute || isPinSetup || isPinEntry) return AppRoutes.home;

  return null;
}

@Riverpod(keepAlive: true)
GoRouter router(RouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) => computeRedirect(
      location: state.matchedLocation,
      authState: authState,
      hasPinSet: ref.read(appPinServiceProvider).hasPinSet(),
      pinUnlocked: ref.read(appPinSessionProvider),
    ),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (ctx, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (ctx, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.pinSetup,
        builder: (ctx, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.pinEntry,
        builder: (ctx, state) => const PinEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (ctx, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.shelf,
        builder: (ctx, state) =>
            ShelfContentScreen(shelfId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.newBook,
        builder: (ctx, state) => const NewBookScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookInfo,
        builder: (ctx, state) =>
            BookInfoScreen(bookId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.reading,
        builder: (ctx, state) =>
            ReadingScreen(bookId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.note,
        builder: (ctx, state) =>
            NoteScreen(bookId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (ctx, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (ctx, state) => const EditProfileScreen(),
      ),
    ],
  );
}
