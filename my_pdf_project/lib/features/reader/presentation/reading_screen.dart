import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_pdf_text/flutter_pdf_text.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../library/presentation/library_controller.dart';
import '../../library/presentation/library_providers.dart';

final _pdfPathProvider = FutureProvider.family<String, String>((ref, url) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/pdf_${url.hashCode}.pdf');
  if (await file.exists()) return file.path;
  final response = await http.get(Uri.parse(url));
  await file.writeAsBytes(response.bodyBytes);
  return file.path;
});

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
  PDFDoc? _pdfDoc; // cached so we don't reload on every page

  double _speechRate = 0.5;
  double _pitch = 1.0;

  // Cancellation: incremented each time a new speak starts;
  // stale async work checks version before proceeding.
  int _speakVersion = 0;

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _ttsSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _ttsSpeaking = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _onPageChanged(int? page, int? total) {
    if (page == null || total == null) return;
    setState(() {
      _currentPage = page + 1;
      _totalPages = total;
    });
    ref.read(libraryControllerProvider.notifier).updateProgress(
      bookId: widget.bookId,
      currentPage: page + 1,
      totalPages: total,
    );
    // 'page' from onPageChanged is 0-indexed new page — use directly
    if (_ttsActive) _speakCurrentPage(page);
  }

  Future<void> _speakCurrentPage(int pageIndex) async {
    final v = ++_speakVersion;
    await _tts.stop();
    if (v != _speakVersion || _pdfPath == null) return;
    try {
      _pdfDoc ??= await PDFDoc.fromPath(_pdfPath!);
      if (v != _speakVersion) return;
      if (pageIndex >= _pdfDoc!.length) return;
      final text = await _pdfDoc!.pageAt(pageIndex).text;
      if (v != _speakVersion || text.trim().isEmpty) return;
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      if (mounted) setState(() => _ttsSpeaking = true);
      await _tts.speak(text);
    } catch (_) {
      if (mounted) setState(() => _ttsSpeaking = false);
    }
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
    final pdfAsync = book != null ? ref.watch(_pdfPathProvider(book.link)) : null;

    if (pdfAsync?.valueOrNull != null && _pdfPath == null) {
      _pdfPath = pdfAsync!.valueOrNull;
    }

    final progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFD8DADB),
      body: Stack(
        children: [
          if (pdfAsync != null)
            pdfAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Failed to load PDF', style: AppTypography.bodyMedium),
                    const SizedBox(height: 8),
                    Text('$e',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              data: (path) => PDFView(
                filePath: path,
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: false,
                pageFling: true,
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
                onViewCreated: (controller) {
                  _pdfController = controller;
                },
                onPageChanged: _onPageChanged,
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
                                onTap: () => context.pop(),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xCC191C1D),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: AppTypography.bodySmall
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
