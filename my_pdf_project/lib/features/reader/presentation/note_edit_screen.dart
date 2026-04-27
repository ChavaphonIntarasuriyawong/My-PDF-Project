import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../library/presentation/library_controller.dart';
import '../../library/presentation/library_providers.dart';

/// Open the note editor as a bottom sheet that rises from the bottom of the
/// screen. Pass [noteId] to edit an existing note; omit it to create a new one.
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.92,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note cannot be empty.')),
      );
      return;
    }
    // Auto-name new untitled notes as "Note (N)" — N = highest existing
    // numbered index + 1, so deletes don't cause clashes.
    if (_isNew && title.isEmpty) {
      final existing = ref.read(notesByBookProvider(widget.bookId)).valueOrNull ?? [];
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
          bookId: widget.bookId, title: title, content: content);
      ok = created != null;
    } else {
      ok = await ctrl.updateNote(widget.noteId!, title: title, content: content);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      if (!_isNew) ref.invalidate(noteByIdProvider(widget.noteId!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save note')),
      );
    }
  }

  /// X = always close/discard (no destructive action).
  void _onClose() {
    Navigator.of(context).pop();
  }

  /// Trash icon — only visible for existing notes. Asks for confirmation.
  void _onDelete() {
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
              .deleteNote(widget.noteId!);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (!mounted) return;
          if (ok) Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookByIdProvider(widget.bookId));
    final book = bookAsync.valueOrNull;
    final thumbAsync = (book != null && book.link.isNotEmpty)
        ? ref.watch(pdfThumbnailProvider(book.link))
        : const AsyncValue<Uint8List?>.data(null);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        color: AppColors.background,
        child: !_initialized
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Drag handle — visual cue this is a draggable sheet.
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // ── Top bar: X (delete) · book title · Done ─────────
                  Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _onClose,
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.close,
                                color: AppColors.primary, size: 22),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            book?.title ?? 'Note',
                            style: AppTypography.titleMedium
                                .copyWith(color: AppColors.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_isNew) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _onDelete,
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.delete_outline,
                                  color: AppColors.error, size: 22),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: _saving ? null : _save,
                          child: Text(
                            'Done',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Body ──────────────────────────────────────────
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 180,
                              width: double.infinity,
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
                                    ? Image.memory(bytes, fit: BoxFit.cover)
                                    : Container(color: AppColors.surfaceMuted),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                          child: TextField(
                            controller: _titleCtrl,
                            style: AppTypography.titleMedium,
                            decoration: InputDecoration(
                              hintText: 'Title of this thought…',
                              hintStyle: AppTypography.titleMedium
                                  .copyWith(color: AppColors.textMuted),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: TextField(
                              controller: _ctrl,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: AppTypography.bodyMedium
                                  .copyWith(color: AppColors.textSecondary),
                              decoration: InputDecoration(
                                hintText: 'Synthesize your insights here…',
                                hintStyle: AppTypography.bodyMedium
                                    .copyWith(color: AppColors.textMuted),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: GradientButton(
                            label: 'Save Note',
                            icon: Icons.save_outlined,
                            loading: _saving,
                            onPressed: _save,
                          ),
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
