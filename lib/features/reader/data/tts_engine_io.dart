import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// Factory used by the default branch of the conditional import in
/// `tts_engine.dart` (mobile + desktop + VM tests). This is the ONLY file
/// in the codebase allowed to import `package:flutter_tts/flutter_tts.dart`
/// outside of the web stub.
TtsEngine createTtsEngine() => _IoTtsEngine();

/// Mobile / VM implementation. Wraps a `FlutterTts` instance and proxies
/// every call through unchanged. The plugin's `dart:io` import resolves
/// fine here because this file is only pulled into the IO compile graph
/// (default branch of the conditional import).
class _IoTtsEngine implements TtsEngine {
  final FlutterTts _inner = FlutterTts();

  @override
  Future<dynamic> get getEngines => _inner.getEngines;

  @override
  Future<dynamic> get getDefaultEngine => _inner.getDefaultEngine;

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
