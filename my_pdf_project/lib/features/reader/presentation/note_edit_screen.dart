import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../library/presentation/library_controller.dart';
import '../../library/presentation/library_providers.dart';

class NoteEditScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String? noteId;
  const NoteEditScreen({super.key, required this.bookId, this.noteId});

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
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
    // Load existing note content once.
    Future.microtask(() async {
      final note = await ref.read(noteByIdProvider(widget.noteId!).future);
      if (!mounted) return;
      _ctrl.text = note?.content ?? '';
      setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _ctrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note cannot be empty.')),
      );
      return;
    }
    setState(() => _saving = true);
    final ctrl = ref.read(libraryControllerProvider.notifier);
    bool ok;
    if (_isNew) {
      final created = await ctrl.createNote(bookId: widget.bookId, content: content);
      ok = created != null;
    } else {
      ok = await ctrl.updateNoteContent(widget.noteId!, content);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      // Drop cached note so re-opening this edit screen shows fresh content.
      if (!_isNew) ref.invalidate(noteByIdProvider(widget.noteId!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/book/${widget.bookId}/note');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save note')),
      );
    }
  }

  Future<void> _delete() async {
    if (_isNew) return;
    final ok = await ref
        .read(libraryControllerProvider.notifier)
        .deleteNote(widget.noteId!);
    if (!mounted) return;
    if (ok) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/book/${widget.bookId}/note');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookByIdProvider(widget.bookId));
    final book = bookAsync.valueOrNull;

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/book/${widget.bookId}/note'),
                      child: Text('Cancel',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.primary)),
                    ),
                    const Spacer(),
                    if (!_isNew)
                      TextButton(
                        onPressed: _delete,
                        child: Text('Delete',
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.error)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              margin: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            book?.title ?? 'Note',
                            style: AppTypography.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        controller: _ctrl,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: AppTypography.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Start writing your note...',
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
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      MediaQuery.of(context).padding.bottom + 24,
                    ),
                    child: GradientButton(
                      label: _isNew ? 'Create Note' : 'Save Note',
                      loading: _saving,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
