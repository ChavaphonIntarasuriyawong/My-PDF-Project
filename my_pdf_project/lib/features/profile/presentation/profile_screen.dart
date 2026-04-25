import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../library/presentation/library_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).valueOrNull;
    final allBooks = ref.watch(allBooksProvider).valueOrNull ?? [];

    final totalBooks = allBooks.length;
    final reading = allBooks.where((b) => b.status == 'reading').length;
    final finished = allBooks.where((b) => b.status == 'finished').length;
    final onHold = allBooks.where((b) => b.status == 'on_hold').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Text('Profile', style: AppTypography.titleLarge),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + name
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: user?.avatarUrl.isNotEmpty == true
                                ? ClipOval(
                                    child: Image.network(
                                      user!.avatarUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      (user?.name.isNotEmpty == true)
                                          ? user!.name[0].toUpperCase()
                                          : '?',
                                      style: AppTypography.headlineLarge.copyWith(color: Colors.white),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user?.name ?? '',
                            style: AppTypography.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Stats bento
                    Text('Reading Stats', style: AppTypography.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _StatCard(label: 'Total', value: '$totalBooks', icon: Icons.menu_book_outlined)),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(label: 'Reading', value: '$reading', icon: Icons.auto_stories_outlined, color: AppColors.statusReadingBg)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _StatCard(label: 'Finished', value: '$finished', icon: Icons.check_circle_outline, color: AppColors.statusFinishedBg)),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(label: 'On Hold', value: '$onHold', icon: Icons.pause_circle_outline, color: AppColors.statusOnHoldBg)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Account section
                    Text('Account', style: AppTypography.titleMedium),
                    const SizedBox(height: 12),
                    _SettingsRow(
                      icon: Icons.edit_outlined,
                      label: 'Edit Profile',
                      onTap: () => context.push('/profile/edit'),
                    ),
                    const SizedBox(height: 8),
                    _SettingsRow(
                      icon: Icons.logout,
                      label: 'Sign Out',
                      destructive: true,
                      onTap: () async {
                        await ref.read(authControllerProvider.notifier).logout();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        active: NavTab.profile,
        onTap: (tab) {
          if (tab == NavTab.library) context.go('/home');
          if (tab == NavTab.create) context.push('/book/new');
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.surfaceMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(value, style: AppTypography.headlineMedium),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(label, style: AppTypography.labelLarge.copyWith(color: color)),
            const Spacer(),
            if (!destructive)
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
