import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/layout/responsive.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../library/presentation/library_controller.dart';
import '../../library/presentation/library_providers.dart';

/// Open the note editor as a near-fullscreen bottom sheet.
/// Pass [noteId] to edit; omit it to create a new note.
///
/// The visual is Figma 25:847 ("Create/Edit Note - PDF Reader"): faded PDF
/// preview on top, rounded-top white note sheet overlapping it, gradient
/// "Save Note" CTA, and the bottom nav bar.
Future<void> showNoteEditSheet(
  BuildContext context, {
  required String bookId,
  String? noteId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.96,
        child: NoteEditSheet(bookId: bookId, noteId: noteId),
      ),
    ),
  );
}

class NoteEditSheet extends ConsumerStatefulWidget {
  final String bookId;
  final String? noteId;
  const NoteEditSheet({super.key, required this.bookId, this.noteId});

  @override
  ConsumerState<NoteEditSheet> createState() => _NoteEditSheetState();
}

class _NoteEditSheetState extends ConsumerState<NoteEditSheet> {
  final _titleCtrl = TextEditingController();
  final _ctrl = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  bool get _isNew => widget.noteId == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _initialized = true;
      return;
    }
    Future.microtask(() async {
      final note = await ref.read(noteByIdProvider(widget.noteId!).future);
      if (!mounted) return;
      _titleCtrl.text = note?.title ?? '';
      _ctrl.text = note?.content ?? '';
      setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    var title = _titleCtrl.text.trim();
    final content = _ctrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note cannot be empty.')));
      return;
    }
    // Auto-name new untitled notes as "Note (N)" — N = highest existing
    // numbered index + 1, so deletes don't cause clashes.
    if (_isNew && title.isEmpty) {
      final existing =
          ref.read(notesByBookProvider(widget.bookId)).valueOrNull ?? [];
      final pattern = RegExp(r'^Note \((\d+)\)$');
      var maxN = 0;
      for (final n in existing) {
        final m = pattern.firstMatch(n.title.trim());
        if (m != null) {
          final num = int.tryParse(m.group(1)!) ?? 0;
          if (num > maxN) maxN = num;
        }
      }
      title = 'Note (${maxN + 1})';
    }
    setState(() => _saving = true);
    final ctrl = ref.read(libraryControllerProvider.notifier);
    bool ok;
    if (_isNew) {
      final created = await ctrl.createNote(
        bookId: widget.bookId,
        title: title,
        content: content,
      );
      ok = created != null;
    } else {
      ok = await ctrl.updateNote(
        widget.noteId!,
        title: title,
        content: content,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      if (!_isNew) ref.invalidate(noteByIdProvider(widget.noteId!));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note saved')));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save note')));
    }
  }

  /// X = close/discard.
  void _onClose() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookByIdProvider(widget.bookId));
    final book = bookAsync.valueOrNull;
    final thumbAsync = (book != null && book.link.isNotEmpty)
        ? ref.watch(pdfThumbnailProvider(book.link))
        : const AsyncValue<Uint8List?>.data(null);

    final progress = (book != null && book.totalPages > 0)
        ? (book.currentPage / book.totalPages).clamp(0.0, 1.0)
        : 0.0;

    final desktop = kIsWeb && isDesktop(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Material(
        color: AppColors.background,
        child: !_initialized
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: desktop ? 720 : 9999),
                  child: Column(
                children: [
                  // ── Sticky top bar — Figma 25:847 ────────────────────
                  // Delete UX is now multi-select on the book info screen,
                  // so the editor only carries Close + Done.
                  _NoteEditTopBar(
                    bookTitle: book?.title ?? 'Note',
                    onClose: _onClose,
                    onDone: _saving ? null : _save,
                  ),

                  // ── Body: PDF preview + overlapping note sheet ──────
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            // PDF viewer section (309px tall).
                            _PdfPreviewSection(
                              thumbAsync: thumbAsync,
                              progress: progress,
                            ),
                            // White note sheet fills remaining space and
                            // overlaps the PDF section by -24px (margin).
                            Expanded(
                              child: Transform.translate(
                                offset: const Offset(0, -24),
                                child: _NoteSheet(
                                  titleCtrl: _titleCtrl,
                                  bodyCtrl: _ctrl,
                                  saving: _saving,
                                  onSave: _save,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Bottom nav — visible per Figma ──────────────────
                  if (!desktop)
                    AppBottomNavBar(
                      onTap: (tab) {
                        // Pop the sheet first so navigation lands on the
                        // root navigator, not stacked under it.
                        Navigator.of(context).pop();
                        if (tab == NavTab.library) context.go('/home');
                        if (tab == NavTab.create) context.push('/book/new');
                        if (tab == NavTab.profile) context.push('/profile');
                      },
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
// Top app bar — X close · book title · Done.
// Height 64, padding 12h/8v, primary color icons. Delete moved to the
// multi-select UX on the book info screen.
// ──────────────────────────────────────────────────────────────────────────

class _NoteEditTopBar extends StatelessWidget {
  final String bookTitle;
  final VoidCallback onClose;
  final VoidCallback? onDone;

  const _NoteEditTopBar({
    required this.bookTitle,
    required this.onClose,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close, color: AppColors.primary, size: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bookTitle,
              style: AppTypography.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onDone,
            child: Text(
              'Done',
              style: AppTypography.labelButton.copyWith(
                color: AppColors.primary,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// PDF Viewer Section — 309px tall, surfaceMuted bg, white inner card with
// faded thumbnail + 3 skeleton bars + 4px progress bar at the bottom.
// ──────────────────────────────────────────────────────────────────────────

class _PdfPreviewSection extends StatelessWidget {
  final AsyncValue<Uint8List?> thumbAsync;
  final double progress;

  const _PdfPreviewSection({required this.thumbAsync, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 309,
      child: Stack(
        children: [
          // Section bg.
          Positioned.fill(child: Container(color: AppColors.surfaceMuted)),
          // Inner white card with the faded preview, inset 24.
          Positioned(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + 4 /* leave room for the progress bar */,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  // 0px 1px 2px rgba(0,0,0,0.05)
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Faded thumbnail at 90% opacity.
                  Expanded(
                    child: Opacity(
                      opacity: 0.9,
                      child: thumbAsync.when(
                        loading: () => Container(
                          color: AppColors.surfaceMuted,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        error: (e, s) =>
                            Container(color: AppColors.surfaceMuted),
                        data: (bytes) => bytes != null
                            ? Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : Container(color: AppColors.surfaceMuted),
                      ),
                    ),
                  ),
                  // Three decorative skeleton lines per Figma.
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBar(width: 207),
                        SizedBox(height: 8),
                        _SkeletonBar(width: double.infinity),
                        SizedBox(height: 8),
                        _SkeletonBar(width: 230),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 4px progress bar pinned to the section bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.progressTrack,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  final double width;
  const _SkeletonBar({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.surfaceSkeleton,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Note sheet — white, rounded-top 32, upward shadow, padding 40/24/60.5,
// title (Manrope Bold 20), multiline body (Inter Reg 16, lh 26), gradient
// "Save Note" button.
// ──────────────────────────────────────────────────────────────────────────

class _NoteSheet extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final bool saving;
  final VoidCallback onSave;

  const _NoteSheet({
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          // 0px -8px 12px rgba(25,28,29,0.04)
          BoxShadow(
            color: Color(0x0A191C1D),
            blurRadius: 12,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title input — chrome-free per Figma. No box, no underline, no fill.
          TextField(
            controller: titleCtrl,
            cursorColor: AppColors.primary,
            style: AppTypography.titleLarge.copyWith(
              fontSize: 20,
              letterSpacing: 0,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Title of this thought…',
              hintStyle: AppTypography.titleLarge.copyWith(
                fontSize: 20,
                letterSpacing: 0,
                height: 1.4,
                color: AppColors.textDisabled,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              fillColor: Colors.transparent,
            ),
          ),
          const SizedBox(height: 16),
          // Body textarea grows to fill remaining space — chrome-free per Figma.
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 200),
              child: TextField(
                controller: bodyCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                cursorColor: AppColors.primary,
                style: AppTypography.noteBody.copyWith(
                  fontSize: 16,
                  height: 26 / 16, // 1.625 line-height per Figma
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Synthesize your insights here…',
                  hintStyle: AppTypography.noteBody.copyWith(
                    fontSize: 16,
                    height: 26 / 16,
                    // rgba(191,200,204,0.6)
                    color: AppColors.textDisabled.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Gradient Save button.
          GradientButton(
            label: 'Save Note',
            icon: Icons.save_outlined,
            loading: saving,
            onPressed: onSave,
            borderRadius: 8,
          ),
        ],
      ),
    );
  }
}
