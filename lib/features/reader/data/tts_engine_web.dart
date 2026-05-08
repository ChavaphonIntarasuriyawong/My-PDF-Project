import 'tts_engine.dart';

/// Web factory used by the `dart.library.js_interop` branch of the conditional
/// import in `tts_engine.dart`. Linux dart2js refuses to resolve
/// `package:flutter_tts/flutter_tts.dart` even from a web-side conditional
/// file (the package's public entrypoint pulls in a kernel chain dart2js
/// rejects on Linux runners), so the web build cannot import flutter_tts at
/// all. Result: web TTS is a no-op until the upstream package or dart2js
/// behaviour changes. This is the deliberately-deferred R1 documented in
/// the swift-stirring-mccarthy plan.
TtsEngine createTtsEngine() => _NoopTtsEngine();

/// Pure no-op implementation — every method completes without doing anything.
/// The reader's `kIsWeb` paths still call into these and behave as if TTS is
/// inactive: `speak()` returns 0, handlers are stored but never invoked,
/// `setVoice`/`setLanguage`/etc. complete trivially.
class _NoopTtsEngine implements TtsEngine {
  @override
  Future<dynamic> get getEngines async => null;

  @override
  Future<dynamic> get getDefaultEngine async => null;

  @override
  Future<dynamic> get getLanguages async => const <String>[];

  @override
  Future<dynamic> get getVoices async => const <Map<String, String>>[];

  @override
  Future<dynamic> setLanguage(String lang) async => 1;

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setVolume(double v) async {}

  @override
  Future<void> setPitch(double p) async {}

  @override
  Future<void> setVoice(Map<String, String> voice) async {}

  @override
  Future<void> awaitSpeakCompletion(bool flag) async {}

  @override
  Future<dynamic> speak(String text) async => 0;

  @override
  Future<void> stop() async {}

  @override
  void setProgressHandler(TtsProgressHandler h) {}

  @override
  void setCompletionHandler(void Function() h) {}

  @override
  void setCancelHandler(void Function() h) {}

  @override
  void setErrorHandler(TtsErrorHandler h) {}
}
