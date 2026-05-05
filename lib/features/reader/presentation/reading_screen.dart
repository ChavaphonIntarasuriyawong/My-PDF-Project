import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdf_text/flutter_pdf_text.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../../core/config/feature_flags.dart';
import '../../../core/network/pdf_fetcher.dart';
import '../../../core/text/tts_text_cleaner.dart';
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
  bool _isDisposed = false; // gates TTS handlers from firing post-dispose
  PDFDoc? _pdfDoc; // cached so we don't reload on every page (mobile only)
  Uint8List? _webPdfBytes; // cached fetched bytes on web for Syncfusion text extractor
  String? _webPdfBytesKey; // book.link the cached _webPdfBytes belong to
  final WebPdfReaderController _webController = WebPdfReaderController();

  /// Resolves current PDF path/URL by reading the book + provider. Avoids
  /// caching in a field that goes stale on book switch / hot-reload.
  String? _currentPdfPath() {
    final book = ref.read(bookByIdProvider(widget.bookId)).valueOrNull;
    if (book == null) return null;
    return ref.read(pdfPathProvider(book.link)).valueOrNull;
  }

  // Web uses the W3C SpeechSynthesis scale where 1.0 is "normal speed".
  // Mobile (Android/iOS) uses 0.5 as the natural default — anything higher
  // sounds rushed.
  double _speechRate = kIsWeb ? 1.0 : 0.5;
  double _pitch = 1.0;

  // Cancellation: incremented each time a new speak starts;
  // stale async work checks version before proceeding.
  int _speakVersion = 0;

  // Web: voiceschanged fires after first user gesture in some browsers, so
  // initState often sees an empty voice list. Track whether we've installed
  // a voice; retry just-in-time before each speak() if not.
  bool _webVoiceSet = false;

  // OCR fallback (Wave 3) — UI-local ephemeral state.
  // `_ocrInProgress` toggles the linear progress strip while a foreground OCR
  // is running for the current page. `_ocrSessionNoticeShown` ensures the
  // "first OCR may take a few seconds" snackbar fires once per reader session.
  bool _ocrInProgress = false;
  bool _ocrSessionNoticeShown = false;
  // Cancellation token for background pre-OCR — mirrors `_speakVersion`.
  // Bumped on dispose / book switch / fresh foreground OCR trigger so any
  // in-flight loop iteration bails on its next check.
  int _bgOcrVersion = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
    // Mark this book as recently opened (local Hive store) so it surfaces
    // on the home "Recently Opened" rail across sessions.
    ref.read(recentBooksServiceProvider).markOpened(widget.bookId);
  }

  Future<void> _initTts() async {
    AppLogger.debug('TTS', 'init start, web=$kIsWeb');
    if (!kIsWeb) {
      try {
        final engines = await _tts.getEngines;
        AppLogger.debug('TTS', 'engines available: $engines');
        final defaultEngine = await _tts.getDefaultEngine;
        AppLogger.debug('TTS', 'default engine: $defaultEngine');
      } catch (e) {
        AppLogger.debug('TTS', 'engine query failed: $e');
      }
    }
    // setLanguage returns -1 (NOT_SUPPORTED) or -2 (MISSING_DATA) on devices
    // without English TTS pack — fall back to device default in that case.
    final langResult = await _tts.setLanguage('en-US');
    AppLogger.debug('TTS', 'setLanguage(en-US) returned: $langResult');
    if (langResult is int && langResult < 0) {
      final langs = await _tts.getLanguages;
      AppLogger.debug('TTS', 'available languages: $langs');
      final list = langs as List?;
      if (list != null && list.isNotEmpty) {
        // Prefer any English variant before random first locale.
        final en = list.firstWhere(
          (l) => l.toString().toLowerCase().startsWith('en'),
          orElse: () => list.first,
        );
        final r = await _tts.setLanguage(en.toString());
        AppLogger.debug('TTS', 'fallback setLanguage($en) returned: $r');
      }
    }

    if (kIsWeb) {
      await _trySetWebVoice();
    }

    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // Ensures speak() future resolves on actual completion, not immediately.
    // Without this, Android sometimes drops audio + completionHandler never fires.
    // The web plugin (flutter_tts 4.2.5) also supports awaitSpeakCompletion via
    // an internal Completer keyed off `utterance.onEnd` — enabling it on web
    // means our completion handler runs after the future resolves, removing a
    // race where natural completion arrived before `_ttsSpeaking = true` was
    // visible to the handler.
    try { await _tts.awaitSpeakCompletion(true); } catch (_) {}
    _tts.setCompletionHandler(() {
      if (_isDisposed || !mounted) return;
      // Re-entrancy guard: only advance if we were actually speaking. On some
      // platforms the engine fires `completion` for both natural finish AND
      // for stop()-triggered cancellation (especially when a fresh
      // _speakCurrentPage calls _tts.stop() before issuing the new speak).
      // Without this guard, that stale completion calls _advanceToNextPageForTts
      // once for the page we just navigated TO, AND a second time from the
      // legitimate completion of that page — skipping every other page.
      final wasSpeaking = _ttsSpeaking;
      setState(() => _ttsSpeaking = false);
      if (!wasSpeaking) return;
      // If the user hasn't pressed Stop, automatically continue to the next page.
      if (_ttsActive) _advanceToNextPageForTts();
    });
    _tts.setCancelHandler(() {
      if (_isDisposed || !mounted) return;
      setState(() => _ttsSpeaking = false);
    });
    _tts.setErrorHandler((msg) {
      if (_isDisposed || !mounted) return;
      // Web SpeechSynthesis fires `error` with type "interrupted"/"canceled"
      // every time we call stop() to switch pages. Not a real error — ignore
      // so auto-advance doesn't self-cancel mid-stream.
      final lower = msg.toString().toLowerCase();
      if (lower.contains('interrupt') ||
          lower.contains('cancel') ||
          lower.contains('not-allowed')) {
        AppLogger.debug('TTS', 'benign error ignored: $msg');
        return;
      }
      setState(() { _ttsActive = false; _ttsSpeaking = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TTS engine error: $msg')),
      );
    });
  }

  Future<void> _trySetWebVoice() async {
    try {
      List? voices;
      for (var i = 0; i < 10; i++) {
        final v = await _tts.getVoices;
        if (v is List && v.isNotEmpty) {
          voices = v;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 150));
      }
      AppLogger.debug('TTS', 'web voices found: ${voices?.length ?? 0}');
      if (voices == null) return;
      int score(Map v) {
        final name = (v['name'] as String? ?? '').toLowerCase();
        final locale = (v['locale'] as String? ?? '').toLowerCase();
        if (!locale.startsWith('en')) return -1;
        if (name.contains('aria') || name.contains('jenny')) return 100;
        if (name.contains('jane') || name.contains('libby')) return 95;
        if (name.contains('michelle') || name.contains('clara')) return 90;
        if (name.contains('natural') && name.contains('female')) return 85;
        if (name.contains('natural')) return 70;
        if (name.contains('zira')) return 60;
        if (name.contains('samantha') || name.contains('karen')) return 60;
        if (name.contains('google us english')) return 55;
        if (name.contains('female')) return 50;
        if (name.contains('google') && name.contains('english')) return 30;
        if (name.contains('david') || name.contains('mark') ||
            name.contains('guy')  || name.contains('alex')) {
          return 5;
        }
        return 10;
      }
      final ranked = voices.cast<Map>().toList()
        ..sort((a, b) => score(b).compareTo(score(a)));
      if (ranked.isNotEmpty && score(ranked.first) > 0) {
        await _tts.setVoice({
          'name': ranked.first['name'].toString(),
          'locale': ranked.first['locale'].toString(),
        });
        _webVoiceSet = true;
        AppLogger.debug('TTS', 'web voice set: ${ranked.first['name']}');
      }
    } catch (_) {/* best-effort */}
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Detach handlers FIRST so any in-flight stop()/cancel from the engine
    // doesn't fire setState on a disposed state. The flag above is the
    // belt-and-suspenders guard for the case where the plugin's platform
    // channel races us.
    _tts.setCompletionHandler(() {});
    _tts.setCancelHandler(() {});
    _tts.setErrorHandler((_) {});
    _tts.stop();
    // Cancel any in-flight background OCR sweep. Bumping the version makes
    // the loop's next iteration check bail; the loop's own `finally` would
    // normally clear the progress provider, but it only does so if it owns
    // the sweep — which it no longer will after the bump. So we clear
    // progress here too, scheduled post-frame to avoid Riverpod barking
    // about state mutations during widget tree teardown.
    _bgOcrVersion++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(bookOcrProgressProvider.notifier).state = null;
      } catch (_) {/* container disposed before frame — best effort */}
    });
    // Release native PDF text-extractor handle on Android — leak otherwise.
    _pdfDoc = null;
    _webPdfBytes = null;
    _webPdfBytesKey = null;
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
    // Clear speaking flag BEFORE stop() so the completion handler's
    // re-entrancy guard sees `_ttsSpeaking == false` if stop() synchronously
    // fires `completion` (some engines treat stop-mid-utterance as completion).
    final wasSpeakingBeforeStop = _ttsSpeaking;
    if (mounted && _ttsSpeaking) {
      setState(() => _ttsSpeaking = false);
    } else {
      _ttsSpeaking = false;
    }
    await _tts.stop();
    if (v != _speakVersion) return;
    // Web Chrome bug: synth.cancel() is asynchronous — the underlying plugin
    // keeps `ttsState == playing` until the cancelled utterance fires onerror
    // (`interrupted`) or onend on the next microtask. If we call speak() in
    // that window, the plugin's `_speak` short-circuits because the state is
    // not yet `stopped`, and our new text is silently dropped — auto-advance
    // appears to "stop after one page". A short delay lets the cancel event
    // propagate. Only needed when there was an actual utterance to cancel.
    if (kIsWeb && wasSpeakingBeforeStop) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (v != _speakVersion) return;
    }
    final pdfPath = _currentPdfPath();
    if (pdfPath == null) {
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
        // pdfPath is the URL on web. Cache bytes per book.link so switching
        // books reloads the right document — without the key check, TTS would
        // read the previous book's text on the new book.
        if (_webPdfBytes == null || _webPdfBytesKey != pdfPath) {
          final response = await fetchPdfBytes(pdfPath);
          if (v != _speakVersion) return;
          _webPdfBytes = response.bodyBytes;
          _webPdfBytesKey = pdfPath;
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
        final pdfFile = File(pdfPath);
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
        _pdfDoc ??= await PDFDoc.fromPath(pdfPath);
        if (v != _speakVersion) return;
        final docLen = _pdfDoc!.length;
        if (docLen == 0) return;
        final pageNum = (pageIndex + 1).clamp(1, docLen);
        pageText = await _pdfDoc!.pageAt(pageNum).text;
      }

      if (v != _speakVersion) return;
      pageText = cleanForTts(pageText);
      if (pageText.trim().isEmpty) {
        // Text-layer extraction came back empty. Two paths:
        //   1. OCR fallback disabled (Remote Config kill switch) — preserve
        //      the original "scanned PDF?" snackbar so the user still sees
        //      a clear dead-end message.
        //   2. OCR enabled — render the page as an image, run OCR, swap the
        //      result back into `pageText`, then fall through to the speak
        //      path below.
        final flags = ref.read(featureFlagsProvider);
        if (!flags.ocrFallbackEnabled) {
          if (mounted) {
            setState(() { _ttsActive = false; _ttsSpeaking = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No readable text on this page (scanned PDF?)')),
            );
          }
          return;
        }

        if (!mounted) return;
        // First OCR of the session: gentle heads-up that the next few seconds
        // will feel slow (engine init + traineddata load on web, traineddata
        // load on mobile). Subsequent pages don't show this.
        if (!_ocrSessionNoticeShown) {
          _ocrSessionNoticeShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(
              'Using OCR for scanned PDF — first page may take a few seconds.',
            )),
          );
        }
        setState(() => _ocrInProgress = true);
        String ocrText;
        try {
          ocrText = await ref.read(ocrPageTextProvider((
            bookId: widget.bookId,
            url: pdfPath,
            pageIndex: pageIndex,
          )).future);
        } catch (e) {
          AppLogger.error('OCR', 'failed', error: e);
          if (mounted) {
            setState(() {
              _ttsActive = false;
              _ttsSpeaking = false;
              _ocrInProgress = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_friendlyOcrError(e))),
            );
          }
          return;
        } finally {
          if (mounted && _ocrInProgress) {
            setState(() => _ocrInProgress = false);
          }
        }
        // User navigated / pressed Stop while OCR was running — drop result.
        if (v != _speakVersion) return;
        if (ocrText.trim().isEmpty) {
          if (mounted) {
            setState(() { _ttsActive = false; _ttsSpeaking = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not extract any text from this page.')),
            );
          }
          return;
        }
        // ocrPageTextProvider already runs cleanForTts before caching — no
        // double-clean needed here.
        pageText = ocrText;
        // First successful OCR — kick off background pre-OCR for the rest of
        // the book so subsequent pages are instant.
        _maybeStartBackgroundOcr(pageIndex, pdfPath);
      }
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      // Web: voices populate asynchronously after first user gesture. Retry
      // voice selection here (after the Read button tap) if init missed it.
      if (kIsWeb && !_webVoiceSet) {
        await _trySetWebVoice();
      }
      if (mounted) setState(() => _ttsSpeaking = true);
      // Diagnostic: extracted text length is a common failure mode (image-only PDFs).
      AppLogger.debug('TTS', 'speaking ${pageText.length} chars, rate=$_speechRate pitch=$_pitch web=$kIsWeb');
      final result = await _tts.speak(pageText);
      AppLogger.debug('TTS', 'speak() returned: $result (version=$v, current=$_speakVersion)');
      // With awaitSpeakCompletion(true), result==0 also fires on legitimate
      // interruption (stop() before completion). Don't surface as error.
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

  /// Kicks off best-effort background pre-OCR for every other page in the
  /// Maps OCR exception output to a short user-facing snackbar message.
  /// Raw exception strings (`Bad state: Could not render page 5 ...`) confuse
  /// users — translate to plain English while keeping the diagnostic detail
  /// in the AppLogger.error call.
  String _friendlyOcrError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('image bytes were null') ||
        msg.contains('could not render page')) {
      return 'Could not read this page. The PDF may be damaged or password-protected.';
    }
    if (msg.contains('traineddata') ||
        msg.contains('language data') ||
        msg.contains('tessdata')) {
      return 'Text recognition is not available right now. Please try again later.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Reading this page is taking too long. Try a different page or try again.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Network problem while reading. Check your connection and try again.';
    }
    return 'Could not read text from this page. Try another page or try again later.';
  }

  /// book once the foreground (lazy) OCR has surfaced its first hit. Cached
  /// pages are skipped so the loop is idempotent — re-entering the book mid
  /// pre-OCR resumes where it left off.
  ///
  /// Cancellation: `_bgOcrVersion` is bumped on dispose, on any subsequent
  /// `_maybeStartBackgroundOcr` call, and via the dispose hook. The captured
  /// `v` is checked at the top of every iteration so the loop bails within
  /// one page-time of the trigger.
  ///
  /// Errors per page are swallowed (`debugPrint` only) so a single bad page
  /// can't crash the whole pre-OCR sweep. Total pages is read from
  /// `_totalPages` which is populated by `onPageChanged` / `onRender` for
  /// both mobile and web before this method ever runs (any successful TTS
  /// invocation implies the reader has rendered at least once).
  void _maybeStartBackgroundOcr(int triggeringPageIndex, String pdfPath) {
    final total = _totalPages;
    if (total <= 1) return; // single-page book — nothing to pre-fetch.
    final v = ++_bgOcrVersion;
    final bookId = widget.bookId;
    // Surface a starting state immediately so the UI chip pops in without
    // waiting for the first page to finish.
    ref.read(bookOcrProgressProvider.notifier).state = (done: 1, total: total);

    // Run the loop on its own microtask so the caller (foreground TTS) can
    // continue uninterrupted.
    Future<void>(() async {
      var done = 1; // triggering page is already cached.
      try {
        for (var i = 0; i < total; i++) {
          if (v != _bgOcrVersion) return; // cancelled.
          if (i == triggeringPageIndex) continue;

          // Skip pages already cached so re-entry / next-session resume
          // is zero-cost.
          final cached = ref.read(ocrCacheServiceProvider).get(bookId, i);
          if (cached == null) {
            try {
              await ref.read(ocrPageTextProvider((
                bookId: bookId,
                url: pdfPath,
                pageIndex: i,
              )).future);
            } catch (e) {
              // Per-page failure is non-fatal — we'll fall back to
              // foreground OCR (or the empty snackbar) if the user
              // navigates here.
              AppLogger.warn('OCR', 'bg page $i failed', error: e);
            }
          }
          if (v != _bgOcrVersion) return;
          done += 1;
          ref.read(bookOcrProgressProvider.notifier).state =
              (done: done, total: total);
          // Yield back to the event loop so UI repaints, scroll & tap
          // gestures stay responsive, and the cancellation flag has a
          // chance to flip.
          await Future<void>.delayed(Duration.zero);
        }
      } catch (e) {
        // Belt-and-suspenders: nothing here should escape, but if it does,
        // never let a background sweep crash the screen.
        AppLogger.warn('OCR', 'bg sweep aborted', error: e);
      } finally {
        // Only clear progress if we're still the active sweep — otherwise a
        // later sweep will manage its own lifecycle.
        if (v == _bgOcrVersion) {
          ref.read(bookOcrProgressProvider.notifier).state = null;
        }
      }
    });
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
      // Flip flag BEFORE await stop() — completion handler races against this.
      // If we set after, completion can fire mid-await with _ttsActive still
      // true, triggering auto-advance and a runaway speak loop.
      setState(() {
        _ttsActive = false;
        _ttsSpeaking = false;
      });
      _speakVersion++; // invalidate any in-flight _speakCurrentPage
      await _tts.stop();
    } else {
      setState(() => _ttsActive = true);
      // On web, the parent's `_currentPage` mirrors the web reader via
      // callback, but there's a brief startup window before scroll listener
      // fires. Query the web controller directly to avoid reading the
      // previous page (off-by-one) at the very first Read tap.
      int displayedPage;
      if (kIsWeb) {
        displayedPage = _webController.currentPage ??
            (_currentPage > 0
                ? _currentPage
                : ref
                        .read(bookByIdProvider(widget.bookId))
                        .valueOrNull
                        ?.currentPage ??
                    1);
      } else {
        displayedPage = _currentPage > 0
            ? _currentPage
            : (ref
                    .read(bookByIdProvider(widget.bookId))
                    .valueOrNull
                    ?.currentPage ??
                1);
      }
      _speakCurrentPage((displayedPage - 1).clamp(0, 999999));
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

    // Mid-read delete: book stream resolved but doc is gone (deleted from
    // shelf or book info while reader was open). Bail back to /home so the
    // reader doesn't sit on a dead URL.
    if (bookAsync.hasValue && book == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                data: (path) => Padding(
                  // Push PDF below the top bar overlay so the first line of
                  // text isn't hidden behind it. Status bar + toolbar +
                  // progress bar ≈ 56dp on top of the system inset.
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 56,
                  ),
                  child: kIsWeb
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
                              Semantics(
                                button: true,
                                label: 'Back to book details',
                                child: GestureDetector(
                                  onTap: () => context.canPop()
                                      ? context.pop()
                                      : context.go('/book/${widget.bookId}'),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                        minWidth: 48, minHeight: 48),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.arrow_back,
                                        color: AppColors.primary, size: 20),
                                  ),
                                ),
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
                                Semantics(
                                  button: true,
                                  label: 'Voice settings: speed and pitch',
                                  child: GestureDetector(
                                    onTap: _showVoiceSettings,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                          minWidth: 48, minHeight: 48),
                                      alignment: Alignment.center,
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
                                ),
                                Semantics(
                                  button: true,
                                  label: _ttsActive
                                      ? 'Stop reading aloud'
                                      : 'Start reading this page aloud',
                                  child: GestureDetector(
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
                        // OCR foreground progress strip — only present while
                        // the current page's text is being recovered. Sits
                        // beneath the existing reading-progress bar so layout
                        // doesn't shift when it appears/disappears.
                        if (_ocrInProgress) ...[
                          const LinearProgressIndicator(
                            backgroundColor: AppColors.progressTrack,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.primary),
                            minHeight: 2,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.text_snippet_outlined,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Extracting text from scanned page...',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
  // 1-indexed currently visible page, or null if reader not yet mounted.
  int? get currentPage => _state?._currentPage;
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
