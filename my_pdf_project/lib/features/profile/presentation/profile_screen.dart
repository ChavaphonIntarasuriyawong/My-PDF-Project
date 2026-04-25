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
    final shelves = ref.watch(shelvesProvider).valueOrNull ?? [];

    final readCount = allBooks.length;
    final notesCount = ref.watch(userNotesCountProvider).valueOrNull ?? 0;
    final shelvesCount = shelves.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.menu,
                          color: AppColors.primary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'MYPDF',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: -0.9,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.surfaceMuted),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name + email
                    Center(
                      child: Column(
                        children: [
                          Text(
                            user?.name ?? '',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w700,
                              fontSize: 30,
                              letterSpacing: -0.75,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Stat cards ───────────────────────────────────
                    _StatCard(label: 'READ', value: '$readCount'),
                    const SizedBox(height: 8),
                    _StatCard(label: 'NOTES', value: '$notesCount'),
                    const SizedBox(height: 8),
                    _StatCard(label: 'SHELVES', value: '$shelvesCount'),
                    const SizedBox(height: 32),

                    // ── Account Settings ─────────────────────────────
                    const Text('ACCOUNT SETTINGS', style: AppTypography.sectionMeta),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          _SettingsRow(
                            icon: Icons.person_outline,
                            iconBg: AppColors.iconBlueTint,
                            label: 'Personal Information',
                            onTap: () => context.push('/profile/edit'),
                          ),
                          const SizedBox(height: 4),
                          _SettingsRow(
                            icon: Icons.logout,
                            iconBg: AppColors.errorContainer,
                            label: 'Logout',
                            labelColor: AppColors.error,
                            onTap: () async {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .logout();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        
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

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w800,
              fontSize: 36,
              height: 1.1,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.label,
    this.labelColor = AppColors.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: labelColor == AppColors.error
                      ? AppColors.error
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: labelColor,
                  ),
                ),
              ),
              if (labelColor == AppColors.textPrimary)
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
