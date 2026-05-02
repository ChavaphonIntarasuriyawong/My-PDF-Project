import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/local/achievement_service.dart';
import '../../../core/local/book_finish_service.dart';
import '../../../core/local/streak_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/pdf_card.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/book_model.dart';
import '../domain/bookshelf_model.dart';
import 'library_controller.dart';
import 'library_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Sentinel used as `shelfId` for the synthetic "All" shelf — recognized
/// by ShelfContentScreen which then loads books from allBooksProvider.
const String kAllShelfId = 'all';

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Shared RNG for the Surprise Me feature. Single instance avoids the cost
  /// of re-seeding a new Random() per tap, and isolates the cryptographic
  /// non-requirement (no need for Random.secure for casual book selection).
  final _surpriseRng = Random();

  /// Streak milestone celebration — fires once per crossing of 7/30/100 day
  /// boundaries. The reader's `recordOpen()` queues the milestone via the
  /// notifier; the home screen consumes it on the next mount/build.
  late final ConfettiController _milestoneConfetti;

  @override
  void initState() {
    super.initState();
    _milestoneConfetti = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    // Defer to the first frame so the controller and snackbar messenger are
    // both bound before we try to fire. Reading the notifier inside initState
    // is safe (it's a Provider, not a StreamProvider) but the SnackBar requires
    // a built ScaffoldMessenger.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        ref.read(streakStateProvider.notifier).recordOpen();
      } catch (e) {
        debugPrint('[streak] home recordOpen failed: $e');
      }
      _maybeCelebrate();
    });
  }

  @override
  void dispose() {
    _milestoneConfetti.dispose();
    super.dispose();
  }

  /// Pull any pending milestone from the streak notifier (set by the reader's
  /// recordOpen call) and surface a one-shot confetti + snackbar. Tries the
  /// notifier-cached value first (zero-cost) and falls back to the persisted
  /// service check for cold-starts where the notifier hasn't seen recordOpen.
  void _maybeCelebrate() {
    if (!mounted) return;
    int? milestone;
    try {
      final notifier = ref.read(streakStateProvider.notifier);
      milestone = notifier.pendingMilestone;
      notifier.consumeMilestone();
    } catch (_) {
      milestone = null;
    }
    // Cold-start path: the streak service has the milestone set in Hive but
    // the notifier hasn't seen it (recordOpen ran earlier and the app
    // restarted). takePendingMilestone marks it celebrated atomically.
    if (milestone == null) {
      try {
        final svc = ref.read(streakServiceProvider);
        // Fire-and-forget — the result lands on the next frame which is fine.
        svc.takePendingMilestone().then((m) {
          if (m != null && mounted) _showMilestone(m);
        });
      } catch (_) {
        /* Hive not open — ignore */
      }
      return;
    }
    _showMilestone(milestone);
  }

  void _showMilestone(int milestone) {
    if (!mounted) return;
    _milestoneConfetti.play();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔥 $milestone day streak!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  /// Picks a random unread book and navigates to its reader. "Unread" =
  /// not finished AND not in the top 3 most-recent recents (filters out
  /// "in progress" books so this feels like a discovery affordance).
  /// Falls back to any book if no unread candidate exists.
  void _surpriseMe() {
    final books = ref.read(allBooksProvider).valueOrNull ?? const <BookModel>[];
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No books yet — add one first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final recentIds = (ref.read(recentBookIdsProvider).valueOrNull ?? const [])
        .take(3)
        .toSet();
    BookFinishService? finishSvc;
    try {
      finishSvc = ref.read(bookFinishServiceProvider);
    } catch (_) {/* Hive not open in tests — proceed without finish filter */}

    final unread = [
      for (final b in books)
        if (!recentIds.contains(b.id) &&
            !(finishSvc?.isFinished(b.id) ?? false))
          b,
    ];

    final pool = unread.isNotEmpty ? unread : books;
    final pick = pool[_surpriseRng.nextInt(pool.length)];

    // Achievement counter (Surprise Reader at 5 uses).
    try {
      final unlocks = ref
          .read(achievementsProvider.notifier)
          .record(AchievementEvent.surpriseMeUsed());
      _surfaceAchievementUnlocks(unlocks);
    } catch (_) {/* Hive not open */}

    context.push('/book/${pick.id}/reading');
  }

  void _surfaceAchievementUnlocks(List<String> ids) {
    if (ids.isEmpty) return;
    if (!mounted) return;
    final svc = ref.read(achievementServiceProvider);
    for (final id in ids) {
      final ach = svc.findById(id);
      if (ach == null) continue;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(ach.icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Unlocked: ${ach.title}')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    _milestoneConfetti.play();
  }

  void _showNewShelfModal() {
    final ctrl = TextEditingController();
    showAppModal(
      context: context,
      builder: (ctx) => AppModal(
        title: 'New Shelf',
        titleIcon: Icons.shelves,
        confirmLabel: 'Create',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organize your intelligence. Shelves act as curated collections for specific research topics or projects.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 24),
            LabeledTextField(
              label: 'Shelf Name',
              hint: 'e.g. Behavioral Economics 2024',
              controller: ctrl,
            ),
          ],
        ),
        onConfirm: () async {
          if (ctrl.text.trim().isEmpty) return;
          final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
          final ok = await ref
              .read(libraryControllerProvider.notifier)
              .createShelf(ctrl.text.trim(), uid);
          if (ok && ctx.mounted) {
            Navigator.of(ctx).pop();
          } else if (ctx.mounted) {
            final err = ref.read(libraryControllerProvider).error;
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(err?.toString() ?? 'Could not create shelf'),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // userProfileProvider watches Firestore directly → real-time updates
    final user = ref.watch(userProfileProvider).valueOrNull;
    final shelves = ref.watch(shelvesProvider);
    final allBooks = ref.watch(allBooksProvider);

    final books = allBooks.valueOrNull ?? [];
    // Recent Readings — top 5 books by lastReadAt (most recent first, nulls last).
    final recentReadings = [...books]
      ..sort((a, b) {
        final da = a.lastReadAt;
        final db = b.lastReadAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    final recentReadingsTop5 = recentReadings.take(5).toList(growable: false);
    // Streak pill: watch the reactive count notifier; hidden when 0 so the
    // first cold-start (no opens yet) doesn't show "0 day streak".
    final streakCount = ref.watch(streakStateProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _AppDrawer(
        userName: user?.name ?? '',
        userEmail: user?.email ?? '',
        books: books,
        shelves: shelves.valueOrNull ?? [],
        onClose: () => _scaffoldKey.currentState?.closeDrawer(),
      ),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top app bar — drawer button + logo.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.menu,
                            color: AppColors.primary,
                            size: 20,
                          ),
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
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_greeting()}, ${user?.name ?? ''}'
                                          .toUpperCase(),
                                      style: AppTypography.greeting,
                                    ),
                                  ),
                                  if (streakCount > 0) ...[
                                    const SizedBox(width: 12),
                                    _StreakPill(count: streakCount),
                                  ],
                                  const SizedBox(width: 8),
                                  Semantics(
                                    button: true,
                                    label: 'Open random book',
                                    child: IconButton(
                                      onPressed: _surpriseMe,
                                      tooltip: 'Surprise me — open a random book',
                                      icon: const Icon(
                                        Icons.casino,
                                        size: 22,
                                        color: AppColors.primary,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 40,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your Digital Library',
                                style: AppTypography.headlineLarge,
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Book Shelves',
                                style: AppTypography.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              shelves.when(
                                data: (list) => Column(
                                  children: [
                                    _ShelfRow(
                                      name: 'All',
                                      count: books.length,
                                      selected: false,
                                      onTap: () =>
                                          context.push('/shelf/$kAllShelfId'),
                                    ),
                                    ...list.map(
                                      (s) => _ShelfRow(
                                        name: s.name,
                                        count: books
                                            .where((b) => b.shelfId == s.id)
                                            .length,
                                        selected: false,
                                        onTap: () =>
                                            context.push('/shelf/${s.id}'),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    GestureDetector(
                                      onTap: _showNewShelfModal,
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(17),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.borderSubtle,
                                            style: BorderStyle.solid,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.add,
                                              size: 18,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'NEW SHELF',
                                              style: AppTypography.labelSmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                loading: () => const _ShimmerList(count: 3),
                                error: (e, _) => Text(
                                  'Error: $e',
                                  style: AppTypography.bodySmall,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text('All PDF', style: AppTypography.titleMedium),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      if (allBooks.isLoading)
                        const SliverToBoxAdapter(child: _ShimmerList(count: 2))
                      else if (recentReadingsTop5.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 48,
                            ),
                            child: Center(
                              child: Text(
                                'No books yet. Tap Create to add one.',
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 128),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final book = recentReadingsTop5[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: SizedBox(
                                    height: 548,
                                    child: PdfCard(
                                      book: book,
                                      onTap: () =>
                                          context.push('/book/${book.id}'),
                                    ),
                                  ),
                                );
                              },
                              childCount: recentReadingsTop5.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Streak milestone confetti — decorative overlay above the Column.
          // ExcludeSemantics keeps screen readers focused on the content
          // beneath. Origin pinned to the top center; particles rain down.
          ExcludeSemantics(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _milestoneConfetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                gravity: 0.3,
                maxBlastForce: 25,
                minBlastForce: 8,
                emissionFrequency: 0.05,
                shouldLoop: false,
                colors: const [
                  AppColors.primary,
                  AppColors.iconBlueTint,
                  AppColors.statusFinishedBg,
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        onTap: (tab) {
          if (tab == NavTab.create) context.push(AppRoutes.newBook);
          if (tab == NavTab.profile) context.push(AppRoutes.profile);
        },
      ),
    );
  }
}

// ── Side drawer ────────────────────────────────────────────────────────────────

class _AppDrawer extends ConsumerWidget {
  final String userName;
  final String userEmail;
  final List<BookModel> books;
  final List<BookshelfModel> shelves;
  final VoidCallback onClose;

  const _AppDrawer({
    required this.userName,
    required this.userEmail,
    required this.books,
    required this.shelves,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readCount = books.length;
    final notesCount = ref.watch(userNotesCountProvider).valueOrNull ?? 0;

    return Drawer(
      backgroundColor: AppColors.surfaceMuted,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userEmail,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Stats mini-card ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniStat(label: 'READ', value: '$readCount'),
                      ),
                      VerticalDivider(width: 1, color: AppColors.borderSubtle),
                      Expanded(
                        child: _MiniStat(label: 'NOTES', value: '$notesCount'),
                      ),
                      VerticalDivider(width: 1, color: AppColors.borderSubtle),
                      Expanded(
                        child: _MiniStat(
                          label: 'SHELVES',
                          value: '${shelves.length}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── MAIN NAVIGATION ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('MAIN NAVIGATION', style: AppTypography.sectionMeta),
            ),
            _DrawerNavTile(
              icon: Icons.person_outline,
              label: 'PROFILE',
              onTap: () {
                onClose();
                final router = GoRouter.of(context);
                Future.delayed(
                  const Duration(milliseconds: 200),
                  () => router.push(AppRoutes.profile),
                );
              },
            ),
            _DrawerNavTile(
              icon: FontAwesomeIcons.bookOpenReader,
              label: 'LIBRARY',
              active: true,
              onTap: onClose,
            ),
            _DrawerNavTile(
              icon: Icons.add,
              label: 'CREATE',
              onTap: () {
                onClose();
                final router = GoRouter.of(context);
                Future.delayed(
                  const Duration(milliseconds: 200),
                  () => router.push(AppRoutes.newBook),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(color: AppColors.borderSubtle),
            ),
            _DrawerNavTile(
              icon: Icons.settings_outlined,
              label: 'SETTINGS',
              onTap: () {
                onClose();
                final router = GoRouter.of(context);
                Future.delayed(
                  const Duration(milliseconds: 200),
                  () => router.push('${AppRoutes.profile}/edit'),
                );
              },
            ),

            const Spacer(),

            // ── Logout ────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: AppColors.borderSubtle),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: ListTile(
                leading: const Icon(
                  Icons.logout,
                  size: 18,
                  color: AppColors.error,
                ),
                title: const Text(
                  'LOGOUT',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5,
                    color: AppColors.error,
                  ),
                ),
                onTap: () async {
                  onClose();
                  await ref.read(authControllerProvider.notifier).logout();
                },
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: const Text(
                'MYPDF',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1.0,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _DrawerNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DrawerNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Material(
        color: active ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5,
                    color: active ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shelf row ──────────────────────────────────────────────────────────────────

class _ShelfRow extends StatelessWidget {
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _ShelfRow({
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.folder_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: AppTypography.labelLarge)),
            Text('$count', style: AppTypography.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  final int count;
  const _ShimmerList({required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

/// Compact pill summarizing the user's reading streak. Hidden from the home
/// rail when count is 0 (kSink) so a fresh install doesn't display a "0 day"
/// badge before the user has opened any book.
class _StreakPill extends StatelessWidget {
  final int count;
  const _StreakPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count day reading streak',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.iconBlueTint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: AppTypography.captionBold.copyWith(
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
