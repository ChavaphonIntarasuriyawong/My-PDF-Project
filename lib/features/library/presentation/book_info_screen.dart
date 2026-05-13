import 'dart:typed_data';
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
import '../../../shared/widgets/desktop_note_editor_panel.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../reader/presentation/note_edit_screen.dart';
import '../domain/book_model.dart';
import '../domain/bookshelf_model.dart';
import '../domain/note_model.dart';
import 'library_controller.dart';
import 'library_providers.dart';
import 'widgets/lock_setup_sheet.dart';

/// Book Info screen — Figma node 25:741 ("Full PDF Reader & Notes View").
///
/// Layout (top to bottom):
/// 1. Sticky top app bar — back / title / 3-dot. In selection mode (Figma
///    node 25:796) it swaps to two text buttons: Cancel (left) / Delete
///    (right), both AppColors.primary.
/// 2. PDF cover card with an inline circular pencil button → reading screen.
/// 3. Annotated Insights section (rounded-top muted sheet) with Add Note CTA.
/// 4. Note cards stacked vertically — long-press enters selection mode.
/// 5. Bottom nav bar.
class BookInfoScreen extends ConsumerStatefulWidget {
  final String bookId;
  const BookInfoScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookInfoScreen> createState() => _BookInfoScreenState();
}

class _BookInfoScreenState extends ConsumerState<BookInfoScreen> {
  /// Selection-mode state — UI-local, not shared, so plain setState is fine.
  final Set<String> _selectedNoteIds = {};
  bool get _inSelectionMode => _selectedNoteIds.isNotEmpty;

  String get bookId => widget.bookId;

  void _toggleNote(String noteId) {
    setState(() {
      if (_selectedNoteIds.contains(noteId)) {
        _selectedNoteIds.remove(noteId);
      } else {
        _selectedNoteIds.add(noteId);
      }
    });
  }

  void _exitSelectionMode() {
    if (_selectedNoteIds.isEmpty) return;
    setState(_selectedNoteIds.clear);
  }

  /// Drop selections that no longer exist (e.g. after a delete or stream
  /// refresh). Called from the notes list builder.
  void _pruneSelection(Set<String> validIds) {
    final stale = _selectedNoteIds
        .where((id) => !validIds.contains(id))
        .toList();
    if (stale.isEmpty) return;
    // Defer so we don't setState during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedNoteIds.removeAll(stale));
    });
  }

  void _confirmDeleteNote(
    BuildContext context,
    WidgetRef ref,
    String noteId,
  ) {
    showAppModal(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Delete Note',
        titleIcon: Icons.delete_outline,
        confirmLabel: 'Delete',
        confirmDestructive: true,
        body: Text(
          'This note will be permanently deleted. This action cannot be undone.',
          style: AppTypography.bodyMedium,
        ),
        onConfirm: () async {
          final ok = await ref
              .read(libraryControllerProvider.notifier)
              .deleteNotes([noteId]);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (!ctx.mounted) return;
          if (ok) {
            ScaffoldMessenger.of(
              ctx,
            ).showSnackBar(const SnackBar(content: Text('1 note deleted')));
          } else {
            final err = ref.read(libraryControllerProvider).error;
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(err?.toString() ?? 'Could not delete note'),
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDeleteSelected() {
    final count = _selectedNoteIds.length;
    final ids = _selectedNoteIds.toList();
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
          final ok = await ref
              .read(libraryControllerProvider.notifier)
              .deleteNotes(ids);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (!mounted) return;
          if (ok) {
            _exitSelectionMode();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  count == 1 ? '1 note deleted' : '$count notes deleted',
                ),
              ),
            );
          } else {
            final err = ref.read(libraryControllerProvider).error;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err?.toString() ?? 'Could not delete notes'),
              ),
            );
          }
        },
      ),
    );
  }

  // ── Modals ──────────────────────────────────────────────────────────────

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
                        s == 'on_hold'
                            ? 'On Hold'
                            : s[0].toUpperCase() + s.substring(1),
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
    BuildContext context,
    WidgetRef ref,
    BookModel book,
    List<BookshelfModel> shelves,
  ) {
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
                ...shelves.map(
                  (s) => _ShelfPick(
                    name: s.name,
                    selected: selected == s.id,
                    onTap: () => setModal(() => selected = s.id),
                  ),
                ),
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

  void _showLockSetupSheet(BookModel book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (sheetCtx) => LockSetupSheet(
        bookId: book.id,
        currentlyLocked: book.isLocked,
        // Bottom sheets cannot reliably surface their own SnackBars (the
        // ScaffoldMessenger they look up is the sheet's local one). Bubble
        // errors back up so the host scaffold's messenger handles them.
        onError: (msg) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        },
      ),
    );
  }

  Future<void> _showOptionsMenu(
    BuildContext context,
    WidgetRef ref,
    BookModel book,
    List<BookshelfModel> shelves,
    Offset anchor,
  ) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(anchor.dx - 149, anchor.dy + 8, 16, 0),
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
                style: AppTypography.labelLarge.copyWith(
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

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookByIdProvider(bookId));

    if (kIsWeb && isDesktop(context)) {
      return EscapePopScope(
        onEscape: () =>
            context.canPop() ? context.pop() : context.go('/home'),
        child: Scaffold(
          // Darker page surface so cover + notes cards pop against the bg.
          backgroundColor: AppColors.surfaceMuted,
          body: bookAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error: $e', style: AppTypography.bodyMedium),
            ),
            data: (book) {
              if (book == null) {
                return Center(
                  child: Text(
                    'Book not found',
                    style: AppTypography.bodyMedium,
                  ),
                );
              }
              return _DesktopBookInfoBody(
                book: book,
                shelves: ref.watch(shelvesProvider).valueOrNull ?? [],
                notes: ref.watch(notesByBookProvider(book.id)).valueOrNull ?? [],
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
                onEdit: () => _showRenameModal(context, ref, book),
                onMoveShelf: (sid) async {
                  await ref
                      .read(libraryControllerProvider.notifier)
                      .moveBook(book.id, sid ?? '');
                },
                onShowStatusModal: () => _showStatusModal(context, ref, book),
                onDeleteNote: (noteId) =>
                    _confirmDeleteNote(context, ref, noteId),
                onDeleteBook: () => _showDeleteModal(context, ref),
                onOpenReader: () =>
                    context.push('/book/${book.id}/reading'),
                onLock: () => _showLockSetupSheet(book),
              );
            },
          ),
        ),
      );
    }

    return EscapePopScope(
      onEscape: () => context.canPop() ? context.pop() : context.go('/home'),
      child: PopScope(
        // Back gesture exits selection mode first; only pops when not selecting.
        canPop: !_inSelectionMode,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _exitSelectionMode();
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: AppBottomNavBar(
            onTap: (tab) {
              if (tab == NavTab.library) context.go('/home');
              if (tab == NavTab.create) context.push('/book/new');
              if (tab == NavTab.profile) context.push('/profile');
            },
          ),
          // Figma 25:741 has no floating action button — entry to the reader
          // moves to the inline pencil next to the cover card.
          body: SafeArea(
            bottom: false,
            child: bookAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e', style: AppTypography.bodyMedium),
              ),
              data: (book) {
                if (book == null) {
                  return Center(
                    child: Text(
                      'Book not found',
                      style: AppTypography.bodyMedium,
                    ),
                  );
                }
                return _buildBody(context, ref, book);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, BookModel book) {
    final shelves = ref.watch(shelvesProvider).valueOrNull ?? [];

    return GestureDetector(
      // Tap outside the notes list (e.g. on the cover area) exits selection.
      behavior: HitTestBehavior.translucent,
      onTap: _inSelectionMode ? _exitSelectionMode : null,
      child: Column(
        children: [
          // ── Sticky top bar — swaps in selection mode (Figma 25:741) ────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: _inSelectionMode
                ? _buildSelectionTopBar()
                : _buildDefaultTopBar(book, shelves),
          ),

          // ── Scrollable body ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PDF cover card + inline read pencil. Constrained to ≤768px
                  // wide per Figma so wide web viewports stay tidy.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: _PdfDisplayArea(book: book),
                  ),

                  // ── Privacy — per-book PIN lock entry point ──────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: _PrivacyTile(
                      isLocked: book.isLocked,
                      onTap: () => _showLockSetupSheet(book),
                    ),
                  ),

                  // ── Annotated Insights — rounded-top muted sheet ─────────
                  _AnnotatedInsightsSheet(
                    book: book,
                    selectedNoteIds: _selectedNoteIds,
                    inSelectionMode: _inSelectionMode,
                    onToggleNote: _toggleNote,
                    onPruneSelection: _pruneSelection,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultTopBar(BookModel book, List<BookshelfModel> shelves) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/home'),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.arrow_back, color: AppColors.primary, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            book.title,
            style: AppTypography.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Builder(
          builder: (btnCtx) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final box = btnCtx.findRenderObject() as RenderBox?;
              final anchor = box != null
                  ? box.localToGlobal(Offset(box.size.width, 0))
                  : Offset.zero;
              _showOptionsMenu(context, ref, book, shelves, anchor);
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.more_vert, color: AppColors.primary, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionTopBar() {
    // Figma 25:796: two text buttons only — Cancel (left), Delete (right).
    // Same primary color; the destructive warning shows up only in the
    // confirm AppModal.
    final buttonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      foregroundColor: AppColors.primary,
      textStyle: AppTypography.labelButton.copyWith(
        color: AppColors.primary,
        fontSize: 16,
      ),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _exitSelectionMode,
          style: buttonStyle,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_selectedNoteIds.isEmpty) return;
            _confirmDeleteSelected();
          },
          style: buttonStyle,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// PDF Display Area — white card + inline pencil → reading screen.
// Figma: max-width 768, radius 8, shadow 0px 8px 32px rgba(25,28,29,0.08).
// ──────────────────────────────────────────────────────────────────────────

class _PdfDisplayArea extends ConsumerWidget {
  final BookModel book;
  const _PdfDisplayArea({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbAsync = book.link.isNotEmpty
        ? ref.watch(pdfThumbnailProvider(book.link))
        : const AsyncValue<Uint8List?>.data(null);

    // Figma 25:741: pencil button sits inside the cover card, vertically
    // centered, right-anchored with a 16px inset. Cover + pencil share a
    // Stack so the button overlaps the image.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 768),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        // rgba(25,28,29,0.08)
                        color: Color(0x14191C1D),
                        blurRadius: 32,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: thumbAsync.when(
                    loading: () => const _CoverPlaceholder(loading: true),
                    error: (e, s) => const _CoverPlaceholder(),
                    data: (bytes) => bytes != null
                        ? Image.memory(bytes, fit: BoxFit.cover)
                        : const _CoverPlaceholder(),
                  ),
                ),
              ),
              // 40x40 teal circle pencil → push reading screen.
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _InlineReadButton(
                    onTap: () => context.push('/book/${book.id}/reading'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineReadButton extends StatelessWidget {
  final VoidCallback onTap;
  const _InlineReadButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.5,
          ),
        ),
        elevation: 0,
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: borderRadius),
          onTap: onTap,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.edit_outlined, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Annotated Insights — rounded-top 40 sheet, surfaceMuted, padding 33/24/48.
// ──────────────────────────────────────────────────────────────────────────

class _AnnotatedInsightsSheet extends ConsumerWidget {
  final BookModel book;
  final Set<String> selectedNoteIds;
  final bool inSelectionMode;
  final void Function(String noteId) onToggleNote;
  final void Function(Set<String> validIds) onPruneSelection;

  const _AnnotatedInsightsSheet({
    required this.book,
    required this.selectedNoteIds,
    required this.inSelectionMode,
    required this.onToggleNote,
    required this.onPruneSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(bookUnlockSessionProvider);
    final notesLocked = book.isLocked && !session.isUnlocked(book.id);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 33, 24, 48 + 80 /* nav bar gap */),
      child: notesLocked
          ? _LockedNotesPlaceholder(bookId: book.id)
          : _NotesSection(
              bookId: book.id,
              selectedNoteIds: selectedNoteIds,
              inSelectionMode: inSelectionMode,
              onToggleNote: onToggleNote,
              onPruneSelection: onPruneSelection,
            ),
    );
  }
}

class _LockedNotesPlaceholder extends StatelessWidget {
  final String bookId;
  const _LockedNotesPlaceholder({required this.bookId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.lock, color: AppColors.primary, size: 40),
        const SizedBox(height: 12),
        Text('Notes are locked', style: AppTypography.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Unlock this book to view or add notes.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(
                '/book/$bookId/lock?redirect=${Uri.encodeComponent('/book/$bookId')}',
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Text('Unlock', style: AppTypography.labelButton),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Notes list. Selection state is owned by the parent BookInfoScreen so the
// top app bar can swap. Long-press toggles selection; tap toggles when in
// selection mode, otherwise opens the note editor.
// ──────────────────────────────────────────────────────────────────────────

class _NotesSection extends ConsumerWidget {
  final String bookId;
  final Set<String> selectedNoteIds;
  final bool inSelectionMode;
  final void Function(String noteId) onToggleNote;
  final void Function(Set<String> validIds) onPruneSelection;

  const _NotesSection({
    required this.bookId,
    required this.selectedNoteIds,
    required this.inSelectionMode,
    required this.onToggleNote,
    required this.onPruneSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesByBookProvider(bookId));
    return notesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e', style: AppTypography.bodySmall),
      data: (notes) {
        // Ask the parent to drop selections that no longer exist.
        onPruneSelection(notes.map((n) => n.id).toSet());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header row — heading + Add Note pill (Figma) ────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Annotated Insights (${notes.length})',
                    style: AppTypography.titleLarge.copyWith(
                      fontSize: 20,
                      letterSpacing: -1.0,
                      height: 1.4,
                    ),
                  ),
                ),
                if (!inSelectionMode)
                  _AddNotePill(
                    onTap: () => showNoteEditSheet(context, bookId: bookId),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (notes.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderHairline),
                ),
                child: Text(
                  'No notes yet. Tap "Add Note" to start writing.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...notes.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NotePreview(
                    note: n,
                    selected: selectedNoteIds.contains(n.id),
                    selectionMode: inSelectionMode,
                    onTap: () {
                      if (inSelectionMode) {
                        onToggleNote(n.id);
                      } else {
                        showNoteEditSheet(
                          context,
                          bookId: bookId,
                          noteId: n.id,
                        );
                      }
                    },
                    onLongPress: () => onToggleNote(n.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Add Note gradient pill — Figma button: pad 20h/14v, radius 12, gradient.
class _AddNotePill extends StatelessWidget {
  final VoidCallback onTap;
  const _AddNotePill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Add Note',
                  style: AppTypography.labelButton.copyWith(
                    fontSize: 14,
                    height: 1.0,
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

// ──────────────────────────────────────────────────────────────────────────
// Note card — Figma "Modal Note Card": white bg, 16 radius, 21 padding,
// soft shadow, hairline border, 3-line clamp body.
// ──────────────────────────────────────────────────────────────────────────

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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      // 0px 1px 1px rgba(0,0,0,0.05)
      shadowColor: Colors.black.withValues(alpha: 0.05),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.borderHairline,
                  width: selected ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(21),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.noteTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _formatDate(note.updatedAt),
                          style: AppTypography.captionRegular.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.8),
                  Text(
                    preview,
                    style: AppTypography.noteBody,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Selection indicator — Figma 25:796 places the circle at the
            // bottom-right of the card (left:310, top:102.2 inside 342x140.8).
            if (selectionMode)
              Positioned(
                right: 12,
                bottom: 18,
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textDisabled,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShelfPick extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _ShelfPick({
    required this.name,
    required this.selected,
    required this.onTap,
  });

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
            const Icon(
              Icons.folder_rounded,
              size: 20,
              color: AppColors.primary,
            ),
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

// ──────────────────────────────────────────────────────────────────────────
// Privacy tile — single settings-row that toggles between "Lock this book"
// and "Manage lock" based on the book's lock state. Matches the visual
// language of other tiles on this screen (white surface, primary icon,
// title + subtitle, trailing chevron).
// ──────────────────────────────────────────────────────────────────────────

class _PrivacyTile extends StatelessWidget {
  final bool isLocked;
  final VoidCallback onTap;

  const _PrivacyTile({required this.isLocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = isLocked ? 'Manage lock' : 'Lock this book';
    final subtitle = isLocked
        ? 'Change or remove PIN'
        : 'Require a PIN to open';
    final icon = isLocked ? Icons.lock : Icons.lock_outline;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.iconBlueTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.labelLarge),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
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
      color: AppColors.surface,
      child: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          : const Center(
              child: Icon(
                Icons.picture_as_pdf,
                size: 72,
                color: AppColors.primary,
              ),
            ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Desktop body — Figma "Full PDF Reader & Notes - Desktop" frame.
// 3-column row inside the shell: [back+title], [cover + edit + progress +
// settings card], [annotated insights list + Add Note + Delete buttons].
// All controllers / providers reused from the mobile path — only layout
// changes.
// ──────────────────────────────────────────────────────────────────────────

class _DesktopBookInfoBody extends ConsumerStatefulWidget {
  final BookModel book;
  final List<BookshelfModel> shelves;
  final List<NoteModel> notes;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final ValueChanged<String?> onMoveShelf;
  final VoidCallback onShowStatusModal;
  final ValueChanged<String> onDeleteNote;
  final VoidCallback onDeleteBook;
  final VoidCallback onOpenReader;
  final VoidCallback onLock;

  const _DesktopBookInfoBody({
    required this.book,
    required this.shelves,
    required this.notes,
    required this.onBack,
    required this.onEdit,
    required this.onMoveShelf,
    required this.onShowStatusModal,
    required this.onDeleteNote,
    required this.onDeleteBook,
    required this.onOpenReader,
    required this.onLock,
  });

  @override
  ConsumerState<_DesktopBookInfoBody> createState() =>
      _DesktopBookInfoBodyState();
}

class _DesktopBookInfoBodyState extends ConsumerState<_DesktopBookInfoBody> {
  /// `null` = list view, `''` = creating new, real id = editing existing.
  /// UI-local state (CLAUDE.md allows setState for non-shared UI flags).
  String? _editingNoteId;

  void _openEditor(String? noteId) {
    setState(() => _editingNoteId = noteId ?? '');
  }

  void _closeEditor() {
    if (_editingNoteId == null) return;
    setState(() => _editingNoteId = null);
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final shelves = widget.shelves;
    final notes = widget.notes;
    final thumbAsync = book.link.isNotEmpty
        ? ref.watch(pdfThumbnailProvider(book.link))
        : const AsyncValue<Uint8List?>.data(null);
    final progress = book.totalPages > 0
        ? (book.currentPage / book.totalPages).clamp(0.0, 1.0)
        : 0.0;
    final pct = (progress * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 24, 48, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar: back arrow only — title moves into the cover column below.
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Back',
                child: GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Center: cover + pencil/lock + form — scrolls as one body.
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title sits above the cover, centered within this column.
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Text(
                            book.title,
                            style: AppTypography.headlineMedium,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 360,
                            maxHeight: 480,
                          ),
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14191C1D),
                                    blurRadius: 32,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: thumbAsync.when(
                                loading: () => const _CoverPlaceholder(
                                  loading: true,
                                ),
                                error: (_, _) => const _CoverPlaceholder(),
                                data: (bytes) => bytes != null
                                    ? Image.memory(
                                        bytes,
                                        fit: BoxFit.cover,
                                      )
                                    : const _CoverPlaceholder(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Progress strip — bar + percent on one row.
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 3,
                                    backgroundColor:
                                        AppColors.progressTrack,
                                    valueColor:
                                        const AlwaysStoppedAnimation(
                                          AppColors.primary,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$pct%',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Settings card
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderHairline),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PDF LINK NAME',
                                style: AppTypography.sectionMeta,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  book.title,
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('SHELF', style: AppTypography.sectionMeta),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: book.shelfId.isEmpty
                                        ? null
                                        : book.shelfId,
                                    isExpanded: true,
                                    hint: Text(
                                      'No Shelf',
                                      style: AppTypography.bodyLarge,
                                    ),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(
                                          'No Shelf',
                                          style: AppTypography.bodyLarge,
                                        ),
                                      ),
                                      ...shelves.map(
                                        (s) => DropdownMenuItem<String?>(
                                          value: s.id,
                                          child: Text(
                                            s.name,
                                            style: AppTypography.bodyLarge,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: widget.onMoveShelf,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('STATUS', style: AppTypography.sectionMeta),
                              const SizedBox(height: 8),
                              Semantics(
                                button: true,
                                label: 'Change status',
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: widget.onShowStatusModal,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        StatusBadge(book.status),
                                        const Spacer(),
                                        const Icon(
                                          Icons.expand_more,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Semantics(
                                  button: true,
                                  label: 'Edit book name',
                                  child: GestureDetector(
                                    onTap: widget.onEdit,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Edit',
                                        style: AppTypography.labelButton
                                            .copyWith(
                                              fontSize: 14,
                                              height: 1.0,
                                            ),
                                      ),
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
                const SizedBox(width: 16),
                // Fixed action column between cover and notes — pencil
                // (open reader) + lock toggle. Doesn't scroll with the page.
                Padding(
                  padding: const EdgeInsets.only(top: 96),
                  child: Column(
                    children: [
                      _DesktopCircleAction(
                        icon: Icons.edit_outlined,
                        label: 'Open reader',
                        onTap: widget.onOpenReader,
                      ),
                      const SizedBox(height: 16),
                      _DesktopCircleAction(
                        icon: book.isLocked
                            ? Icons.lock
                            : Icons.lock_open_outlined,
                        label: book.isLocked
                            ? 'Manage lock'
                            : 'Set up lock',
                        onTap: widget.onLock,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right: notes side panel — fixed beside the scrolling
                // center column. Branches between list mode and inline
                // editor mode based on _editingNoteId.
                SizedBox(
                  width: 320,
                  child: _editingNoteId == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Annotated Insights (${notes.length})',
                              style: AppTypography.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: notes.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.borderHairline,
                                        ),
                                      ),
                                      child: Text(
                                        'No notes yet. Tap "Add Note" to start.',
                                        style: AppTypography.bodyMedium,
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: notes.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (ctx, i) => _DesktopNoteCard(
                                        note: notes[i],
                                        onTap: () => _openEditor(notes[i].id),
                                        onMenuSelected: (action) {
                                          if (action == 'edit') {
                                            _openEditor(notes[i].id);
                                          } else if (action == 'delete') {
                                            widget.onDeleteNote(notes[i].id);
                                          }
                                        },
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            _DesktopActionButton(
                              label: 'Add Note',
                              icon: Icons.add_comment_outlined,
                              color: AppColors.primary,
                              onTap: () => _openEditor(null),
                            ),
                            const SizedBox(height: 8),
                            _DesktopActionButton(
                              label: 'Delete PDF',
                              icon: Icons.delete_outline,
                              color: AppColors.primary,
                              onTap: widget.onDeleteBook,
                            ),
                          ],
                        )
                      : DesktopNoteEditorPanel(
                          // Re-key on id swap so init reloads controllers
                          // when the user taps a different card while the
                          // editor is already open.
                          key: ValueKey(_editingNoteId ?? 'new'),
                          bookId: book.id,
                          noteId: _editingNoteId!.isEmpty
                              ? null
                              : _editingNoteId,
                          onClose: _closeEditor,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopNoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final ValueChanged<String>? onMenuSelected;
  const _DesktopNoteCard({
    required this.note,
    required this.onTap,
    this.onMenuSelected,
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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderHairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(note.updatedAt),
                    style: AppTypography.captionRegular.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0,
                    ),
                  ),
                  if (onMenuSelected != null)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: PopupMenuButton<String>(
                        tooltip: 'Note options',
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        color: AppColors.surface,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onSelected: (v) => onMenuSelected!.call(v),
                        itemBuilder: (_) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            height: 44,
                            child: Text(
                              'Edit',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            height: 44,
                            child: Text(
                              'Delete',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
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
      ),
    );
  }
}

class _DesktopCircleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DesktopCircleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x29191C1D),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.surface, size: 20),
          ),
        ),
      ),
    );
  }
}

class _DesktopActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _DesktopActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelButton.copyWith(
                  fontSize: 14,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
