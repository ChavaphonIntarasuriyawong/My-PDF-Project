import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/layout/responsive.dart';
import '../../../shared/widgets/escape_pop_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/pdf_card.dart';
import '../domain/book_model.dart';
import 'home_screen.dart' show kAllShelfId;
import 'library_controller.dart';
import 'library_providers.dart';

class ShelfContentScreen extends ConsumerWidget {
  final String shelfId;
  const ShelfContentScreen({super.key, required this.shelfId});

  bool get _isAll => shelfId == kAllShelfId;

  Future<void> _showShelfMenu(
    BuildContext context,
    WidgetRef ref,
    String shelfName,
    Offset anchor,
  ) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(anchor.dx - 149, anchor.dy + 8, 16, 0),
      color: AppColors.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          height: 51,
          child: Center(
            child: Text(
              'Edit',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          height: 51,
          child: Center(
            child: Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
    if (!context.mounted) return;
    if (selected == 'edit') {
      _showRenameModal(context, ref, shelfName);
    } else if (selected == 'delete') {
      _showDeleteModal(context, ref);
    }
  }

  void _showRenameModal(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showAppModal(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Edit shelf name',
        confirmLabel: 'Confirm',
        body: LabeledTextField(
          label: 'Shelf Name',
          hint: current,
          controller: ctrl,
        ),
        onConfirm: () async {
          if (ctrl.text.trim().isEmpty) return;
          final ok = await ref
              .read(libraryControllerProvider.notifier)
              .updateShelfName(shelfId, ctrl.text.trim());
          if (ok && ctx.mounted) {
            Navigator.of(ctx).pop();
          } else if (ctx.mounted) {
            final err = ref.read(libraryControllerProvider).error;
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(err?.toString() ?? 'Could not rename shelf'),
              ),
            );
          }
        },
      ),
    );
  }

  void _showDeleteModal(BuildContext context, WidgetRef ref) {
    showAppModal(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Delete shelf',
        confirmLabel: 'Confirm',
        confirmDestructive: true,
        body: Text(
          'Delete this shelf? Books inside will not be deleted — they will be moved out of the shelf and stay in your library.',
          style: AppTypography.bodyMedium,
        ),
        onConfirm: () async {
          await ref
              .read(libraryControllerProvider.notifier)
              .deleteShelf(shelfId);
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelves = ref.watch(shelvesProvider).valueOrNull ?? [];
    final shelf = _isAll
        ? null
        : shelves.where((s) => s.id == shelfId).firstOrNull;
    // For the synthetic "All" shelf, fall through to allBooksProvider so the
    // page lists every book in the user's library, not just one shelf.
    final books = _isAll
        ? ref.watch(allBooksProvider)
        : ref.watch(booksByShelfProvider(shelfId));

    if (kIsWeb && isDesktop(context)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _DesktopBody(
          shelfName: _isAll ? 'All' : (shelf?.name ?? 'Collection'),
          books: books,
        ),
      );
    }

    return EscapePopScope(
      onEscape: () => context.canPop() ? context.pop() : context.go('/home'),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _isAll ? 'All books' : (shelf?.name ?? 'Collection'),
                        style: AppTypography.titleLarge,
                      ),
                    ),
                    // No rename/delete menu for the "All" shelf — it's synthetic.
                    if (!_isAll)
                      Builder(
                        builder: (btnCtx) => IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: AppColors.primary,
                          ),
                          onPressed: shelf == null
                              ? null
                              : () {
                                  final box =
                                      btnCtx.findRenderObject() as RenderBox?;
                                  final anchor = box != null
                                      ? box.localToGlobal(
                                          Offset(box.size.width, 0),
                                        )
                                      : Offset.zero;
                                  _showShelfMenu(
                                    context,
                                    ref,
                                    shelf.name,
                                    anchor,
                                  );
                                },
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'COLLECTION',
                    style: AppTypography.labelSmall.copyWith(
                      letterSpacing: 1.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: books.when(
                  data: (list) => list.isEmpty
                      ? Center(
                          child: Text(
                            _isAll
                                ? 'No books yet. Tap Create to add one.'
                                : 'No books in this shelf.',
                            style: AppTypography.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 128),
                          itemCount: list.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: SizedBox(
                              height: 548,
                              child: PdfCard(
                                book: list[i],
                                onTap: () =>
                                    context.push('/book/${list[i].id}'),
                              ),
                            ),
                          ),
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNavBar(
          onTap: (tab) {
            if (tab == NavTab.library) context.go('/home');
            if (tab == NavTab.create) context.push('/book/new');
            if (tab == NavTab.profile) context.push('/profile');
          },
        ),
      ),
    );
  }
}

// ── Desktop body ──────────────────────────────────────────────────────────
// Reuses the same `booksByShelfProvider` data the mobile body uses — the
// only difference is layout (grid + breadcrumb + "+ New Document" CTA).
class _DesktopBody extends StatelessWidget {
  final String shelfName;
  final AsyncValue<List<BookModel>> books;

  const _DesktopBody({required this.shelfName, required this.books});

  @override
  Widget build(BuildContext context) {
    // Breadcrumb: single COLLECTIONS root + the actual shelf name uppercase.
    final isAll = shelfName == 'All';
    final segment = isAll ? 'ALL' : shelfName.toUpperCase();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(48, 48, 48, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.folder_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'COLLECTIONS / $segment',
                          style: AppTypography.headlineMedium.copyWith(
                            fontSize: 24,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shelfName,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => context.push('/book/new'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_circle,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'New Document',
                        style: AppTypography.labelButton.copyWith(
                          fontSize: 14,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          books.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e', style: AppTypography.bodyMedium),
            data: (list) {
              // Books in a 4-up grid, then the "Add New Document" placeholder
              // ALWAYS on its own row below (matches Figma — it never inlines
              // into the last gap of the books row).
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (list.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 240,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 24,
                            childAspectRatio: 0.65,
                          ),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final b = list[i];
                        return PdfCard(
                          book: b,
                          onTap: () => context.push('/book/${b.id}'),
                        );
                      },
                    ),
                  if (list.isNotEmpty) const SizedBox(height: 24),
                  Center(
                    child: SizedBox(
                      width: 360,
                      height: 160,
                      child: _AddDocumentTile(
                        onTap: () => context.push('/book/new'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AddDocumentTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddDocumentTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add new document',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DottedBorder(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.add,
                    color: AppColors.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add New Document',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
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

/// Lightweight dashed-border container — avoids a new dependency. Uses
/// CustomPainter for the dashes so we stay theme-token compliant.
class DottedBorder extends StatelessWidget {
  final Widget child;
  const DottedBorder({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
