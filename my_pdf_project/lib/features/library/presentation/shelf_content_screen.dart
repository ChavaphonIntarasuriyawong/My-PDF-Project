import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/pdf_card.dart';
import 'home_screen.dart' show kAllShelfId;
import 'library_controller.dart';
import 'library_providers.dart';

class ShelfContentScreen extends ConsumerWidget {
  final String shelfId;
  const ShelfContentScreen({super.key, required this.shelfId});

  bool get _isAll => shelfId == kAllShelfId;

  Future<void> _showShelfMenu(
      BuildContext context, WidgetRef ref, String shelfName, Offset anchor) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        anchor.dx - 149, anchor.dy + 8, 16, 0,
      ),
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
        body: LabeledTextField(label: 'Shelf Name', hint: current, controller: ctrl),
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
              SnackBar(content: Text(err?.toString() ?? 'Could not rename shelf')),
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
          await ref.read(libraryControllerProvider.notifier).deleteShelf(shelfId);
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
    final shelf = _isAll ? null : shelves.where((s) => s.id == shelfId).firstOrNull;
    // For the synthetic "All" shelf, fall through to allBooksProvider so the
    // page lists every book in the user's library, not just one shelf.
    final books = _isAll
        ? ref.watch(allBooksProvider)
        : ref.watch(booksByShelfProvider(shelfId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
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
                      child: const Icon(Icons.arrow_back,
                          color: AppColors.primary, size: 16),
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
                        icon: const Icon(Icons.more_vert,
                            color: AppColors.primary),
                        onPressed: shelf == null
                            ? null
                            : () {
                                final box = btnCtx.findRenderObject()
                                    as RenderBox?;
                                final anchor = box != null
                                    ? box.localToGlobal(
                                        Offset(box.size.width, 0))
                                    : Offset.zero;
                                _showShelfMenu(
                                    context, ref, shelf.name, anchor);
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
                        itemBuilder: (_, i) {
                          final book = list[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: SizedBox(
                              height: 548,
                              child: PdfCard(
                                book: book,
                                onTap: () => context.push('/book/${book.id}'),
                              ),
                            ),
                          );
                        },
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
    );
  }
}
