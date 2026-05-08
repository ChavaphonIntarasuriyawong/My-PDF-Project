// Conditional import: the IO variant pulls `package:flutter_tts/flutter_tts.dart`
// behind a single, web-isolated file. The package itself declares web support
// (flutter_tts 4.2.5 ships a `flutter_tts_web.dart` plugin), but its public
// entry file imports `dart:io` at the top level. Linux dart2js (in CI)
// rejects that import in the web compile graph even though Windows local
// dart2js silently tolerates it. Routing through this conditional file is
// the same pattern we already use for `flutter_pdf_text` and `flutter_pdfview`
// — both implementations import the package, but the conditional indirection
// keeps each branch's resolution scoped to its own target platform.
import 'tts_engine_io.dart'
    if (dart.library.js_interop) 'tts_engine_web.dart'
    as impl;

/// Per-word boundary callback signature. Mirrors `flutter_tts`'s
/// `ProgressHandler`: `(text, startOffset, endOffset, currentWord)`.
typedef TtsProgressHandler =
    void Function(
      String text,
      int startOffset,
      int endOffset,
      String currentWord,
    );

/// Error callback signature. Mirrors `flutter_tts`'s `ErrorHandler` exactly
/// (the engine emits a `dynamic` payload — string on most platforms, Map on
/// older Android builds).
typedef TtsErrorHandler = void Function(dynamic msg);

/// Platform-agnostic facade over the `flutter_tts` plugin. The reader holds
/// a single instance for its lifetime and never imports the plugin directly.
///
/// Methods that the upstream plugin types as `Future<dynamic>` are kept that
/// way here so the reader's existing `langResult is int && langResult < 0`
/// pattern keeps compiling without runtime casts. Diagnostic-only getters
/// (`getEngines`, `getDefaultEngine`) are guarded inside a `kIsWeb` false
/// branch in [ReadingScreen] — the web impl returns `null` for both.
abstract class TtsEngine {
  /// Mobile diagnostic only — list of installed TTS engine packages. The
  /// web stub returns `null`; the reader call site is already inside an
  /// `if (!kIsWeb)` block.
  Future<dynamic> get getEngines;

  /// Mobile diagnostic only — currently selected engine package name. Web
  /// stub returns `null`; same call-site guard as [getEngines].
  Future<dynamic> get getDefaultEngine;

  /// List of supported language tags (`en-US`, `th-TH`, ...). Used as a
  /// fallback search when `setLanguage('en-US')` returns a negative status.
  /// The plugin types this `Future<dynamic>` (a `List` at runtime).
  Future<dynamic> get getLanguages;

  /// List of available voices. Each entry is a `Map<String, String>` with
  /// `name` + `locale` keys. Web populates this asynchronously after the
  /// first user gesture; mobile resolves synchronously.
  Future<dynamic> get getVoices;

  /// Sets the active language. Returns the upstream raw status — typically
  /// `int` on Android (-2 = MISSING_DATA, -1 = NOT_SUPPORTED, 0 = SUCCESS)
  /// and `null`/string elsewhere — as `Future<dynamic>` so the reader's
  /// `is int && < 0` check keeps working.
  Future<dynamic> setLanguage(String lang);

  /// Sets speech rate. Mobile expects 0.0–1.0; web uses the W3C
  /// SpeechSynthesis scale where 1.0 is "normal".
  Future<void> setSpeechRate(double rate);

  /// Sets output volume in the 0.0–1.0 range.
  Future<void> setVolume(double v);

  /// Sets pitch (1.0 is the unmodified voice).
  Future<void> setPitch(double p);

  /// Picks a specific voice by `{name, locale}` pair. Used on web to bias
  /// toward natural-sounding female voices.
  Future<void> setVoice(Map<String, String> voice);

  /// When `true`, the future returned by [speak] only resolves after the
  /// utterance actually finishes (or is cancelled). Required so our
  /// completion handler races correctly with `_ttsSpeaking` flips.
  Future<void> awaitSpeakCompletion(bool flag);

  /// Speaks [text]. Returns the upstream raw status as `Future<dynamic>`
  /// (Android returns `int` 1=success, web returns `null`).
  Future<dynamic> speak(String text);

  /// Cancels any in-flight utterance. The web SpeechSynthesis cancel is
  /// asynchronous — the reader inserts a brief delay after this on web.
  Future<void> stop();

  /// Per-word boundary handler. The upstream API stores a single handler;
  /// calling this replaces any previous handler.
  void setProgressHandler(TtsProgressHandler h);

  /// Natural-end completion handler (utterance finished without cancel).
  void setCompletionHandler(void Function() h);

  /// User-cancel handler (matches `_tts.stop()` invocations).
  void setCancelHandler(void Function() h);

  /// Engine-error handler. Web SpeechSynthesis fires "interrupted"/"canceled"
  /// here on every stop() — the reader filters those out before surfacing
  /// to the user.
  void setErrorHandler(TtsErrorHandler h);
}

/// Constructs the platform-appropriate [TtsEngine]. Selection happens at
/// compile time via the conditional import above so callers don't branch.
TtsEngine createTtsEngine() => impl.createTtsEngine();
