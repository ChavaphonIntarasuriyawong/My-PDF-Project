import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
      if (isLoggedIn && isAuthRoute) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (ctx, state) => const RegisterScreen()),
      GoRoute(path: AppRoutes.home, builder: (ctx, state) => const HomeScreen()),
      GoRoute(
        path: AppRoutes.shelf,
        builder: (ctx, state) => ShelfContentScreen(shelfId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.newBook,
        builder: (ctx, state) => const NewBookScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookInfo,
        builder: (ctx, state) => BookInfoScreen(bookId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.reading,
        builder: (ctx, state) => ReadingScreen(bookId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.note,
        builder: (ctx, state) => NoteScreen(bookId: state.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.profile, builder: (ctx, state) => const ProfileScreen()),
      GoRoute(path: AppRoutes.editProfile, builder: (ctx, state) => const EditProfileScreen()),
    ],
  );
});
