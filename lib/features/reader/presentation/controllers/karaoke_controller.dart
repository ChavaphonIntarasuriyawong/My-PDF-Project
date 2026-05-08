import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable state for the TTS karaoke side-pane.
///
/// `currentStart`/`currentEnd` are character offsets into [fullText] for
/// the word currently being spoken. `[-1, -1]` means "no active word"
/// (idle, between words, or in fallback sentence mode before first tick).
@immutable
class KaraokeState {
  /// Full text being spoken on the current page.
  final String fullText;

  /// Inclusive start char offset of the current word (or sentence in fallback
  /// mode). `-1` when no active span.
  final int currentStart;

  /// Exclusive end char offset of the current word/sentence. `-1` when none.
  final int currentEnd;

  /// Pane visibility toggle. The pane mounts on demand; this flag controls
  /// whether the slide-up overlay is animated open.
  final bool isVisible;

  /// True while the engine is actively producing speech for [fullText].
  /// Drives empty-state vs. content rendering.
  final bool isSpeaking;

  /// True when word-level [setProgressHandler] events haven't fired in time
  /// (typical on web SpeechSynthesis when the voice doesn't emit `boundary`).
  /// In this mode, [onSentenceTick] drives sentence-granularity highlights.
  final bool fallbackSentenceMode;

  /// Char offset within [fullText] where the currently-spoken slice begins.
  /// Non-zero after a click-to-seek: we issue `speak(fullText.substring(N))`
  /// and the engine reports progress offsets relative to that slice. We add
  /// [baseOffset] back when forwarding to the pane so highlights stay aligned
  /// with the un-sliced [fullText] coordinate space.
  final int baseOffset;

  const KaraokeState({
    this.fullText = '',
    this.currentStart = -1,
    this.currentEnd = -1,
    this.isVisible = false,
    this.isSpeaking = false,
    this.fallbackSentenceMode = false,
    this.baseOffset = 0,
  });

  KaraokeState copyWith({
    String? fullText,
    int? currentStart,
    int? currentEnd,
    bool? isVisible,
    bool? isSpeaking,
    bool? fallbackSentenceMode,
    int? baseOffset,
  }) {
    return KaraokeState(
      fullText: fullText ?? this.fullText,
      currentStart: currentStart ?? this.currentStart,
      currentEnd: currentEnd ?? this.currentEnd,
      isVisible: isVisible ?? this.isVisible,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      fallbackSentenceMode: fallbackSentenceMode ?? this.fallbackSentenceMode,
      baseOffset: baseOffset ?? this.baseOffset,
    );
  }

  bool get hasActiveSpan => currentStart >= 0 && currentEnd > currentStart;
}

/// Controller for the karaoke side-pane.
///
/// Wired from [ReadingScreen]'s TTS handlers:
/// - [onTtsStart] called immediately before each `_tts.speak(pageText)`.
/// - [onProgress] mirrors `setProgressHandler((text, start, end, word))`.
/// - [onSentenceTick] used only when [enableFallbackMode] has flipped the mode.
/// - [onTtsStop] called from completion / cancel / error handlers.
class KaraokeController extends StateNotifier<KaraokeState> {
  KaraokeController() : super(const KaraokeState());

  /// Reset for a new utterance and capture the full text. Keeps current
  /// visibility (don't auto-close the pane) and resets fallback mode for a
  /// fresh detection window — each speak gets one chance to emit progress
  /// events before the timer flips us into sentence mode.
  ///
  /// [baseOffset] is the char offset within [fullText] where the slice we
  /// passed to `_tts.speak()` begins. When the seek path issues
  /// `speak(fullText.substring(wordStart))`, set [baseOffset] = wordStart so
  /// progress offsets get re-anchored to the full-text coordinate space the
  /// pane renders. Defaults to 0 for normal full-page speak.
  ///
  /// Preserves [fullText] when the caller passes the same string — pane
  /// keeps its tokens cached. Pass an empty string to clear.
  void onTtsStart(String fullText, {int baseOffset = 0}) {
    state = state.copyWith(
      fullText: fullText,
      currentStart: -1,
      currentEnd: -1,
      isSpeaking: true,
      fallbackSentenceMode: false,
      baseOffset: baseOffset,
    );
  }

  /// Word-level progress event from the TTS engine. The engine reports
  /// offsets relative to the chunk it's speaking; we add [baseOffset] back
  /// so the pane's highlight tracks against the full-page text coordinates,
  /// not the sliced substring (matters after a click-to-seek mid-page).
  void onProgress(String text, int start, int end, String word) {
    if (!state.isSpeaking) return;
    if (start < 0 || end <= start) return;
    state = state.copyWith(
      currentStart: start + state.baseOffset,
      currentEnd: end + state.baseOffset,
    );
  }

  /// Fallback path: highlight a whole sentence span. Called from the sentence
  /// queue in the reader screen when [fallbackSentenceMode] is true.
  void onSentenceTick(int sentenceStart, int sentenceEnd) {
    if (!state.isSpeaking) return;
    if (sentenceStart < 0 || sentenceEnd <= sentenceStart) return;
    state = state.copyWith(
      currentStart: sentenceStart,
      currentEnd: sentenceEnd,
    );
  }

  /// Switch to sentence-level highlighting. Called from a 2 s timer that
  /// fires if no [onProgress] event arrived after speak().
  void enableFallbackMode() {
    if (state.fallbackSentenceMode) return;
    state = state.copyWith(fallbackSentenceMode: true);
  }

  /// Clear active span + speaking flag. Pane visibility is preserved so the
  /// user can keep reading the last extracted page; full-text reset happens
  /// only on the next [onTtsStart].
  void onTtsStop() {
    state = state.copyWith(currentStart: -1, currentEnd: -1, isSpeaking: false);
  }

  void toggleVisible() {
    state = state.copyWith(isVisible: !state.isVisible);
  }

  void show() {
    if (state.isVisible) return;
    state = state.copyWith(isVisible: true);
  }

  void hide() {
    if (!state.isVisible) return;
    state = state.copyWith(isVisible: false);
  }
}

/// Auto-disposes when the reader screen unmounts. Kept alive across pane
/// visibility toggles because the screen itself reads the provider in `build`.
final karaokeControllerProvider =
    StateNotifierProvider.autoDispose<KaraokeController, KaraokeState>(
      (ref) => KaraokeController(),
    );
