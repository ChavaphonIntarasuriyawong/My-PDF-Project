import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_providers.dart';

/// Persistent 220px-wide sidebar shown on the desktop web shell.
///
/// Reuses the same providers the mobile drawer uses (`userProfileProvider`,
/// `authControllerProvider`) so logout / profile data stay consistent across
/// breakpoints. Highlights the active item via a prefix match against the
/// captured router's current path.
///
/// The router is passed in explicitly because the sidebar renders OUTSIDE the
/// InheritedGoRouter subtree (it lives in `MaterialApp.router.builder`, above
/// the Navigator), so `GoRouter.of(context)` / `context.go` would assert.
class DesktopNavSidebar extends ConsumerWidget {
  final GoRouter router;
  const DesktopNavSidebar({super.key, required this.router});

  static const double width = 220;

  bool _isActive(String matched, String target) {
    if (target == AppRoutes.home) {
      // Library tab also owns shelf, book info, and reading screens.
      return matched == AppRoutes.home ||
          matched.startsWith('/shelf/') ||
          (matched.startsWith('/book/') && matched != AppRoutes.newBook);
    }
    if (target == AppRoutes.profile) {
      return matched == AppRoutes.profile ||
          matched.startsWith('${AppRoutes.profile}/');
    }
    if (target == AppRoutes.newBook) {
      return matched == AppRoutes.newBook;
    }
    return false;
  }

  String _initials(String name, String email) {
    final source = name.trim().isNotEmpty ? name.trim() : email.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'[\s@.]+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return source[0].toUpperCase();
    if (parts.length == 1) {
      final p = parts.first;
      return p.length >= 2
          ? p.substring(0, 2).toUpperCase()
          : p[0].toUpperCase();
    }
    return (parts.first[0] + parts.elementAt(1)[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).valueOrNull;
    final name = user?.name ?? '';
    final email = user?.email ?? '';

    // Wrap in AnimatedBuilder so a route change repaints the active-item
    // highlight — the router delegate notifies listeners on navigation.
    return AnimatedBuilder(
      animation: router.routerDelegate,
      builder: (context, _) {
        final matched =
            router.routerDelegate.currentConfiguration.uri.path;
        return _buildSidebar(context, ref, name, email, matched);
      },
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    WidgetRef ref,
    String name,
    String email,
    String matched,
  ) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surfaceMuted,
          border: Border(
            right: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wordmark
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text(
                  'MYPDF',
                  style: AppTypography.titleLarge.copyWith(
                    fontSize: 18,
                    letterSpacing: -0.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // User card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(name, email),
                        style: AppTypography.labelButton.copyWith(
                          fontSize: 14,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Guest' : name,
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: AppColors.borderSubtle, height: 1),
              ),
              const SizedBox(height: 12),
              _NavItem(
                icon: Icons.person_outline,
                label: 'PROFILE',
                active: _isActive(matched, AppRoutes.profile),
                onTap: () => router.go(AppRoutes.profile),
              ),
              _NavItem(
                icon: Icons.menu_book_outlined,
                label: 'LIBRARY',
                active: _isActive(matched, AppRoutes.home),
                onTap: () => router.go(AppRoutes.home),
              ),
              _NavItem(
                icon: Icons.add,
                label: 'CREATE',
                active: _isActive(matched, AppRoutes.newBook),
                onTap: () => router.go(AppRoutes.newBook),
              ),
              const Spacer(),
              _NavItem(
                icon: Icons.logout,
                label: 'LOGOUT',
                destructive: true,
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  router.go(AppRoutes.login);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool destructive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    // Active page highlights in primary teal + bold weight to match the
    // mobile drawer's active-row treatment.
    final Color fg = destructive
        ? AppColors.error
        : active
        ? AppColors.primary
        : AppColors.textSecondary;
    final FontWeight weight = active ? FontWeight.w700 : FontWeight.w500;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: Colors.transparent,
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: weight,
                  letterSpacing: 0.55,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
