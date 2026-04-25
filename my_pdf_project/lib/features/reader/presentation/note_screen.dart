import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../library/presentation/library_controller.dart';
import '../../library/presentation/library_providers.dart';

class NoteScreen extends ConsumerStatefulWidget {
  final String bookId;
  const NoteScreen({super.key, required this.bookId});

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  final _noteCtrl = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(libraryControllerProvider.notifier).saveNote(
      bookId: widget.bookId,
      content: _noteCtrl.text,
    );
    ref.invalidate(noteByBookProvider(widget.bookId));
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookByIdProvider(widget.bookId));
    final noteAsync = ref.watch(noteByBookProvider(widget.bookId));

    // Initialize controller once note loads
    if (!_initialized && noteAsync.hasValue) {
      _noteCtrl.text = noteAsync.valueOrNull?.content ?? '';
      _initialized = true;
    }

    final book = bookAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNavBar(
        active: NavTab.library,
        onTap: (tab) {
          if (tab == NavTab.library) context.go('/home');
          if (tab == NavTab.create) context.push('/book/new');
          if (tab == NavTab.profile) context.push('/profile');
        },
      ),
      body: Column(
        children: [
          // Book header (top section, ~309px equivalent)
          Container(
            color: AppColors.surface,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: const Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Text('Notes', style: AppTypography.titleLarge),
                      ],
                    ),
                  ),
                  if (book != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: book.coverUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      book.coverUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, st) =>
                                          const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 28),
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  style: AppTypography.titleMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Page ${book.currentPage} of ${book.totalPages}',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Note editor (bottom card)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              margin: const EdgeInsets.only(top: 8),
              child: noteAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_note, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text('My Notes', style: AppTypography.titleMedium),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: TextField(
                              controller: _noteCtrl,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: AppTypography.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'Start writing your notes here...',
                                hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
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
                            label: 'Save Note',
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
