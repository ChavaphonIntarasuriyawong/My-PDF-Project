import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdf_text/flutter_pdf_text.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
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

  final FlutterTts _tts = FlutterTts();
  bool _ttsActive = false;
  bool _ttsSpeaking = false;
  String? _pdfPath;
  PDFDoc? _pdfDoc; // cached so we don't reload on every page (mobile only)
  Uint8List? _webPdfBytes; // cached fetched bytes on web for Syncfusion text extractor
  final WebPdfReaderController _webController = WebPdfReaderController();

  // Web uses the W3C SpeechSynthesis scale where 1.0 is "normal speed".
  // Mobile (Android/iOS) uses 0.5 as the natural default — anything higher
  // sounds rushed.
  double _speechRate = kIsWeb ? 1.0 : 0.5;
  double _pitch = 1.0;

  // Cancellation: incremented each time a new speak starts;
  // stale async work checks version before proceeding.
  int _speakVersion = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    // setLanguage returns -1 (NOT_SUPPORTED) or -2 (MISSING_DATA) on devices
    // without English TTS pack — fall back to device default in that case.
    final langResult = await _tts.setLanguage('en-US');
    if (langResult is int && langResult < 0) {
      final langs = await _tts.getLanguages;
      final list = langs as List?;
      if (list != null && list.isNotEmpty) {
        await _tts.setLanguage(list.first.toString());
      }
    }

    if (kIsWeb) {
      // Browser default voices are robotic. Pick the warmest female natural
      // voice the browser exposes. Edge has Aria/Jenny (Natural); Chrome usually
      // exposes a female-toned "Google US English"; Windows has Zira; macOS Samantha.
      try {
        final voices = await _tts.getVoices;
        if (voices is List) {
          int score(Map v) {
            final name = (v['name'] as String? ?? '').toLowerCase();
            final locale = (v['locale'] as String? ?? '').toLowerCase();
            if (!locale.startsWith('en')) return -1;
            // Female natural voices on Edge — top tier, "cozy" sounding.
            if (name.contains('aria') || name.contains('jenny')) return 100;
            if (name.contains('jane') || name.contains('libby')) return 95;
            if (name.contains('michelle') || name.contains('clara')) return 90;
            if (name.contains('natural') && name.contains('female')) return 85;
            if (name.contains('natural')) return 70;
            // Female OS voices.
            if (name.contains('zira')) return 60;
            if (name.contains('samantha') || name.contains('karen')) return 60;
            if (name.contains('google us english')) return 55;
            if (name.contains('female')) return 50;
            if (name.contains('google') && name.contains('english')) return 30;
            // Deprioritize male voices we recognize.
            if (name.contains('david') || name.contains('mark') ||
                name.contains('guy')  || name.contains('alex')) return 5;
            return 10;
          }
          final ranked = voices.cast<Map>().toList()
            ..sort((a, b) => score(b).compareTo(score(a)));
          if (ranked.isNotEmpty && score(ranked.first) > 0) {
            await _tts.setVoice({
              'name': ranked.first['name'].toString(),
              'locale': ranked.first['locale'].toString(),
            });
          }
        }
      } catch (_) {/* voice selection is best-effort */}
    }

    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _ttsSpeaking = false);
      // If the user hasn't pressed Stop, automatically continue to the next page.
      if (_ttsActive) _advanceToNextPageForTts();
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _ttsSpeaking = false);
    });
    _tts.setErrorHandler((msg) {
      if (mounted) {
        setState(() { _ttsActive = false; _ttsSpeaking = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS engine error: $msg')),
        );
      }
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

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
    // 'page' from onPageChanged is 0-indexed new page — use directly
    if (_ttsActive) _speakCurrentPage(page);
  }

  Future<void> _speakCurrentPage(int pageIndex) async {
    final v = ++_speakVersion;
    await _tts.stop();
    if (v != _speakVersion) return;
    if (_pdfPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF still loading, try again in a moment.')),
        );
        setState(() { _ttsActive = false; _ttsSpeaking = false; });
      }
      return;
    }

    String? pageText;
    try {
      if (kIsWeb) {
        // _pdfPath is the URL on web. Fetch bytes once, cache, then use
        // Syncfusion to extract text — flutter_pdf_text doesn't support web.
        if (_webPdfBytes == null) {
          final response = await http.get(Uri.parse(_pdfPath!));
          if (v != _speakVersion) return;
          if (response.statusCode != 200) {
            throw Exception('HTTP ${response.statusCode} fetching PDF');
          }
          _webPdfBytes = response.bodyBytes;
        }
        final doc = sf.PdfDocument(inputBytes: _webPdfBytes!);
        final extractor = sf.PdfTextExtractor(doc);
        final docLen = doc.pages.count;
        final clampedIndex = pageIndex.clamp(0, docLen - 1);
        pageText = extractor.extractText(
          startPageIndex: clampedIndex,
          endPageIndex: clampedIndex,
        );
        doc.dispose();
      } else {
        // Mobile path — flutter_pdf_text from local file.
        final pdfFile = File(_pdfPath!);
        if (!await pdfFile.exists() || await pdfFile.length() < 100) {
          _pdfDoc = null;
          if (mounted) {
            setState(() { _ttsActive = false; _ttsSpeaking = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF file not accessible. Reopen the book and try again.')),
            );
          }
          return;
        }
        _pdfDoc ??= await PDFDoc.fromPath(_pdfPath!);
        if (v != _speakVersion) return;
        final docLen = _pdfDoc!.length;
        if (docLen == 0) return;
        final pageNum = (pageIndex + 1).clamp(1, docLen);
        pageText = await _pdfDoc!.pageAt(pageNum).text;
      }

      if (v != _speakVersion) return;
      pageText = _cleanForTts(pageText);
      if (pageText.trim().isEmpty) {
        if (mounted) {
          setState(() { _ttsActive = false; _ttsSpeaking = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No readable text on this page (scanned PDF?)')),
          );
        }
        return;
      }
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      if (mounted) setState(() => _ttsSpeaking = true);
      await _tts.speak(pageText);
    } catch (e) {
      _pdfDoc = null;
      if (mounted) {
        setState(() { _ttsActive = false; _ttsSpeaking = false; });
        final msg = e.toString().contains('INVALID_PATH')
            ? 'Could not read PDF text. The file may be encrypted or scanned.'
            : 'TTS error: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  /// Cleans PDF-extracted text so a TTS engine reads it like prose:
  ///   - joins broken hyphenated words across lines
  ///   - turns single line breaks into spaces (engines pause on \n)
  ///   - keeps double newlines as paragraph breaks
  ///   - strips control chars and page-numberish noise the extractor emits
  ///   - skips runs of unreadable symbols (often left over from images / glyphs)
  String _cleanForTts(String raw) {
    var text = raw.replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'-\s*\n\s*'), ''); // "exam-\nple" -> "example"
    text = text.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' '); // single \n -> space
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    // Replace runs of broken-font glyphs / exotic symbols with a single space.
    // Keep printable ASCII, Latin supplement, Latin Extended-A, curly quotes,
    // en/em dashes, and newlines.
    text = text.replaceAll(
        RegExp(r"[^ -~ -ſ‘’“”–—\n]+"),
        ' ');
    text = text.replaceAll(RegExp(r' {2,}'), ' ');
    return text.trim();
  }

  void _advanceToNextPageForTts() {
    if (_totalPages == 0) return;
    final next = _currentPage + 1; // _currentPage is 1-indexed
    if (next > _totalPages) {
      setState(() {
        _ttsActive = false;
        _ttsSpeaking = false;
      });
      return;
    }
    if (kIsWeb) {
      _webController.jumpToPage(next);
    } else {
      _pdfController?.setPage(next - 1); // setPage is 0-indexed
    }
    // _onPageChanged will fire from the underlying PDF view and call
    // _speakCurrentPage because _ttsActive is still true.
  }

  Future<void> _toggleTts() async {
    if (_ttsActive) {
      await _tts.stop();
      setState(() {
        _ttsActive = false;
        _ttsSpeaking = false;
      });
    } else {
      setState(() => _ttsActive = true);
      final page = _currentPage > 0
          ? _currentPage - 1
          : (ref.read(bookByIdProvider(widget.bookId)).valueOrNull?.currentPage ?? 1) - 1;
      _speakCurrentPage(page.clamp(0, 999999));
    }
  }

  // Called from slider onChangeEnd — restarts TTS with new settings immediately
  void _restartTtsIfActive() {
    if (!_ttsActive) return;
    final page = _currentPage > 0 ? _currentPage - 1 : 0;
    _speakCurrentPage(page);
  }

  void _showVoiceSettings() {
    double rate = _speechRate;
    double pitch = _pitch;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Voice Settings', style: AppTypography.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Changes apply when you release the slider.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Speed', style: AppTypography.labelLarge),
                    const Spacer(),
                    Text(
                      '${(rate * 100).round()}%',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Slider(
                  value: rate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setSheet(() => rate = v),
                  onChangeEnd: (v) {
                    setState(() => _speechRate = v);
                    _restartTtsIfActive();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Pitch', style: AppTypography.labelLarge),
                    const Spacer(),
                    Text(
                      pitch.toStringAsFixed(1),
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Slider(
                  value: pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setSheet(() => pitch = v),
                  onChangeEnd: (v) {
                    setState(() => _pitch = v);
                    _restartTtsIfActive();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookByIdProvider(widget.bookId));
    final book = bookAsync.valueOrNull;
    final pdfAsync = book != null ? ref.watch(pdfPathProvider(book.link)) : null;

    if (pdfAsync?.valueOrNull != null && _pdfPath == null) {
      _pdfPath = pdfAsync!.valueOrNull;
    }

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
                        controller: _webController,
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
                              if (pdfAsync?.hasValue == true) ...[
                                GestureDetector(
                                  onTap: _showVoiceSettings,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: Icon(
                                      Icons.tune,
                                      size: 18,
                                      color: _ttsActive
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _toggleTts,
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _ttsActive
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _ttsActive
                                            ? AppColors.primary
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _ttsSpeaking
                                              ? Icons.volume_up
                                              : Icons.volume_up_outlined,
                                          size: 16,
                                          color: _ttsActive
                                              ? Colors.white
                                              : AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _ttsActive ? 'Stop' : 'Read',
                                          style:
                                              AppTypography.bodySmall.copyWith(
                                            color: _ttsActive
                                                ? Colors.white
                                                : AppColors.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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

class WebPdfReaderController {
  _WebPdfReaderState? _state;
  void jumpToPage(int page) => _state?._jumpToPage(page);
}

class _WebPdfReader extends StatefulWidget {
  final String url;
  final int initialPage;
  final WebPdfReaderController? controller;
  final void Function(int page, int total) onPagesAndPageChanged;

  const _WebPdfReader({
    super.key,
    required this.url,
    required this.initialPage,
    required this.onPagesAndPageChanged,
    this.controller,
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
    widget.controller?._state = this;
    _scrollController.addListener(_onScroll);
    _load();
  }

  void _jumpToPage(int page) {
    if (_itemHeight <= 0 || !_scrollController.hasClients) return;
    final clamped = page.clamp(1, _totalPages > 0 ? _totalPages : page);
    _scrollController.jumpTo(_itemHeight * (clamped - 1));
  }

  Future<void> _load() async {
    try {
      final response = await http.get(Uri.parse(widget.url)).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Download timed out'),
          );
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
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
    final page = (_scrollController.offset / _itemHeight).floor() + 1;
    final clamped = page.clamp(1, _totalPages);
    if (clamped != _currentPage) {
      _currentPage = clamped;
      widget.onPagesAndPageChanged(clamped - 1, _totalPages);
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
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
