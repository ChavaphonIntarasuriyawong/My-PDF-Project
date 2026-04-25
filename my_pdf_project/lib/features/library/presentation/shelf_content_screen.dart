import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/pdf_card.dart';
import 'library_controller.dart';
import 'library_providers.dart';

class ShelfContentScreen extends ConsumerWidget {
  final String shelfId;
  const ShelfContentScreen({super.key, required this.shelfId});

  void _showShelfMenu(BuildContext context, WidgetRef ref, String shelfName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: Text('Rename Shelf', style: AppTypography.labelLarge),
              onTap: () {
                Navigator.pop(context);
                _showRenameModal(context, ref, shelfName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Delete Shelf', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteModal(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameModal(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showAppModal(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Edit Shelf Name',
        confirmLabel: 'Save',
        body: LabeledTextField(label: 'Shelf Name', hint: current, controller: ctrl),
        onConfirm: () async {
          if (ctrl.text.trim().isEmpty) return;
          await ref.read(libraryControllerProvider.notifier).updateShelfName(shelfId, ctrl.text.trim());
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _showDeleteModal(BuildContext context, WidgetRef ref) {
    showAppModal(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Delete Shelf',
        confirmLabel: 'Delete',
        body: Text(
          'This will permanently delete the shelf. Books inside will not be deleted.',
          style: AppTypography.bodyMedium,
        ),
        onConfirm: () async {
          await ref.read(libraryControllerProvider.notifier).deleteShelf(shelfId);
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
            context.pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelves = ref.watch(shelvesProvider).valueOrNull ?? [];
    final shelf = shelves.where((s) => s.id == shelfId).firstOrNull;
    final books = ref.watch(booksByShelfProvider(shelfId));

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
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: AppColors.primary, size: 16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      shelf?.name ?? 'Collection',
                      style: AppTypography.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.primary),
                    onPressed: shelf == null
                        ? null
                        : () => _showShelfMenu(context, ref, shelf.name),
                  ),
                ],
              ),
            ),
            Expanded(
              child: books.when(
                data: (list) => list.isEmpty
                    ? Center(
                        child: Text('No books in this shelf.', style: AppTypography.bodyMedium),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 128),
                        itemCount: list.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: SizedBox(
                            height: 420,
                            child: PdfCard(
                              book: list[i],
                              onTap: () => context.push('/book/${list[i].id}'),
                            ),
                          ),
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        active: NavTab.library,
        onTap: (tab) {
          if (tab == NavTab.library) context.go('/home');
          if (tab == NavTab.create) context.push('/book/new');
          if (tab == NavTab.profile) context.push('/profile');
        },
      ),
    );
  }
}
