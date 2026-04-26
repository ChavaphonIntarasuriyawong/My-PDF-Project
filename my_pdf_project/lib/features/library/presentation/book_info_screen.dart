import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../reader/presentation/note_screen.dart' show kNotePreviewMaxChars;
import '../domain/book_model.dart';
import '../domain/bookshelf_model.dart';
import '../domain/note_model.dart';
import 'library_controller.dart';
import 'library_providers.dart';

class BookInfoScreen extends ConsumerWidget {
  final String bookId;
  const BookInfoScreen({super.key, required this.bookId});

  void _showStatusModal(BuildContext context, WidgetRef ref, BookModel book) {
    String selected = book.status;
    showAppModal(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AppModal(
          title: 'Update Status',
          confirmLabel: 'Save',
          body: Column(
            children: ['reading', 'on_hold', 'finished'].map((s) {
              return GestureDetector(
                onTap: () => setModal(() => selected = s),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: selected == s
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      StatusBadge(s),
                      const SizedBox(width: 12),
                      Text(
                        s == 'on_hold' ? 'On Hold' : s[0].toUpperCase() + s.substring(1),
                        style: AppTypography.labelLarge,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          onConfirm: () async {
            final ok = await ref
                .read(libraryControllerProvider.notifier)
                .updateStatus(book.id, selected);
            if (!ctx.mounted) return;
            if (ok) {
              Navigator.of(ctx).pop();
            } else {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Could not update status')),
              );
            }
          },
        ),
      ),
    );
  }

  void _showRenameModal(BuildContext context, WidgetRef ref, BookModel book) {
    final ctrl = TextEditingController(text: book.title);
    showAppModal(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Edit PDF name',
        confirmLabel: 'Confirm',
        body: LabeledTextField(
          label: 'PDF LINK NAME',
          hint: book.title,
          controller: ctrl,
        ),
        onConfirm: () async {
          if (ctrl.text.trim().isEmpty) return;
          final ok = await ref
              .read(libraryControllerProvider.notifier)
              .renameBook(book.id, ctrl.text.trim());
          if (!ctx.mounted) return;
          if (ok) {
            Navigator.of(ctx).pop();
          } else {
            final err = ref.read(libraryControllerProvider).error;
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(err?.toString() ?? 'Could not rename')),
            );
          }
        },
      ),
    );
  }

  void _showMoveShelfModal(
      BuildContext context, WidgetRef ref, BookModel book, List<BookshelfModel> shelves) {
    String? selected = book.shelfId.isEmpty ? null : book.shelfId;
    showAppModal(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AppModal(
          title: 'Move to Shelf',
          confirmLabel: 'Move',
          body: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ShelfPick(
                  name: 'No Shelf',
                  selected: selected == null,
                  onTap: () => setModal(() => selected = null),
                ),
                ...shelves.map((s) => _ShelfPick(
                      name: s.name,
                      selected: selected == s.id,
                      onTap: () => setModal(() => selected = s.id),
                    )),
              ],
            ),
          ),
          onConfirm: () async {
            final ok = await ref
                .read(libraryControllerProvider.notifier)
                .moveBook(book.id, selected ?? '');
            if (!ctx.mounted) return;
            if (ok) {
              Navigator.of(ctx).pop();
            } else {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Could not move book')),
              );
            }
          },
        ),
      ),
    );
  }

  void _showDeleteModal(BuildContext context, WidgetRef ref) {
    showAppModal(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Delete Book',
        confirmLabel: 'Delete',
        confirmDestructive: true,
        body: Text(
          'This will permanently delete this book and its notes.',
          style: AppTypography.bodyMedium,
        ),
        onConfirm: () async {
          await ref.read(libraryControllerProvider.notifier).deleteBook(bookId);
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
            context.go('/home');
          }
        },
      ),
    );
  }

  Future<void> _showOptionsMenu(BuildContext context, WidgetRef ref,
      BookModel book, List<BookshelfModel> shelves, Offset anchor) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        anchor.dx - 149, anchor.dy + 8, 16, 0,
      ),
      color: AppColors.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      items: [
        for (final entry in const [
          ('edit', 'Edit'),
          ('delete', 'Delete'),
          ('move', 'Move to'),
          ('status', 'Status'),
        ])
          PopupMenuItem<String>(
            value: entry.$1,
            height: 51,
            child: Center(
              child: Text(
                entry.$2,
                style: const TextStyle(
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
    switch (selected) {
      case 'edit':
        _showRenameModal(context, ref, book);
        break;
      case 'delete':
        _showDeleteModal(context, ref);
        break;
      case 'move':
        _showMoveShelfModal(context, ref, book, shelves);
        break;
      case 'status':
        _showStatusModal(context, ref, book);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookByIdProvider(bookId));

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNavBar(
        onTap: (tab) {
          if (tab == NavTab.library) context.go('/home');
          if (tab == NavTab.create) context.push('/book/new');
          if (tab == NavTab.profile) context.push('/profile');
        },
      ),
      floatingActionButton: bookAsync.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/book/$bookId/reading'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              label: Text(
                'Read',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: bookAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Error: $e', style: AppTypography.bodyMedium)),
          data: (book) {
            if (book == null) {
              return Center(
                  child: Text('Book not found', style: AppTypography.bodyMedium));
            }
            return _buildBody(context, ref, book);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, BookModel book) {
    final progress = book.totalPages > 0 ? book.currentPage / book.totalPages : 0.0;
    final thumbAsync = book.link.isNotEmpty
        ? ref.watch(pdfThumbnailProvider(book.link))
        : const AsyncValue<Uint8List?>.data(null);
    final shelves = ref.watch(shelvesProvider).valueOrNull ?? [];
    final notesAsync = ref.watch(notesByBookProvider(book.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
                child:
                    const Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  book.title,
                  style: AppTypography.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Builder(
                builder: (btnCtx) => IconButton(
                  icon: const Icon(Icons.more_vert, color: AppColors.primary),
                  onPressed: () {
                    final box = btnCtx.findRenderObject() as RenderBox?;
                    final anchor = box != null
                        ? box.localToGlobal(Offset(box.size.width, 0))
                        : Offset.zero;
                    _showOptionsMenu(context, ref, book, shelves, anchor);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: thumbAsync.when(
                    loading: () => const _CoverPlaceholder(loading: true),
                    error: (e, s) => const _CoverPlaceholder(),
                    data: (bytes) => bytes != null
                        ? Image.memory(bytes,
                            width: double.infinity, height: 240, fit: BoxFit.cover)
                        : const _CoverPlaceholder(),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(book.title, style: AppTypography.headlineMedium),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showStatusModal(context, ref, book),
                      child: StatusBadge(book.status),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Reading Progress', style: AppTypography.labelLarge),
                    Text(
                      '${book.currentPage} / ${book.totalPages} pages',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: AppColors.progressTrack,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${book.progress.toStringAsFixed(0)}% complete',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                // ── Notes section ─────────────────────────────────────
                Row(
                  children: [
                    Text('Notes', style: AppTypography.titleMedium),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/book/${book.id}/note/edit'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_comment_outlined, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text('Add Note',
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                notesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Error: $e',
                      style: AppTypography.bodySmall),
                  data: (notes) => notes.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            'No notes yet. Tap "Add Note" to start writing.',
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        )
                      : Column(
                          children: [
                            ...notes.take(3).map((n) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _NotePreview(
                                    note: n,
                                    onTap: () => context.push(
                                        '/book/${book.id}/note/edit?id=${n.id}'),
                                  ),
                                )),
                            if (notes.length > 3)
                              GestureDetector(
                                onTap: () =>
                                    context.push('/book/${book.id}/note'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'See all ${notes.length} notes →',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () =>
                                    context.push('/book/${book.id}/note'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'See more info →',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NotePreview extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  const _NotePreview({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preview = note.content.trim().isEmpty
        ? '(empty note)'
        : note.content.trim().length > kNotePreviewMaxChars
            ? '${note.content.trim().substring(0, kNotePreviewMaxChars)}…'
            : note.content.trim();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            preview,
            style: AppTypography.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _ShelfPick extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _ShelfPick({required this.name, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_open_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: AppTypography.labelLarge)),
            if (selected)
              const Icon(Icons.check, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final bool loading;
  const _CoverPlaceholder({this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf, size: 72, color: AppColors.primary),
    );
  }
}
