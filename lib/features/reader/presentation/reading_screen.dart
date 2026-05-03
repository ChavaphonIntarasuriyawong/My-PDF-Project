import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdf_text/flutter_pdf_text.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:hive/hive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../../core/config/feature_flags.dart';
import '../../../core/local/achievement_service.dart';
import '../../../core/local/book_finish_service.dart';
import '../../../core/local/recent_books_service.dart';
import '../../../core/local/streak_service.dart';
import '../../../core/network/pdf_fetcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../library/presentation/library_controller.dart';
import '../../library/presentation/library_providers.dart';
import 'controllers/karaoke_controller.dart';
import 'widgets/karaoke_text_pane.dart';

/// Hive key for the persisted user-selected speech rate. Engine-clamp scale:
/// mobile accepts 0.1–1+ (we keep 0.5–2.0 user-facing and let the engine
/// clamp natively); web accepts 0.1–10 with practical 0.5–2.0.
const String _kTtsRateKey = 'tts_rate';

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
  Uint8List?
  _webPdfBytes; // cached fetched bytes on web for Syncfusion text extractor
  String? _webPdfBytesKey; // book.link the cached _webPdfBytes belong to
  final WebPdfReaderController _webController = WebPdfReaderController();

  // Per-page extracted text cache. Extraction is the dominant latency on
  // press-Read (mobile flutter_pdf_text + web Syncfusion both run on UI
  // isolate and can take 200-800ms on dense pages). Caching means a re-read
  // of the same page or auto-advance to a page we prefetched starts speaking
  // immediately. Cleared on book switch via [_resetPageCacheIfBookChanged].
  final Map<int, String> _pageTextCache = {};
  String? _pageCacheBookKey; // book.link the cached entries belong to.
  // Tracks an in-flight prefetch so we don't queue duplicate extractions
  // when the user mashes Read or auto-advance fires before the previous
  // prefetch finishes.
  final Set<int> _pageTextInflight = {};

  // Last applied engine config — skip redundant async round-trips when the
  // value hasn't changed since the previous speak. setSpeechRate / setPitch
  // are platform channel calls that add ~10-30ms each on Android.
  double? _lastAppliedEngineRate;
  double? _lastAppliedPitch;

  /// Resolves current PDF path/URL by reading the book + provider. Avoids
  /// caching in a field that goes stale on book switch / hot-reload.
  String? _currentPdfPath() {
    final book = ref.read(bookByIdProvider(widget.bookId)).valueOrNull;
    if (book == null) return null;
    return ref.read(pdfPathProvider(book.link)).valueOrNull;
  }

  /// Drops cached page text + extractor handle when the active book changed.
  /// Called from [_speakCurrentPage] before the cache is consulted, so a
  /// stale entry from a previous book never feeds into TTS.
  void _resetPageCacheIfBookChanged(String pdfPath) {
    if (_pageCacheBookKey == pdfPath) return;
    _pageCacheBookKey = pdfPath;
    _pageTextCache.clear();
    _pageTextInflight.clear();
    _pdfDoc = null;
  }

  /// Extract page text once, cache the result, return it. The cache key is
  /// (pdfPath, pageIndex). Returns null when the file is missing/empty —
  /// caller surfaces a snackbar in that case (existing behavior preserved).
  /// Parallel calls for the same page coalesce via [_pageTextInflight] so
  /// prefetch + on-demand don't double-extract.
  Future<String?> _extractPageText(int pageIndex) async {
    final cached = _pageTextCache[pageIndex];
    if (cached != null) return cached;
    final pdfPath = _currentPdfPath();
    if (pdfPath == null) return null;
    _resetPageCacheIfBookChanged(pdfPath);
    // Re-check after cache reset (rare: book switched between cache hit
    // and now; cache cleared, fall through to extraction).
    final cached2 = _pageTextCache[pageIndex];
    if (cached2 != null) return cached2;
    if (_pageTextInflight.contains(pageIndex)) {
      // Spin until the in-flight extraction completes. 50ms ticks keep this
      // off the busy loop and bail at 5s total so a stuck extractor doesn't
      // wedge the UI forever.
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final ready = _pageTextCache[pageIndex];
        if (ready != null) return ready;
        if (!_pageTextInflight.contains(pageIndex)) break;
      }
      return _pageTextCache[pageIndex];
    }
    _pageTextInflight.add(pageIndex);
    try {
      String? raw;
      if (kIsWeb) {
        if (_webPdfBytes == null || _webPdfBytesKey != pdfPath) {
          final response = await fetchPdfBytes(pdfPath);
          _webPdfBytes = response.bodyBytes;
          _webPdfBytesKey = pdfPath;
        }
        final doc = sf.PdfDocument(inputBytes: _webPdfBytes!);
        try {
          final extractor = sf.PdfTextExtractor(doc);
          final docLen = doc.pages.count;
          if (docLen == 0) return null;
          final clampedIndex = pageIndex.clamp(0, docLen - 1);
          raw = extractor.extractText(
            startPageIndex: clampedIndex,
            endPageIndex: clampedIndex,
          );
        } finally {
          doc.dispose();
        }
      } else {
        final pdfFile = File(pdfPath);
        if (!await pdfFile.exists() || await pdfFile.length() < 100) {
          return null;
        }
        _pdfDoc ??= await PDFDoc.fromPath(pdfPath);
        final docLen = _pdfDoc!.length;
        if (docLen == 0) return null;
        final pageNum = (pageIndex + 1).clamp(1, docLen);
        raw = await _pdfDoc!.pageAt(pageNum).text;
      }
      final cleaned = _cleanForTts(raw);
      _pageTextCache[pageIndex] = cleaned;
      return cleaned;
    } catch (e) {
      debugPrint('[TTS] extract page $pageIndex failed: $e');
      return null;
    } finally {
      _pageTextInflight.remove(pageIndex);
    }
  }

  /// Background prefetch for a page so a future on-demand request hits the
  /// cache instead of blocking on extraction. Fire-and-forget; failures are
  /// silent. The optional [delay] lets us push the heavy work outside the
  /// engine's startup window — text extraction runs on the UI isolate and
  /// can starve `flutter_tts` progress callbacks (which marshal through the
  /// platform channel on the same thread). 3s is enough for the engine to
  /// stabilize on the current speak before extraction begins.
  void _prefetchPageText(
    int pageIndex, {
    Duration delay = Duration.zero,
  }) {
    if (pageIndex < 0) return;
    if (_totalPages > 0 && pageIndex >= _totalPages) return;
    if (_pageTextCache.containsKey(pageIndex)) return;
    if (_pageTextInflight.contains(pageIndex)) return;
    Future<void> run() async {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
        if (_isDisposed || !mounted) return;
        if (_pageTextCache.containsKey(pageIndex)) return;
        if (_pageTextInflight.contains(pageIndex)) return;
      }
      await _extractPageText(pageIndex);
    }
    unawaited(run());
  }

  /// Apply rate/pitch to the engine only when the value actually changed
  /// since the last apply. Each setter is a platform-channel round-trip
  /// (~10-30ms on Android) — skipping no-ops cuts ~40-80ms off the hot
  /// path on every page advance.
  Future<void> _applyEngineConfigIfChanged() async {
    if (_lastAppliedEngineRate != _engineRate) {
      await _tts.setSpeechRate(_engineRate);
      _lastAppliedEngineRate = _engineRate;
    }
    if (_lastAppliedPitch != _pitch) {
      await _tts.setPitch(_pitch);
      _lastAppliedPitch = _pitch;
    }
  }

  // User-facing speech rate: 1.0 = "normal" on every platform. Slider in
  // the karaoke pane and Voice Settings shows this value. The number sent
  // to the engine is platform-corrected via [_engineRate] because Android +
  // iOS treat 0.5 as their natural baseline (1.0 sounds 2× speed).
  double _speechRate = 1.0;

  /// Translates the user-facing rate to what the engine needs.
  /// Web SpeechSynthesis: 1.0 = normal → pass through.
  /// Mobile flutter_tts: natural ≈ 0.5 → halve so user's 1.0 sounds normal.
  double get _engineRate => kIsWeb ? _speechRate : _speechRate * 0.5;
  double _pitch = 1.0;

  /// Tracks whether we've already recorded a TTS-on-this-book event for the
  /// achievement counter. Reset on book switch (initState rebinds widget).
  bool _ttsCountedForBook = false;

  // Cancellation: incremented each time a new speak starts;
  // stale async work checks version before proceeding.
  int _speakVersion = 0;

  // Programmatic-stop quiet window. Some engines (web Chrome, Android in
  // certain release builds) fire `cancel` AND/OR `error("interrupted")` on
  // a delay AFTER our own _tts.stop() returns — sometimes after we've
  // already begun the next speak(). A counter approach is fragile because
  // the same stop can surface as zero, one, or two events depending on
  // platform. Instead we stamp the time of every programmatic stop and
  // ignore cancel/interrupt events within a short window. Real user-
  // initiated cancels (toggling Stop) bypass the stamp because they don't
  // call _markProgrammaticStop().
  DateTime? _lastProgrammaticStopAt;
  static const Duration _kProgrammaticStopQuietWindow =
      Duration(milliseconds: 600);

  bool get _isInProgrammaticStopWindow {
    final at = _lastProgrammaticStopAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < _kProgrammaticStopQuietWindow;
  }

  void _markProgrammaticStop() {
    _lastProgrammaticStopAt = DateTime.now();
  }

  // Web: voiceschanged fires after first user gesture in some browsers, so
  // initState often sees an empty voice list. Track whether we've installed
  // a voice; retry just-in-time before each speak() if not.
  bool _webVoiceSet = false;

  // ----- Karaoke captions -----
  // Detection window: if no progress event lands by then we flip into
  // sentence-by-sentence mode and drive highlights from the queue below.
  Timer? _karaokeProgressDetectTimer;
  bool _karaokeProgressEverFired = false;
  // Sentence-mode queue. When non-empty, the completion handler advances by
  // calling _speakNextSentence() instead of jumping pages — sentence speak
  // intentionally swallows the page-advance until the queue empties.
  List<_KaraokeSentence>? _karaokeSentences;
  int _karaokeSentenceIndex = 0;

  // ----- Confetti on first-finish -----
  // 3-second one-shot burst when the user lands on the last page for the very
  // first time (per book). Persisted via [BookFinishService] in Hive so a
  // subsequent visit is silent. Disposed in [dispose] to release the ticker.
  late final ConfettiController _finishConfetti;

  // ----- TTS resume slot (music-app behavior) -----
  // When the user stops mid-page (or a cancel/error fires), capture where we
  // were so the next play resumes there instead of restarting from the top.
  // Screen-local in-memory only — dies with the screen, no persistence.
  // Cleared on: page change, manual seek, natural completion, successful
  // dispatch on the next play.
  int _resumeOffset = -1; // char offset within fullText, -1 = none
  int _resumeSentenceIndex = -1; // sentence queue index, -1 = none
  String _resumeFullText = ''; // guard: only valid if matches current pageText

  void _captureResume() {
    final s = ref.read(karaokeControllerProvider);
    if (s.fullText.isEmpty) {
      _clearResume();
      return;
    }
    if (s.fallbackSentenceMode) {
      // _speakNextSentence increments _karaokeSentenceIndex *before* the
      // speak() — so when the user stops mid-sentence, the index points one
      // past the sentence currently audible. Subtract one so resume replays
      // the interrupted sentence from its start (music-app style).
      // Skip if no sentence was reached yet (index 0 = pre-first-tick).
      if (_karaokeSentenceIndex <= 0) return;
      _resumeSentenceIndex = _karaokeSentenceIndex - 1;
      // Index 0 means the very first sentence was interrupted — replaying
      // it is just "start from the top", so don't treat as resume.
      if (_resumeSentenceIndex <= 0) return;
      _resumeOffset = -1;
    } else {
      // Word-mode: only capture if we have a valid current word offset.
      // After onTtsStop, currentStart is -1 — guard against overwriting a
      // previously-captured valid slot when the cancel handler re-fires.
      if (s.currentStart <= 0) return;
      _resumeOffset = s.currentStart;
      _resumeSentenceIndex = -1;
    }
    _resumeFullText = s.fullText;
  }

  void _clearResume() {
    _resumeOffset = -1;
    _resumeSentenceIndex = -1;
    _resumeFullText = '';
  }

  bool get _hasResume =>
      _resumeFullText.isNotEmpty &&
      (_resumeOffset > 0 || _resumeSentenceIndex > 0);

  @override
  void initState() {
    super.initState();
    _restoreSpeechRate();
    _initTts();
    _finishConfetti = ConfettiController(duration: const Duration(seconds: 3));
    // Mark this book as recently opened (local Hive store) so it surfaces
    // on the home "Recently Opened" rail across sessions.
    ref.read(recentBooksServiceProvider).markOpened(widget.bookId);
    // Reading streak: opening any book counts toward today's tally. Done
    // here (not in LibraryController) because the reader is the single,
    // unambiguous "started reading" entry point — book info screens, share
    // sheet previews, etc. don't qualify.
    // Defer until first frame so a Hive failure (test envs without an open
    // box) is async-swallowed in the controller and doesn't block paint.
    // Cache-warm the page the user is about to read. PDF text extraction
    // is the dominant press-Read latency (~200-800ms on dense pages); doing
    // it eagerly while the reader paints means the first Read tap starts
    // speaking almost instantly. Deferred via post-frame so we don't fight
    // the initial layout for the UI isolate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final book = ref.read(bookByIdProvider(widget.bookId)).valueOrNull;
      if (book == null) return;
      // Book may load with currentPage == 0; default to first page.
      final page0 = (book.currentPage > 0 ? book.currentPage : 1) - 1;
      // Small additional delay so the PDF view itself can claim the
      // isolate first — extraction finishes well before the user can tap.
      _prefetchPageText(page0, delay: const Duration(milliseconds: 600));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        ref.read(streakStateProvider.notifier).recordOpen().then((res) {
          if (!mounted) return;
          // Mirror the streak count into the achievement counter so the
          // 3 / 7 / 30 day badges fire alongside the existing milestone
          // confetti on the home screen.
          if (res.count > 0) {
            try {
              final unlocks = ref
                  .read(achievementsProvider.notifier)
                  .record(AchievementEvent.streakReached(res.count));
              _showAchievementUnlocks(unlocks);
            } catch (_) {/* Hive not open */}
          }
        });
      } catch (e) {
        debugPrint('[streak] recordOpen failed: $e');
      }
    });
  }

  /// Reads `tts_rate` from the shared `app_prefs` Hive box on cold start.
  /// Stored value is the user-facing rate (1.0 = normal). Legacy values
  /// outside the 0.5-2.0 slider range are clamped on read so an old install
  /// that persisted 0.5 as "Android normal" doesn't lock the user at half-
  /// speed under the new platform-corrected math.
  void _restoreSpeechRate() {
    try {
      final box = Hive.box(RecentBooksService.boxName);
      final raw = box.get(_kTtsRateKey);
      if (raw is num) {
        _speechRate = raw.toDouble().clamp(0.5, 2.0);
      }
    } catch (_) {
      /* Hive not open — keep default. */
    }
  }

  /// Slider hook for the karaoke pane speed slider. Updates state, applies
  /// the platform-corrected engine rate, and persists. Realtime mid-utterance
  /// re-speak is wired separately in [_applyRateToActiveTts] so the karaoke
  /// pane can opt in via [onSpeedChange] without forcing a restart on every
  /// drag tick.
  void _setSpeechRate(double next) {
    final clamped = next.clamp(0.5, 2.0);
    if (mounted) {
      setState(() => _speechRate = clamped);
    } else {
      _speechRate = clamped;
    }
    // Best-effort engine update — flutter_tts swallows errors internally,
    // so we don't need a try/catch here.
    _tts.setSpeechRate(_engineRate);
    try {
      Hive.box(RecentBooksService.boxName).put(_kTtsRateKey, clamped);
    } catch (_) {
      /* Hive not open — silent, in-memory only. */
    }
    // Realtime apply: most engines do NOT honor setSpeechRate mid-utterance —
    // the new rate only takes effect on the next speak() call. Re-speak from
    // the current word/sentence so the user hears the change immediately.
    _applyRateToActiveTts();
  }

  /// Re-speak the current page (or remaining slice) so a mid-utterance rate
  /// change is audible without waiting for the next page. No-op when TTS is
  /// idle or paused. Reuses [_seekTtsTo] in word-mode (preserves highlight
  /// anchor) and [_speakCurrentPage] in sentence-fallback mode.
  void _applyRateToActiveTts() {
    if (!_ttsActive || !_ttsSpeaking) return;
    final s = ref.read(karaokeControllerProvider);
    if (s.fullText.isEmpty) return;
    if (s.fallbackSentenceMode) {
      // Sentence-mode: simplest correct path is a full restart of the
      // current page. _speakCurrentPage already detects fallback mode and
      // resumes via the sentence queue if a resume slot is set, but here
      // we want to reflect the current word, not restart from the top.
      _captureResume();
      final page = _currentPage > 0 ? _currentPage - 1 : 0;
      _speakCurrentPage(page);
      return;
    }
    // Word-mode: seek back to the currently-highlighted word so the new
    // rate kicks in mid-page without losing position. If no progress event
    // has fired yet (currentStart < 0), fall back to a full page restart.
    if (s.currentStart >= 0 && s.currentStart < s.fullText.length) {
      _seekTtsTo(s.currentStart);
    } else {
      final page = _currentPage > 0 ? _currentPage - 1 : 0;
      _speakCurrentPage(page);
    }
  }

  /// Records first-TTS-per-book for the Karaoke Star achievement (3 unique
  /// books). Idempotent within a screen lifetime via [_ttsCountedForBook].
  void _maybeRecordTtsForBook() {
    if (_ttsCountedForBook) return;
    _ttsCountedForBook = true;
    try {
      final unlocks = ref
          .read(achievementsProvider.notifier)
          .record(AchievementEvent.ttsUsedOnBook(widget.bookId));
      _showAchievementUnlocks(unlocks);
    } catch (_) {
      /* Hive not open in tests — silent. */
    }
  }

  /// Surfaces a one-shot snackbar for each newly-unlocked achievement and
  /// fires the existing confetti controller so the celebration matches the
  /// book-finish flow.
  void _showAchievementUnlocks(List<String> ids) {
    if (ids.isEmpty) return;
    if (!mounted) return;
    final svc = ref.read(achievementServiceProvider);
    for (final id in ids) {
      final ach = svc.findById(id);
      if (ach == null) continue;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(ach.icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Unlocked: ${ach.title}')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    _finishConfetti.play();
  }

  Future<void> _initTts() async {
    debugPrint('[TTS] init start, web=$kIsWeb');
    if (!kIsWeb) {
      try {
        final engines = await _tts.getEngines;
        debugPrint('[TTS] engines available: $engines');
        final defaultEngine = await _tts.getDefaultEngine;
        debugPrint('[TTS] default engine: $defaultEngine');
      } catch (e) {
        debugPrint('[TTS] engine query failed: $e');
      }
    }
    // setLanguage returns -1 (NOT_SUPPORTED) or -2 (MISSING_DATA) on devices
    // without English TTS pack — fall back to device default in that case.
    final langResult = await _tts.setLanguage('en-US');
    debugPrint('[TTS] setLanguage(en-US) returned: $langResult');
    if (langResult is int && langResult < 0) {
      final langs = await _tts.getLanguages;
      debugPrint('[TTS] available languages: $langs');
      final list = langs as List?;
      if (list != null && list.isNotEmpty) {
        // Prefer any English variant before random first locale.
        final en = list.firstWhere(
          (l) => l.toString().toLowerCase().startsWith('en'),
          orElse: () => list.first,
        );
        final r = await _tts.setLanguage(en.toString());
        debugPrint('[TTS] fallback setLanguage($en) returned: $r');
      }
    }

    if (kIsWeb) {
      await _trySetWebVoice();
    }
    // Mobile: rely on the system-default voice. Earlier attempts at name-
    // based ranking ("network"/"premium"/"enhanced") produced false-positive
    // matches on cheaper voices that happened to share a substring. Letting
    // the OS pick avoids a regression in audio quality compared to bare TTS.

    await _tts.setSpeechRate(_engineRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // Ensures speak() future resolves on actual completion, not immediately.
    // Without this, Android sometimes drops audio + completionHandler never fires.
    // The web plugin (flutter_tts 4.2.5) also supports awaitSpeakCompletion via
    // an internal Completer keyed off `utterance.onEnd` — enabling it on web
    // means our completion handler runs after the future resolves, removing a
    // race where natural completion arrived before `_ttsSpeaking = true` was
    // visible to the handler.
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
    // Karaoke word-boundary events. The handler signature is
    // (text, start, end, word) — `start`/`end` are char offsets into the
    // utterance we passed to speak(). When we speak the entire page in one
    // call (happy path), these offsets index `pageText` directly so we can
    // forward them straight to the controller.
    _tts.setProgressHandler((text, start, end, word) {
      if (_isDisposed || !mounted) return;
      _karaokeProgressEverFired = true;
      _karaokeProgressDetectTimer?.cancel();
      _karaokeProgressDetectTimer = null;
      ref
          .read(karaokeControllerProvider.notifier)
          .onProgress(text, start, end, word);
    });
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
      // Sentence-mode: a per-sentence speak() just finished. Advance to the
      // next sentence in the queue — page advance only when the queue empties.
      if (_karaokeSentences != null && _karaokeSentences!.isNotEmpty) {
        if (_speakNextSentence()) return;
      }
      // Page truly done — natural completion. Clear resume so a fresh
      // play after this point starts from the top, not from a stale offset.
      _clearResume();
      // Karaoke page boundary: page-level speak finished, clear active span.
      ref.read(karaokeControllerProvider.notifier).onTtsStop();
      // If the user hasn't pressed Stop, automatically continue to the next page.
      if (_ttsActive) _advanceToNextPageForTts();
    });
    _tts.setCancelHandler(() {
      if (_isDisposed || !mounted) return;
      // Self-induced cancel: a programmatic stop() above us is still
      // draining its echo. Skip mutation — the caller is already mid-
      // restart and will re-arm the karaoke span + speaking flag itself.
      // Without this guard the late cancel races the new speak() and
      // clobbers isSpeaking back to false (so progress events bail) and
      // wipes currentStart/currentEnd (so the highlight never appears on
      // a seek/resume).
      if (_isInProgrammaticStopWindow) return;
      setState(() => _ttsSpeaking = false);
      // Capture resume slot BEFORE onTtsStop() wipes currentStart/currentEnd.
      // Music-app behavior: next play picks up where we left off.
      _captureResume();
      // User-initiated stop. Clear the karaoke active span — page text
      // stays in the pane so the user can still scroll-read the last page.
      ref.read(karaokeControllerProvider.notifier).onTtsStop();
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
        // Same quiet-window check as the cancel handler. A programmatic
        // stop can surface here instead of in setCancelHandler depending
        // on the engine — both paths defer to the timestamp.
        debugPrint('[TTS] benign error ignored: $msg');
        return;
      }
      setState(() {
        _ttsActive = false;
        _ttsSpeaking = false;
      });
      // Capture resume before clearing the karaoke span — same as cancel path.
      _captureResume();
      ref.read(karaokeControllerProvider.notifier).onTtsStop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('TTS engine error: $msg')));
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
      debugPrint('[TTS] web voices found: ${voices?.length ?? 0}');
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
        if (name.contains('david') ||
            name.contains('mark') ||
            name.contains('guy') ||
            name.contains('alex')) {
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
        debugPrint('[TTS] web voice set: ${ranked.first['name']}');
      }
    } catch (_) {
      /* best-effort */
    }
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
    _tts.setProgressHandler((_, a, b, c) {});
    _tts.stop();
    _karaokeProgressDetectTimer?.cancel();
    _karaokeProgressDetectTimer = null;
    _karaokeSentences = null;
    _finishConfetti.dispose();
    // Release native PDF text-extractor handle on Android — leak otherwise.
    _pdfDoc = null;
    _webPdfBytes = null;
    _webPdfBytesKey = null;
    super.dispose();
  }

  void _onPageChanged(int? page, int? total) {
    if (page == null || total == null || page < 0) return;
    // New page = fresh start. Drop any pending resume slot before we possibly
    // kick off auto-advance speak below — otherwise a stale offset/sentence
    // index from the previous page could match the new page's text by sheer
    // coincidence and resume into the middle of the new page.
    _clearResume();
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
    if (total > 0 && page == total - 1) {
      final book = ref.read(bookByIdProvider(widget.bookId)).valueOrNull;
      if (book != null && book.status != 'finished') {
        ctrl.updateStatus(widget.bookId, 'finished');
      }
      // Confetti + snackbar on the very first time this book hits its end.
      // BookFinishService is idempotent: subsequent visits no-op.
      try {
        final svc = ref.read(bookFinishServiceProvider);
        svc.markFinished(widget.bookId).then((newlyMarked) {
          if (!mounted || !newlyMarked) return;
          _finishConfetti.play();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Finished!'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          // Achievement counters: First Steps + Bookworm. Only fired once
          // per book thanks to BookFinishService's idempotent guard.
          try {
            final unlocks = ref
                .read(achievementsProvider.notifier)
                .record(AchievementEvent.bookFinished());
            _showAchievementUnlocks(unlocks);
          } catch (_) {/* Hive not open */}
        });
      } catch (e) {
        // Hive box not open (e.g. test env without override) — silent.
        debugPrint('[book_finish] markFinished failed: $e');
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
    if (wasSpeakingBeforeStop) _markProgrammaticStop();
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
          const SnackBar(
            content: Text('PDF still loading, try again in a moment.'),
          ),
        );
        setState(() {
          _ttsActive = false;
          _ttsSpeaking = false;
        });
      }
      return;
    }

    String? pageText;
    try {
      // Cache-first extract. First call per page does the real work (~200-
      // 800ms on dense pages); subsequent calls and prefetched pages hit
      // the cache and return instantly. _extractPageText already does the
      // _cleanForTts pass before storing.
      pageText = await _extractPageText(pageIndex);
      if (v != _speakVersion) return;
      if (pageText == null) {
        if (mounted) {
          setState(() {
            _ttsActive = false;
            _ttsSpeaking = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'PDF file not accessible. Reopen the book and try again.',
              ),
            ),
          );
        }
        return;
      }
      if (pageText.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _ttsActive = false;
            _ttsSpeaking = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No readable text on this page (scanned PDF?)'),
            ),
          );
        }
        return;
      }
      // Music-app resume: if a previous stop captured a position on text
      // that matches this page's cleaned output, pick up from there instead
      // of restarting at the top. The tight string-equality guard ensures we
      // never resume into a different page (extraction differences = skip).
      if (_hasResume && _resumeFullText == pageText) {
        await _applyEngineConfigIfChanged();
        if (kIsWeb && !_webVoiceSet) {
          await _trySetWebVoice();
        }
        // Fallback-mode resume: re-split the page (deterministic for identical
        // text), aim the queue at the captured sentence index, kick it off.
        if (_resumeSentenceIndex > 0) {
          final sentences = _splitForKaraoke(pageText);
          if (sentences.isNotEmpty && _resumeSentenceIndex < sentences.length) {
            _karaokeSentences = sentences;
            _karaokeSentenceIndex = _resumeSentenceIndex;
            ref
                .read(karaokeControllerProvider.notifier)
                .onTtsStart(pageText, baseOffset: 0);
            ref.read(karaokeControllerProvider.notifier).enableFallbackMode();
            _clearResume();
            if (mounted) setState(() => _ttsSpeaking = true);
            if (!_speakNextSentence()) {
              // Defensive: queue couldn't advance — fall through next time.
              _karaokeSentences = null;
              if (mounted) {
                setState(() {
                  _ttsActive = false;
                  _ttsSpeaking = false;
                });
              }
            }
            return;
          }
          // Resume index out of bounds for current split — drop it and let
          // the normal speak path run from the page start.
          _clearResume();
        } else if (_resumeOffset > 0 && _resumeOffset < pageText.length) {
          // Word-mode resume: defer to _seekTtsTo which handles the slice
          // speak + baseOffset wiring. Clear before dispatch so the seek
          // doesn't see itself as a resume target.
          final offset = _resumeOffset;
          _clearResume();
          await _seekTtsTo(offset);
          return;
        }
      }
      await _applyEngineConfigIfChanged();
      // Web: voices populate asynchronously after first user gesture. Retry
      // voice selection here (after the Read button tap) if init missed it.
      if (kIsWeb && !_webVoiceSet) {
        await _trySetWebVoice();
      }
      // Karaoke: prime the pane with the page text BEFORE we kick off speak()
      // so the user sees the prose render even on slow first-tick engines.
      // baseOffset = 0: full-page speak, progress offsets index pageText
      // directly. _seekTtsTo() sets a non-zero baseOffset for slice speaks.
      ref
          .read(karaokeControllerProvider.notifier)
          .onTtsStart(pageText, baseOffset: 0);
      // Decide path: if a previous speak already failed to emit progress
      // events, we're in fallback mode for this page — drive sentence-by-
      // sentence instead. Otherwise speak the whole page and arm a 2s timer
      // that promotes us to fallback if no progress event ever lands.
      final karaokeState = ref.read(karaokeControllerProvider);
      if (karaokeState.fallbackSentenceMode) {
        // Sentence queue path. _speakNextSentence handles speak() itself.
        _karaokeSentences = _splitForKaraoke(pageText);
        _karaokeSentenceIndex = 0;
        if (mounted) setState(() => _ttsSpeaking = true);
        _maybeRecordTtsForBook();
        if (!_speakNextSentence()) {
          // Empty queue (no sentences extracted). Fall through to a single
          // page-level speak so the user still hears the page.
          _karaokeSentences = null;
          if (mounted) {
            setState(() {
              _ttsActive = false;
              _ttsSpeaking = false;
            });
          }
        }
        return;
      }
      // Word-progress path: arm fallback detection + speak whole page.
      _karaokeProgressEverFired = false;
      _karaokeProgressDetectTimer?.cancel();
      _karaokeProgressDetectTimer = Timer(const Duration(seconds: 2), () {
        if (_isDisposed || !mounted) return;
        if (_karaokeProgressEverFired) return;
        if (v != _speakVersion) return;
        // No progress events landed — promote to sentence mode for the next
        // page. We don't restart the current page mid-speak (jarring); the
        // *next* page will use sentence path automatically.
        debugPrint(
          '[TTS] no progress events after 2s, switching to sentence fallback',
        );
        ref.read(karaokeControllerProvider.notifier).enableFallbackMode();
      });
      if (mounted) setState(() => _ttsSpeaking = true);
      // Achievement: count the first time the user actually triggers TTS for
      // this book. Placed after all early-returns so a failed text-extract
      // doesn't burn the credit.
      _maybeRecordTtsForBook();
      // Prefetch the next page's text 3s later, after the engine has
      // stabilized on the current speak. Doing it immediately starves the
      // platform-channel progress callbacks because PDF text extraction
      // pegs the UI isolate, breaking the karaoke detect timer (no progress
      // events for 2s → fallback flips → tap-to-seek dies).
      _prefetchPageText(
        pageIndex + 1,
        delay: const Duration(seconds: 3),
      );
      // Diagnostic: extracted text length is a common failure mode (image-only PDFs).
      debugPrint(
        '[TTS] speaking ${pageText.length} chars, rate=$_speechRate pitch=$_pitch web=$kIsWeb',
      );
      final result = await _tts.speak(pageText);
      debugPrint(
        '[TTS] speak() returned: $result (version=$v, current=$_speakVersion)',
      );
      // With awaitSpeakCompletion(true), result==0 also fires on legitimate
      // interruption (stop() before completion). Don't surface as error.
    } catch (e) {
      _pdfDoc = null;
      _pageTextCache.clear();
      _pageTextInflight.clear();
      if (mounted) {
        setState(() {
          _ttsActive = false;
          _ttsSpeaking = false;
        });
        final msg = e.toString().contains('INVALID_PATH')
            ? 'Could not read PDF text. The file may be encrypted or scanned.'
            : 'TTS error: $e';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
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
    text = text.replaceAll(
      RegExp(r'-\s*\n\s*'),
      '',
    ); // "exam-\nple" -> "example"
    text = text.replaceAll(
      RegExp(r'(?<!\n)\n(?!\n)'),
      ' ',
    ); // single \n -> space
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    // Replace runs of broken-font glyphs / exotic symbols with a single space.
    // Keep printable ASCII, Latin supplement, Latin Extended-A, curly quotes,
    // en/em dashes, and newlines.
    text = text.replaceAll(RegExp(r"[^ -~ -ſ‘’“”–—\n]+"), ' ');
    text = text.replaceAll(RegExp(r' {2,}'), ' ');
    return text.trim();
  }

  /// Splits a page's text into sentence spans for the fallback karaoke path.
  /// Each entry knows its char offsets back into [pageText] so the controller
  /// can highlight the matching span in the karaoke pane.
  List<_KaraokeSentence> _splitForKaraoke(String pageText) {
    final out = <_KaraokeSentence>[];
    // Pattern: end of sentence punctuation followed by whitespace. We KEEP
    // the punctuation with the preceding sentence by splitting *after* it.
    // RegExp.allMatches gives us the boundary positions; we walk between
    // them to slice the text.
    final boundary = RegExp(r'(?<=[.!?])\s+');
    int cursor = 0;
    for (final m in boundary.allMatches(pageText)) {
      final end = m.start;
      if (end > cursor) {
        final slice = pageText.substring(cursor, end);
        if (slice.trim().isNotEmpty) {
          out.add(_KaraokeSentence(start: cursor, end: end, text: slice));
        }
      }
      cursor = m.end;
    }
    // Tail (no trailing punctuation, or last sentence).
    if (cursor < pageText.length) {
      final slice = pageText.substring(cursor);
      if (slice.trim().isNotEmpty) {
        out.add(
          _KaraokeSentence(start: cursor, end: pageText.length, text: slice),
        );
      }
    }
    return out;
  }

  /// Advances the sentence queue: pulls the next entry, emits a sentence-tick
  /// to the karaoke controller, and fires a single speak() for that sentence.
  /// Returns false if the queue is empty (caller should advance the page).
  bool _speakNextSentence() {
    final list = _karaokeSentences;
    if (list == null || list.isEmpty) return false;
    if (_karaokeSentenceIndex >= list.length) {
      _karaokeSentences = null;
      _karaokeSentenceIndex = 0;
      // Page finished — clear active span and let caller advance.
      // Natural completion of the page also clears the resume slot.
      _clearResume();
      ref.read(karaokeControllerProvider.notifier).onTtsStop();
      if (_ttsActive) _advanceToNextPageForTts();
      return true; // we handled the completion side-effect
    }
    final s = list[_karaokeSentenceIndex];
    _karaokeSentenceIndex++;
    ref.read(karaokeControllerProvider.notifier).onSentenceTick(s.start, s.end);
    if (mounted) setState(() => _ttsSpeaking = true);
    // Fire and forget. setCompletionHandler advances when this finishes.
    unawaited(_tts.speak(s.text));
    return true;
  }

  /// Click-to-seek: scrub TTS to the word at [wordStart] (a char offset within
  /// the current page's `KaraokeState.fullText`). Called from the karaoke
  /// pane's `_TappableWord.onTap`.
  ///
  /// Behavior:
  ///   - If currently speaking, stop and restart from [wordStart].
  ///   - If idle, start speaking from [wordStart] (auto-activates TTS).
  ///   - In word-progress mode: speak `fullText.substring(wordStart)` and tell
  ///     the controller `baseOffset = wordStart` so progress offsets re-anchor.
  ///   - In sentence-fallback mode: find the sentence containing [wordStart],
  ///     point the queue at it, kick off the next sentence speak.
  Future<void> _seekTtsTo(int wordStart) async {
    final state = ref.read(karaokeControllerProvider);
    final fullText = state.fullText;
    if (fullText.isEmpty) return;
    if (wordStart < 0 || wordStart >= fullText.length) return;

    final v = ++_speakVersion;
    // Cancel the detect timer — even if it hadn't fired yet, the new speak
    // re-arms its own (only when needed).
    _karaokeProgressDetectTimer?.cancel();
    _karaokeProgressDetectTimer = null;

    final wasSpeakingBeforeStop = _ttsSpeaking;
    if (mounted && _ttsSpeaking) {
      setState(() => _ttsSpeaking = false);
    } else {
      _ttsSpeaking = false;
    }
    if (wasSpeakingBeforeStop) _markProgrammaticStop();
    await _tts.stop();
    if (v != _speakVersion) return;
    // Web cancel is async — same workaround as _speakCurrentPage.
    if (kIsWeb && wasSpeakingBeforeStop) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (v != _speakVersion) return;
    }
    // Clear resume AFTER the stop+delay window: if the cancel handler fired
    // during await, it would have re-captured a stale offset (the word we
    // were on before the seek). The seek is the new "start point", so any
    // resume slot is invalidated. The next user-initiated stop captures
    // fresh from the seek position.
    _clearResume();

    if (state.fallbackSentenceMode) {
      // Sentence path: find which sentence contains the tapped word.
      final sentences = _karaokeSentences;
      if (sentences == null || sentences.isEmpty) return;
      int matchIndex = sentences.length - 1; // fall through to last
      for (int i = 0; i < sentences.length; i++) {
        final s = sentences[i];
        if (s.start <= wordStart && wordStart < s.end) {
          matchIndex = i;
          break;
        }
      }
      _karaokeSentenceIndex = matchIndex;
      // Mirror _speakCurrentPage: flip flags + re-pump the controller's
      // speaking state so the empty-state doesn't briefly flash.
      ref
          .read(karaokeControllerProvider.notifier)
          .onTtsStart(fullText, baseOffset: 0);
      ref.read(karaokeControllerProvider.notifier).enableFallbackMode();
      if (mounted) {
        setState(() {
          _ttsActive = true;
          _ttsSpeaking = true;
        });
      } else {
        _ttsActive = true;
        _ttsSpeaking = true;
      }
      // _speakNextSentence pulls list[_karaokeSentenceIndex] then ++s the
      // index, which is exactly what we want.
      _speakNextSentence();
      return;
    }

    // Word-progress path: slice the page text from the tapped word and let
    // the engine emit boundary events relative to the slice. baseOffset
    // shifts those offsets back to full-text coords inside the controller.
    final slice = fullText.substring(wordStart);
    if (slice.trim().isEmpty) return;
    ref
        .read(karaokeControllerProvider.notifier)
        .onTtsStart(fullText, baseOffset: wordStart);
    if (mounted) {
      setState(() {
        _ttsActive = true;
        _ttsSpeaking = true;
      });
    } else {
      _ttsActive = true;
      _ttsSpeaking = true;
    }
    // Only re-arm the 2 s detect timer if we've never confirmed progress
    // events for this engine. Once they've fired once, we trust them — no
    // need to chase fallback mode again on a seek.
    if (!_karaokeProgressEverFired) {
      _karaokeProgressDetectTimer = Timer(const Duration(seconds: 2), () {
        if (_isDisposed || !mounted) return;
        if (_karaokeProgressEverFired) return;
        if (v != _speakVersion) return;
        ref.read(karaokeControllerProvider.notifier).enableFallbackMode();
      });
    }
    debugPrint(
      '[TTS] seek: speaking ${slice.length} chars from offset $wordStart',
    );
    unawaited(_tts.speak(slice));
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
      // Capture resume FIRST — onTtsStop() below clears currentStart/currentEnd.
      // Music-app behavior: pressing Read again resumes from this point.
      _captureResume();
      // Flip flag BEFORE await stop() — completion handler races against this.
      // If we set after, completion can fire mid-await with _ttsActive still
      // true, triggering auto-advance and a runaway speak loop.
      setState(() {
        _ttsActive = false;
        _ttsSpeaking = false;
      });
      _speakVersion++; // invalidate any in-flight _speakCurrentPage
      _karaokeProgressDetectTimer?.cancel();
      _karaokeProgressDetectTimer = null;
      _karaokeSentences = null;
      ref.read(karaokeControllerProvider.notifier).onTtsStop();
      await _tts.stop();
    } else {
      setState(() => _ttsActive = true);
      // On web, the parent's `_currentPage` mirrors the web reader via
      // callback, but there's a brief startup window before scroll listener
      // fires. Query the web controller directly to avoid reading the
      // previous page (off-by-one) at the very first Read tap.
      int displayedPage;
      if (kIsWeb) {
        displayedPage =
            _webController.currentPage ??
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
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Speed', style: AppTypography.labelLarge),
                    const Spacer(),
                    Text(
                      '${(rate * 100).round()}%',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  // Range must match _setSpeechRate clamp (0.5-2.0) and the
                  // karaoke pane speed slider — otherwise opening this sheet
                  // after the user nudges karaoke speed past 1.0 throws a
                  // Slider value-out-of-range assertion.
                  value: rate.clamp(0.5, 2.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
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
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
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

  /// Karaoke pane mounted as a direct Stack child so Positioned works.
  /// Sliding-up panel rooted to the bottom of the reader area. The phone
  /// frame on web (412×896) is the canvas reference; on real mobile we use
  /// the actual MediaQuery height. ~42% gives ~10 lines at bodyMedium.
  Widget _buildKaraokePane(
    BuildContext context, {
    required bool isVisible,
  }) {
    final mq = MediaQuery.of(context);
    // Cap pane against the visible screen (clamp prevents the pane from
    // pushing past the top bar when the device is short — e.g. landscape).
    final paneHeight = (mq.size.height * 0.42).clamp(220.0, 520.0);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: isVisible ? 0 : -paneHeight,
      height: paneHeight,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: KaraokeTextPane(
          onWordTap: _seekTtsTo,
          currentSpeed: _speechRate,
          onSpeedChange: _setSpeechRate,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pdfAsync = book != null
        ? ref.watch(pdfPathProvider(book.link))
        : null;

    final progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;

    // Karaoke captions: feature-flagged via Remote Config. Default-on, can be
    // killed server-side without redeploy by flipping `karaoke_tts_enabled`.
    final karaokeEnabled = ref.watch(karaokeEnabledProvider);
    final karaokeState = ref.watch(karaokeControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFD8DADB),
      body: Stack(
        children: [
          // PDFView/loading must fill the stack — without Positioned.fill some
          // platform-view embeds collapse to 0x0 and render a blank surface.
          if (pdfAsync != null)
            Positioned.fill(
              child: pdfAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load PDF',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$e',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
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
                            if (pages != null) {
                              setState(() => _totalPages = pages);
                            }
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
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.canPop()
                                    ? context.pop()
                                    : context.go('/book/${widget.bookId}'),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: AppColors.primary,
                                  size: 20,
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
                                GestureDetector(
                                  onTap: _showVoiceSettings,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Icon(
                                      Icons.tune,
                                      size: 18,
                                      color: _ttsActive
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                // Karaoke captions toggle. Hidden when the
                                // Remote Config flag is off, providing the
                                // promised kill-switch without redeploy.
                                if (karaokeEnabled)
                                  Semantics(
                                    label: 'Toggle karaoke captions',
                                    button: true,
                                    child: GestureDetector(
                                      onTap: () => ref
                                          .read(
                                            karaokeControllerProvider.notifier,
                                          )
                                          .toggleVisible(),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Icon(
                                          karaokeState.isVisible
                                              ? Icons.subtitles
                                              : Icons.subtitles_outlined,
                                          size: 18,
                                          color: karaokeState.isVisible
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                GestureDetector(
                                  onTap: _toggleTts,
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _ttsActive
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
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
                                          style: AppTypography.bodySmall
                                              .copyWith(
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
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary,
                          ),
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
                        horizontal: 13,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCCF8FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x33BFC8CC)),
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

          // Karaoke captions pane: slide-up from the bottom edge. Animates off
          // when the user collapses it; off-screen sits at translateY(100%) so
          // the pane doesn't intercept taps while hidden. Height ~42% gives
          // enough room for ~10 lines on a 412×896 phone frame.
          // Use MediaQuery instead of LayoutBuilder so Positioned remains a
          // direct child of the Stack (LayoutBuilder breaks the parent-data
          // contract Positioned needs).
          if (karaokeEnabled)
            _buildKaraokePane(context, isVisible: karaokeState.isVisible),

          // First-finish confetti — purely decorative overlay above the PDF
          // and the karaoke pane. Excluded from a11y so screen readers don't
          // announce a stream of meaningless particles.
          ExcludeSemantics(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _finishConfetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                gravity: 0.3,
                maxBlastForce: 25,
                minBlastForce: 8,
                emissionFrequency: 0.05,
                shouldLoop: false,
                colors: const [AppColors.primary, AppColors.iconBlueTint],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A sentence span carved out of the page text for the fallback karaoke
/// path. `start`/`end` are char offsets back into the original page text so
/// the controller can highlight matching tokens in the pane.
class _KaraokeSentence {
  final int start;
  final int end;
  final String text;
  const _KaraokeSentence({
    required this.start,
    required this.end,
    required this.text,
  });
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
          child: Text(
            'Failed to load PDF: $_error',
            textAlign: TextAlign.center,
          ),
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

        if (!_jumpedToInitialPage &&
            widget.initialPage > 1 &&
            _totalPages > 0) {
          _jumpedToInitialPage = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(_itemHeight * (widget.initialPage - 1));
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
            itemBuilder: (ctx, i) =>
                _PdfPageImage(document: _document!, pageNumber: i + 1),
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


