import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/book_model.dart';
import '../domain/bookshelf_model.dart';
import 'library_controller.dart';
import 'library_providers.dart';

class NewBookScreen extends ConsumerStatefulWidget {
  const NewBookScreen({super.key});

  @override
  ConsumerState<NewBookScreen> createState() => _NewBookScreenState();
}

class _NewBookScreenState extends ConsumerState<NewBookScreen> {
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  String? _selectedShelfId;
  bool _loading = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_urlCtrl.text.trim().isEmpty || _titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final book = BookModel(
      id: '',
      title: _titleCtrl.text.trim(),
      link: _urlCtrl.text.trim(),
      totalPages: 0,
      currentPage: 0,
      progress: 0,
      status: 'reading',
      shelfId: _selectedShelfId ?? '',
      ownerId: uid,
    );
    final created = await ref.read(libraryControllerProvider.notifier).createBook(book);
    if (mounted) {
      setState(() => _loading = false);
      if (created != null) context.go('/book/${created.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shelves = ref.watch(shelvesProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNavBar(
        active: NavTab.create,
        onTap: (tab) {
          if (tab == NavTab.library) context.go('/home');
          if (tab == NavTab.profile) context.push('/profile');
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Text('Add PDF Link', style: AppTypography.titleLarge),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Save a PDF to\nyour library',
                        style: AppTypography.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Paste a PDF link below to start tracking your reading.',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),

                    // ── PDF Link — primary field ──────────────────────────
                    Text(
                      'PDF LINK',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(
                              Icons.link,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _urlCtrl,
                              keyboardType: TextInputType.url,
                              style: AppTypography.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'https://example.com/book.pdf',
                                hintStyle: AppTypography.bodyMedium
                                    .copyWith(color: AppColors.textMuted),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Book title ────────────────────────────────────────
                    LabeledTextField(
                      label: 'Book Title',
                      hint: 'e.g. Thinking Fast and Slow',
                      controller: _titleCtrl,
                    ),
                    const SizedBox(height: 24),

                    // ── Shelf ─────────────────────────────────────────────
                    _ShelfDropdown(
                      shelves: shelves,
                      value: _selectedShelfId,
                      onChanged: (v) => setState(() => _selectedShelfId = v),
                    ),
                    const SizedBox(height: 48),

                    GradientButton(
                      label: 'Add to Library',
                      loading: _loading,
                      onPressed: _create,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfDropdown extends StatelessWidget {
  final List<BookshelfModel> shelves;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _ShelfDropdown({
    required this.shelves,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SHELF',
          style: AppTypography.labelSmall
              .copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: value,
              isExpanded: true,
              style: AppTypography.bodyMedium,
              dropdownColor: AppColors.surface,
              hint: Text(
                'None (Unshelved)',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None (Unshelved)',
                      style: AppTypography.bodyMedium),
                ),
                ...shelves.map((s) => DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(s.name, style: AppTypography.bodyMedium),
                    )),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
