import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/local/achievement_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../library/presentation/library_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final user = ref.watch(userProfileProvider).valueOrNull;
    final allBooks = ref.watch(allBooksProvider).valueOrNull ?? [];
    final shelves = ref.watch(shelvesProvider).valueOrNull ?? [];

    final readCount = allBooks.length;
    final notesCount = ref.watch(userNotesCountProvider).valueOrNull ?? 0;
    final shelvesCount = shelves.length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: AppDrawer(
        active: NavSection.profile,
        onClose: () => _scaffoldKey.currentState?.closeDrawer(),
      ),
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
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
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

                    // ── Achievements ─────────────────────────────────
                    const _AchievementsSection(),
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
                  size: 22,
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

/// Profile screen achievement grid. Section title shows progress
/// `(unlocked/total)`; tiles are 3 across with a circular icon, label, and
/// locked-state overlay. Tapping a tile opens a small modal with the
/// description and unlock date.
class _AchievementsSection extends ConsumerWidget {
  const _AchievementsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);
    final unlockedCount = achievements.where((a) => a.unlocked).length;
    final total = achievements.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ACHIEVEMENTS',
              style: AppTypography.sectionMeta,
            ),
            const Spacer(),
            Text(
              '$unlockedCount / $total',
              style: AppTypography.captionBold.copyWith(
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            // 0.7 aspect leaves room for the locked-state progress bar +
            // counter under the title without clipping the icon.
            childAspectRatio: 0.7,
          ),
          itemCount: total,
          itemBuilder: (ctx, i) => _AchievementTile(
            achievement: achievements[i],
            onTap: () => _showDetail(context, achievements[i]),
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, Achievement a) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 32,
                backgroundColor: a.unlocked
                    ? AppColors.iconBlueTint
                    : AppColors.surfaceMuted,
                child: Icon(
                  a.icon,
                  size: 32,
                  color: a.unlocked ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Text(a.title, style: AppTypography.titleLarge),
              const SizedBox(height: 4),
              Text(
                a.description,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (a.unlocked && a.unlockedAt != null)
                Text(
                  'Unlocked ${_formatDate(a.unlockedAt!)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                )
              else ...[
                // Locked: show progress bar + "X / Y to go" hint so the user
                // sees how close they are. Hidden for unlocked badges where
                // the unlock date is the more useful signal.
                Text(
                  '${a.current} / ${a.target}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: a.ratio,
                    minHeight: 6,
                    backgroundColor: AppColors.progressTrack,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _remainingHint(a),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Natural-language hint per-achievement, used under the progress bar in
  /// the detail dialog. Numeric remainders kept singular/plural-correct so
  /// "1 book to go" doesn't read "1 books to go".
  static String _remainingHint(Achievement a) {
    final remaining = (a.target - a.current).clamp(0, a.target);
    if (remaining == 0 && !a.unlocked) {
      return 'Almost there — open the app once more to unlock.';
    }
    switch (a.id) {
      case AchievementIds.firstBook:
      case AchievementIds.bookworm:
        return remaining == 1
            ? 'Finish 1 more book'
            : 'Finish $remaining more books';
      case AchievementIds.streak3:
      case AchievementIds.streak7:
      case AchievementIds.streak30:
        return remaining == 1
            ? '1 more day to go'
            : '$remaining more days to go';
      case AchievementIds.surpriseReader:
        return remaining == 1
            ? 'Use Surprise Me 1 more time'
            : 'Use Surprise Me $remaining more times';
      case AchievementIds.karaokeStar:
        return remaining == 1
            ? 'Use TTS in 1 more book'
            : 'Use TTS in $remaining more books';
    }
    return '$remaining to go';
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onTap;
  const _AchievementTile({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Semantics(
      button: true,
      label: 'Achievement: ${achievement.title}, '
          '${unlocked ? "unlocked" : "locked"}',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: unlocked
                          ? AppColors.iconBlueTint
                          : AppColors.surfaceMuted,
                      child: Icon(
                        achievement.icon,
                        size: 24,
                        color: unlocked
                            ? AppColors.primary
                            : AppColors.textDisabled,
                      ),
                    ),
                    if (!unlocked)
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(
                          Icons.lock,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  achievement.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.captionBold.copyWith(
                    fontSize: 11,
                    color: unlocked
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${achievement.current}/${achievement.target}',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: achievement.ratio,
                        backgroundColor: AppColors.progressTrack,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
