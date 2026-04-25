import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/pdf_card.dart';
import '../../auth/presentation/auth_providers.dart';
import 'library_controller.dart';
import 'library_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedShelfId;

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
        confirmLabel: 'Create',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organize your intelligence. Shelves act as curated collections for specific research topics or projects.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 24),
            LabeledTextField(label: 'Shelf Name', hint: 'e.g. Behavioral Economics 2024', controller: ctrl),
          ],
        ),
        onConfirm: () async {
          if (ctrl.text.trim().isEmpty) return;
          final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
          final ok = await ref.read(libraryControllerProvider.notifier).createShelf(ctrl.text.trim(), uid);
          if (ok && ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final shelves = ref.watch(shelvesProvider);
    final allBooks = ref.watch(allBooksProvider);

    final books = allBooks.valueOrNull ?? [];
    final filtered = _selectedShelfId == null
        ? books
        : books.where((b) => b.shelfId == _selectedShelfId).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top app bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.menu, color: AppColors.primary, size: 20),
                  const SizedBox(width: 16),
                  Text('MYPDF', style: AppTypography.titleLarge),
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
                            '${_greeting()}, ${user?.name ?? ''}',
                            style: AppTypography.greeting,
                          ).withUpperCase(),
                          const SizedBox(height: 4),
                          Text('Your Digital Library', style: AppTypography.headlineLarge),
                          const SizedBox(height: 32),
                          // Bookshelves section
                          Text('Book Shelves', style: AppTypography.titleMedium),
                          const SizedBox(height: 12),
                          shelves.when(
                            data: (list) => Column(
                              children: [
                                // "All" row
                                _ShelfRow(
                                  name: 'All',
                                  count: books.length,
                                  selected: _selectedShelfId == null,
                                  onTap: () => setState(() => _selectedShelfId = null),
                                ),
                                ...list.map((s) => _ShelfRow(
                                  name: s.name,
                                  count: books.where((b) => b.shelfId == s.id).length,
                                  selected: _selectedShelfId == s.id,
                                  onTap: () => setState(() => _selectedShelfId = s.id),
                                  onLongPress: () => context.push('/shelf/${s.id}'),
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
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add, size: 10, color: AppColors.textSecondary),
                                        const SizedBox(width: 8),
                                        Text('NEW SHELF', style: AppTypography.labelSmall),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            loading: () => const _ShimmerList(count: 3),
                            error: (e, _) => Text('Error: $e', style: AppTypography.bodySmall),
                          ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                        child: Center(
                          child: Text('No books yet. Tap Create to add one.', style: AppTypography.bodyMedium),
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
                              height: 420,
                              child: PdfCard(
                                book: filtered[i],
                                onTap: () => context.push('/book/${filtered[i].id}'),
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
        active: NavTab.library,
        onTap: (tab) {
          if (tab == NavTab.create) context.push(AppRoutes.newBook);
          if (tab == NavTab.profile) context.push(AppRoutes.profile);
        },
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ShelfRow({
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: AppColors.primary, width: 1.5) : null,
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 18, color: AppColors.textSecondary),
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

extension on Text {
  Widget withUpperCase() => Builder(
    builder: (ctx) => Text(
      (data ?? '').toUpperCase(),
      style: style,
    ),
  );
}
