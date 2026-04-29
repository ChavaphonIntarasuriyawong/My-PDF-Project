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
import '../../reader/presentation/note_edit_screen.dart';
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
                if (book.author != null || book.year != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (book.author != null) 'by ${book.author}',
                      if (book.year != null) '${book.year}',
                    ].join(' · '),
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
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
                // ── Annotated Insights section ─────────────────────────
                _NotesSection(bookId: book.id),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Notes list with multi-select-on-long-press behavior.
/// Lives entirely on this screen — selection state is UI-local so a plain
/// StatefulWidget with setState is appropriate here.
class _NotesSection extends ConsumerStatefulWidget {
  final String bookId;
  const _NotesSection({required this.bookId});

  @override
  ConsumerState<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends ConsumerState<_NotesSection> {
  final Set<String> _selected = {};
  bool get _inSelectionMode => _selected.isNotEmpty;

  void _toggle(String noteId) {
    setState(() {
      if (_selected.contains(noteId)) {
        _selected.remove(noteId);
      } else {
        _selected.add(noteId);
      }
    });
  }

  void _selectAll(List<NoteModel> notes) {
    setState(() {
      final allIds = notes.map((n) => n.id).toSet();
      // Toggle: if everything is already selected, deselect all; else select all.
      if (_selected.length == notes.length &&
          _selected.containsAll(allIds)) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  void _clearSelection() {
    setState(_selected.clear);
  }

  void _confirmDeleteSelected() {
    final count = _selected.length;
    final ids = _selected.toList();
    showAppModal(
      context: context,
      builder: (ctx) => AppModal(
        title: count == 1 ? 'Delete Note' : 'Delete Notes',
        titleIcon: Icons.delete_outline,
        confirmLabel: 'Delete',
        confirmDestructive: true,
        body: Text(
          count == 1
              ? 'This note will be permanently deleted. This action cannot be undone.'
              : 'These $count notes will be permanently deleted. This action cannot be undone.',
          style: AppTypography.bodyMedium,
        ),
        onConfirm: () async {
          final ctrl = ref.read(libraryControllerProvider.notifier);
          for (final id in ids) {
            await ctrl.deleteNote(id);
          }
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (mounted) _clearSelection();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesByBookProvider(widget.bookId));
    return notesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Text('Error: $e', style: AppTypography.bodySmall),
      data: (notes) {
        // Drop selections that no longer exist (e.g., after a delete).
        final validIds = notes.map((n) => n.id).toSet();
        _selected.removeWhere((id) => !validIds.contains(id));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Annotated Insights (${notes.length})',
              style: AppTypography.titleLarge
                  .copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            // Header action row — Add Note when idle, selection toolbar when selecting.
            _inSelectionMode
                ? _SelectionToolbar(
                    count: _selected.length,
                    total: notes.length,
                    allSelected: _selected.length == notes.length,
                    onCancel: _clearSelection,
                    onSelectAll: () => _selectAll(notes),
                    onDelete: _confirmDeleteSelected,
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => showNoteEditSheet(context,
                          bookId: widget.bookId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_comment_outlined,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Add Note',
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            if (notes.isEmpty)
              Container(
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
            else
              ...notes.map((n) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NotePreview(
                      note: n,
                      selected: _selected.contains(n.id),
                      selectionMode: _inSelectionMode,
                      onTap: () {
                        if (_inSelectionMode) {
                          _toggle(n.id);
                        } else {
                          showNoteEditSheet(context,
                              bookId: widget.bookId, noteId: n.id);
                        }
                      },
                      onLongPress: () => _toggle(n.id),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  final int count;
  final int total;
  final bool allSelected;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;

  const _SelectionToolbar({
    required this.count,
    required this.total,
    required this.allSelected,
    required this.onCancel,
    required this.onSelectAll,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1 — count + cancel X
          Row(
            children: [
              Expanded(
                child: Text(
                  '$count of $total selected',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onCancel,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close,
                      color: AppColors.primary, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2 — Select all + Delete
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onSelectAll,
                    icon: Icon(
                      allSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      allSelected ? 'Deselect all' : 'Select all',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.white),
                    label: Text(
                      'Delete ($count)',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotePreview extends StatelessWidget {
  final NoteModel note;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NotePreview({
    required this.note,
    required this.onTap,
    required this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
  });

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = note.title.trim().isEmpty ? 'Untitled' : note.title.trim();
    final preview = note.content.trim().isEmpty
        ? '(empty note)'
        : note.content.trim();
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTypography.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDate(note.updatedAt),
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preview,
                      style: AppTypography.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
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
            const Icon(Icons.folder_rounded,
                size: 20, color: AppColors.primary),
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
