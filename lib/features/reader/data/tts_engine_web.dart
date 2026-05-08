import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// Factory used by the web (`dart.library.js_interop`) branch of the
/// conditional import in `tts_engine.dart`. flutter_tts 4.2.5 ships a real
/// web plugin (`flutter_tts_web.dart` + `interop_types.dart`) registered
/// through `flutter_web_plugins`, so we can import the public entry point
/// and proxy through to it. Routing through this conditional file is what
/// keeps Linux dart2js (CI) from choking on the package's top-level
/// `dart:io` import — the same pattern that fixed `flutter_pdf_text` and
/// `flutter_pdfview` for the web build.
TtsEngine createTtsEngine() => _WebTtsEngine();

/// Web implementation. Proxies every call to a `FlutterTts` instance, with
/// two web-specific tweaks for the diagnostic getters [getEngines] and
/// [getDefaultEngine]: the Web Speech API has no concept of "TTS engines",
/// so we return `null` instead of letting the platform channel call fail
/// silently. Both getters are guarded by an `if (!kIsWeb)` block at the
/// reader's call site, so this branch is defensive only.
class _WebTtsEngine implements TtsEngine {
  final FlutterTts _inner = FlutterTts();

  @override
  Future<dynamic> get getEngines async => null;

  @override
  Future<dynamic> get getDefaultEngine async => null;

  @override
  Future<dynamic> get getLanguages => _inner.getLanguages;

  @override
  Future<dynamic> get getVoices => _inner.getVoices;

  @override
  Future<dynamic> setLanguage(String lang) => _inner.setLanguage(lang);

  @override
  Future<void> setSpeechRate(double rate) async {
    await _inner.setSpeechRate(rate);
  }

  @override
  Future<void> setVolume(double v) async {
    await _inner.setVolume(v);
  }

  @override
  Future<void> setPitch(double p) async {
    await _inner.setPitch(p);
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    await _inner.setVoice(voice);
  }

  @override
  Future<void> awaitSpeakCompletion(bool flag) async {
    await _inner.awaitSpeakCompletion(flag);
  }

  @override
  Future<dynamic> speak(String text) => _inner.speak(text);

  @override
  Future<void> stop() async {
    await _inner.stop();
  }

  @override
  void setProgressHandler(TtsProgressHandler h) {
    _inner.setProgressHandler(h);
  }

  @override
  void setCompletionHandler(void Function() h) {
    _inner.setCompletionHandler(h);
  }

  @override
  void setCancelHandler(void Function() h) {
    _inner.setCancelHandler(h);
  }

  @override
  void setErrorHandler(TtsErrorHandler h) {
    _inner.setErrorHandler(h);
  }
}
