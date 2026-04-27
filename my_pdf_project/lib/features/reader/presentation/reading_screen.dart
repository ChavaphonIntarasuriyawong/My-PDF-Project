import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../../../core/network/pdf_fetcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../library/presentation/library_controller.dart';
import '../../library/presentation/library_providers.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  final String bookId;
  const ReadingScreen({super.key, required this.bookId});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  int _currentPage = 0;
  int _totalPages = 0;

  PDFViewController? _pdfController;
  bool _jumpedToSavedPage = false;

  void _onPageChanged(int? page, int? total) {
    if (page == null || total == null || page < 0) return;
    setState(() {
      _currentPage = page + 1;
      _totalPages = total;
    });
    final ctrl = ref.read(libraryControllerProvider.notifier);
    ctrl.updateProgress(
      bookId: widget.bookId,
      currentPage: page + 1,
      totalPages: total,
    );
    // Auto-mark finished when reader hits the last page (0-indexed: page == total-1).
    // Skip if already finished to avoid redundant writes.
    if (page + 1 >= total && total > 0) {
      final book = ref.read(bookByIdProvider(widget.bookId)).valueOrNull;
      if (book != null && book.status != 'finished') {
        ctrl.updateStatus(widget.bookId, 'finished');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookByIdProvider(widget.bookId));
    final book = bookAsync.valueOrNull;
    final pdfAsync = book != null ? ref.watch(pdfPathProvider(book.link)) : null;

    final progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFD8DADB),
      body: Stack(
        children: [
          // PDFView/loading must fill the stack — without Positioned.fill some
          // platform-view embeds collapse to 0x0 and render a blank surface.
          if (pdfAsync != null)
            Positioned.fill(
              child: pdfAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Failed to load PDF', style: AppTypography.bodyMedium),
                      const SizedBox(height: 8),
                      Text('$e',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                data: (path) => kIsWeb
                    ? _WebPdfReader(
                        key: ValueKey(path),
                        url: path,
                        initialPage: book?.currentPage ?? 0,
                        onPagesAndPageChanged: (page, total) =>
                            _onPageChanged(page, total),
                      )
                    : PDFView(
                  key: ValueKey(path),
                  filePath: path,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: false,
                  pageFling: false,
                  pageSnap: false,
                  fitPolicy: FitPolicy.WIDTH,
                  onRender: (pages) {
                    if (pages != null) setState(() => _totalPages = pages);
                    if (!_jumpedToSavedPage) {
                      _jumpedToSavedPage = true;
                      final savedPage = book?.currentPage ?? 0;
                      if (savedPage > 1 && _pdfController != null) {
                        _pdfController!.setPage(savedPage - 1);
                      }
                      if (savedPage > 0 && _currentPage == 0) {
                        setState(() => _currentPage = savedPage);
                      }
                    }
                  },
                  onError: (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF render error: $e')),
                      );
                    }
                  },
                  onPageError: (page, e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Page $page error: $e')),
                      );
                    }
                  },
                  onViewCreated: (controller) {
                    _pdfController = controller;
                  },
                  onPageChanged: _onPageChanged,
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Top bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: const Color(0xCCF8FAFB),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.canPop()
                                    ? context.pop()
                                    : context.go('/book/${widget.bookId}'),
                                child: const Icon(Icons.arrow_back,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  book?.title ?? '',
                                  style: AppTypography.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: AppColors.progressTrack,
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.primary),
                          minHeight: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_totalPages > 0)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xCCF8FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0x33BFC8CC),
                        ),
                      ),
                      child: Text(
                        'Page $_currentPage of $_totalPages',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WebPdfReader extends StatefulWidget {
  final String url;
  final int initialPage;
  final void Function(int page, int total) onPagesAndPageChanged;

  const _WebPdfReader({
    super.key,
    required this.url,
    required this.initialPage,
    required this.onPagesAndPageChanged,
  });

  @override
  State<_WebPdfReader> createState() => _WebPdfReaderState();
}

class _WebPdfReaderState extends State<_WebPdfReader> {
  pdfx.PdfDocument? _document;
  String? _error;
  int _totalPages = 0;
  double _aspectRatio = 1 / 1.4142; // A4 fallback until first page measured.
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  double _itemHeight = 0;
  bool _jumpedToInitialPage = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await fetchPdfBytes(widget.url);
      final doc = await pdfx.PdfDocument.openData(response.bodyBytes);
      // Use first page's aspect ratio for all items — book pages are usually uniform.
      final firstPage = await doc.getPage(1);
      final ratio = firstPage.width / firstPage.height;
      await firstPage.close();
      if (!mounted) return;
      setState(() {
        _document = doc;
        _totalPages = doc.pagesCount;
        _aspectRatio = ratio;
      });
      widget.onPagesAndPageChanged(0, _totalPages);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onScroll() {
    if (_itemHeight == 0 || _totalPages == 0) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Use viewport CENTER, not top, so the page filling most of the screen
    // wins. Top-only tracking under-reports the last page when viewport
    // height > item height (multiple pages visible at once).
    final centerOffset = pos.pixels + pos.viewportDimension / 2;
    int page = (centerOffset / _itemHeight).floor() + 1;
    // Snap to last page when scrolled to the very bottom — handles cases
    // where the final page doesn't quite cross the viewport center.
    if ((pos.maxScrollExtent - pos.pixels).abs() < 2) {
      page = _totalPages;
    }
    final clamped = page.clamp(1, _totalPages);
    if (clamped != _currentPage) {
      _currentPage = clamped;
      widget.onPagesAndPageChanged(clamped - 1, _totalPages);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _document?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load PDF: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_document == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (ctx, constraints) {
        const verticalPadding = 8.0;
        _itemHeight = constraints.maxWidth / _aspectRatio + verticalPadding * 2;

        if (!_jumpedToInitialPage && widget.initialPage > 1 && _totalPages > 0) {
          _jumpedToInitialPage = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController
                  .jumpTo(_itemHeight * (widget.initialPage - 1));
            }
          });
        }

        return ScrollConfiguration(
          // Web default disables mouse drag-to-scroll — re-enable it explicitly.
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _totalPages,
            itemExtent: _itemHeight,
            itemBuilder: (ctx, i) => _PdfPageImage(
              document: _document!,
              pageNumber: i + 1,
            ),
          ),
        );
      },
    );
  }
}

class _PdfPageImage extends StatefulWidget {
  final pdfx.PdfDocument document;
  final int pageNumber;

  const _PdfPageImage({required this.document, required this.pageNumber});

  @override
  State<_PdfPageImage> createState() => _PdfPageImageState();
}

class _PdfPageImageState extends State<_PdfPageImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    try {
      final page = await widget.document.getPage(widget.pageNumber);
      // 2x density for crisp text on retina-class displays.
      final image = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: pdfx.PdfPageImageFormat.jpeg,
      );
      await page.close();
      if (!mounted) return;
      setState(() => _bytes = image?.bytes);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _bytes != null
          ? Image.memory(_bytes!, fit: BoxFit.contain)
          : _failed
              ? const Center(child: Icon(Icons.broken_image, color: Colors.grey))
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
