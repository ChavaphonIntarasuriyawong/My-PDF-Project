import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../features/library/presentation/library_controller.dart';
import '../../features/library/presentation/library_providers.dart';
import 'gradient_button.dart';

/// Inline note editor used by the desktop right-side panel on both Book Info
/// and Reading screens. Lives in the same 320px slot as the notes list — the
/// parent toggles between list and this editor via local UI state. Mirrors
/// the save / auto-name behavior of `NoteEditSheet` but with no modal chrome.
///
/// API:
/// - [bookId]   : owning book id (required to create new notes).
/// - [noteId]   : `null` to create a fresh note; non-null to edit existing.
/// - [onClose]  : called by both the X header button and after a successful
///                save. Parent is responsible for swapping the slot back.
class DesktopNoteEditorPanel extends ConsumerStatefulWidget {
  final String bookId;

  /// `null` = create new; non-null = edit existing.
  final String? noteId;
  final VoidCallback onClose;

  const DesktopNoteEditorPanel({
    super.key,
    required this.bookId,
    required this.noteId,
    required this.onClose,
  });

  @override
  ConsumerState<DesktopNoteEditorPanel> createState() =>
      _DesktopNoteEditorPanelState();
}

class _DesktopNoteEditorPanelState
    extends ConsumerState<DesktopNoteEditorPanel> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
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
      _bodyCtrl.text = note?.content ?? '';
      setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    var title = _titleCtrl.text.trim();
    final content = _bodyCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note cannot be empty.')));
      return;
    }
    // Auto-name new untitled notes as "Note (N)" — N = highest existing
    // numbered index + 1 (mirrors NoteEditSheet._save).
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
      widget.onClose();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save note')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderHairline),
      ),
      padding: const EdgeInsets.all(20),
      child: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header row — heading + close (X) ─────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isNew ? 'New Note' : 'Edit Note',
                        style: AppTypography.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Close editor',
                      child: IconButton(
                        tooltip: 'Close',
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: widget.onClose,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Title field — chrome-free per Figma _NoteSheet ──────
                TextField(
                  controller: _titleCtrl,
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
                const SizedBox(height: 12),
                // ── Body textarea — fills remaining vertical space ──────
                Expanded(
                  child: TextField(
                    controller: _bodyCtrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    cursorColor: AppColors.primary,
                    style: AppTypography.noteBody.copyWith(
                      fontSize: 16,
                      height: 26 / 16,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Synthesize your insights here…',
                      hintStyle: AppTypography.noteBody.copyWith(
                        fontSize: 16,
                        height: 26 / 16,
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
                const SizedBox(height: 16),
                // ── Footer — gradient Save Note button ──────────────────
                Semantics(
                  button: true,
                  label: 'Save note',
                  child: GradientButton(
                    label: 'Save Note',
                    icon: Icons.save_outlined,
                    loading: _saving,
                    onPressed: _save,
                    borderRadius: 8,
                  ),
                ),
              ],
            ),
    );
  }
}
