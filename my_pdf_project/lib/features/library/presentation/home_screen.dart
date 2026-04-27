import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedShelfId;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
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
              SnackBar(content: Text(err?.toString() ?? 'Could not create shelf')),
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
    final filtered = _selectedShelfId == null
        ? books
        : books.where((b) => b.shelfId == _selectedShelfId).toList();
    // Recently opened (local Hive). Filter to current shelf when one is selected
    // so the rail respects the same scope as the book list.
    final recents = ref.watch(recentBooksProvider);
    final recentsScoped = _selectedShelfId == null
        ? recents
        : recents.where((b) => b.shelfId == _selectedShelfId).toList();

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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top app bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.menu,
                          color: AppColors.primary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('MYPDF', style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.9,
                    color: AppColors.primary,
                  )),
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
                          Text(
                            '${_greeting()}, ${user?.name ?? ''}'.toUpperCase(),
                            style: AppTypography.greeting,
                          ),
                          const SizedBox(height: 4),
                          Text('Your Digital Library',
                              style: AppTypography.headlineLarge),
                          const SizedBox(height: 32),
                          Text('Book Shelves', style: AppTypography.titleMedium),
                          const SizedBox(height: 12),
                          shelves.when(
                            data: (list) => Column(
                              children: [
                                _ShelfRow(
                                  name: 'All',
                                  count: books.length,
                                  selected: _selectedShelfId == null,
                                  onTap: () =>
                                      setState(() => _selectedShelfId = null),
                                ),
                                ...list.map((s) => _ShelfRow(
                                      name: s.name,
                                      count: books
                                          .where((b) => b.shelfId == s.id)
                                          .length,
                                      selected: false,
                                      onTap: () =>
                                          context.push('/shelf/${s.id}'),
                                    )),
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
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add,
                                            size: 18,
                                            color: AppColors.textSecondary),
                                        const SizedBox(width: 8),
                                        Text('NEW SHELF',
                                            style: AppTypography.labelSmall),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            loading: () => const _ShimmerList(count: 3),
                            error: (e, _) => Text('Error: $e',
                                style: AppTypography.bodySmall),
                          ),
                          if (recentsScoped.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            Text('Recently Opened',
                                style: AppTypography.titleMedium),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 96,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: recentsScoped.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (_, i) => _RecentTile(
                                  book: recentsScoped[i],
                                  onTap: () => context
                                      .push('/book/${recentsScoped[i].id}'),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          Text('Recent Readings', style: AppTypography.titleMedium),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (allBooks.isLoading)
                    const SliverToBoxAdapter(child: _ShimmerList(count: 2))
                  else if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 48),
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
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: SizedBox(
                              height: 548,
                              child: PdfCard(
                                book: filtered[i],
                                onTap: () =>
                                    context.push('/book/${filtered[i].id}'),
                              ),
                            ),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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
                      child: const Icon(Icons.close,
                          size: 20, color: AppColors.textSecondary),
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
                      Expanded(child: _MiniStat(label: 'READ', value: '$readCount')),
                      VerticalDivider(
                          width: 1, color: AppColors.borderSubtle),
                      Expanded(child: _MiniStat(label: 'NOTES', value: '$notesCount')),
                      VerticalDivider(
                          width: 1, color: AppColors.borderSubtle),
                      Expanded(child: _MiniStat(label: 'SHELVES', value: '${shelves.length}')),
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
                    () => router.push(AppRoutes.profile));
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
                    () => router.push(AppRoutes.newBook));
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
                    () => router.push('${AppRoutes.profile}/edit'));
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
                leading: const Icon(Icons.logout, size: 18, color: AppColors.error),
                title: const Text('LOGOUT',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.5,
                      color: AppColors.error,
                    )),
                onTap: () async {
                  onClose();
                  await ref
                      .read(authControllerProvider.notifier)
                      .logout();
                },
                dense: true,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
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
                Icon(icon,
                    size: 18,
                    color: active ? AppColors.primary : AppColors.textSecondary),
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
          border:
              selected ? Border.all(color: AppColors.primary, width: 1.5) : null,
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_rounded,
                size: 20, color: AppColors.primary),
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

class _RecentTile extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;
  const _RecentTile({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.picture_as_pdf,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${book.progress.toStringAsFixed(0)}% • '
                    '${book.currentPage}/${book.totalPages}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
