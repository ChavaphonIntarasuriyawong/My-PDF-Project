import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../features/library/domain/book_model.dart';
import '../../features/library/presentation/library_providers.dart';
import 'status_badge.dart';

class PdfCard extends ConsumerWidget {
  final BookModel book;
  final VoidCallback? onTap;

  const PdfCard({super.key, required this.book, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbAsync = book.link.isNotEmpty
        ? ref.watch(pdfThumbnailProvider(book.link))
        : const AsyncValue<Object?>.data(null);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      child: thumbAsync.when(
                        loading: () => const _CoverPlaceholder(showSpinner: true),
                        error: (e, s) => const _CoverPlaceholder(),
                        data: (bytes) => bytes != null
                            ? Image.memory(
                                bytes as dynamic,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (ctx, e, s) =>
                                    const _CoverPlaceholder(),
                              )
                            : const _CoverPlaceholder(),
                      ),
                    ),
                  ),
                  // PDF badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        color: const Color(0xB3E1E3E4),
                        child: Text(
                          'PDF',
                          style: AppTypography.captionBold.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 9.6,
                            letterSpacing: -0.48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                book.title,
                style: AppTypography.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  const Spacer(),
                  StatusBadge(book.status),
                ],
              ),
            ),
            // Progress
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PAGE ${book.currentPage} OF ${book.totalPages}'
                            .toUpperCase(),
                        style: AppTypography.captionRegular,
                      ),
                      Text(
                        '${book.progress.toStringAsFixed(0)}%',
                        style: AppTypography.captionBold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: book.totalPages > 0
                          ? book.currentPage / book.totalPages
                          : 0,
                      backgroundColor: AppColors.progressTrack,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 4,
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

class _CoverPlaceholder extends StatelessWidget {
  final bool showSpinner;
  const _CoverPlaceholder({this.showSpinner = false});

  @override
  Widget build(BuildContext context) {
    if (showSpinner) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return const SizedBox.expand();
  }
}
