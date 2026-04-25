import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../library/domain/note_model.dart';
import '../../library/presentation/library_controller.dart';
import '../../library/presentation/library_providers.dart';

const int kNotePreviewMaxChars = 140;

class NoteScreen extends ConsumerWidget {
  final String bookId;
  const NoteScreen({super.key, required this.bookId});

  void _confirmDelete(BuildContext context, WidgetRef ref, NoteModel note) {
    showAppModal(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Delete Notes',
        confirmLabel: 'Delete',
        confirmDestructive: true,
        body: Text(
          'Are you sure you want to delete the notes? Once you delete the notes, they cannot be recovered.',
          style: AppTypography.bodyMedium,
        ),
        onConfirm: () async {
          await ref.read(libraryControllerProvider.notifier).deleteNote(note.id);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookByIdProvider(bookId));
    final notesAsync = ref.watch(notesByBookProvider(bookId));
    final book = bookAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNavBar(
        
        onTap: (tab) {
          if (tab == NavTab.library) context.go('/home');
          if (tab == NavTab.create) context.push('/book/new');
          if (tab == NavTab.profile) context.push('/profile');
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/book/$bookId/note/edit'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_comment_outlined, color: Colors.white, size: 18),
        label: Text(
          'Add Note',
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/book/$bookId'),
                      child: const Icon(Icons.arrow_back,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        book?.title ?? 'Notes',
                        style: AppTypography.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Error: $e', style: AppTypography.bodyMedium)),
              data: (notes) {
                if (notes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_note,
                              size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'No notes yet. Tap "Add Note" to start.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final note = notes[i];
                    return _NoteCard(
                      note: note,
                      onTap: () => context.push(
                          '/book/$bookId/note/edit?id=${note.id}'),
                      onDelete: () => _confirmDelete(context, ref, note),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final preview = note.content.trim().isEmpty
        ? '(empty note)'
        : note.content.trim();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview,
                      style: AppTypography.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(note.updatedAt),
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
