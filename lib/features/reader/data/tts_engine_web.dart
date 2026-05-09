import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'tts_engine.dart';

TtsEngine createTtsEngine() => _WebSpeechTtsEngine();

/// Web implementation of [TtsEngine] backed by the browser's built-in
/// Web Speech API (window.speechSynthesis + SpeechSynthesisUtterance).
///
/// Replaces the previous no-op stub so TTS actually works on web. The reading
/// screen's existing kIsWeb guards, 120 ms cancel delay, _trySetWebVoice retry
/// loop, and karaoke-boundary plumbing remain unchanged — this engine wires
/// into all of them.
class _WebSpeechTtsEngine implements TtsEngine {
  String _lang = 'en-US';
  double _rate = 1.0;
  double _volume = 1.0;
  double _pitch = 1.0;
  String? _voiceName;
  bool _awaitCompletion = false;

  TtsProgressHandler? _progressHandler;
  void Function()? _completionHandler;
  void Function()? _cancelHandler;
  TtsErrorHandler? _errorHandler;

  // Tracks the completer for the currently active speak() call. Nulled by
  // stop() so that a late-arriving browser "interrupted" onerror can't
  // accidentally complete a subsequent speak()'s future (the local closure
  // variable also guards this independently via isCompleted).
  Completer<void>? _activeCompleter;

  web.SpeechSynthesis get _synth => web.window.speechSynthesis;

  @override
  Future<dynamic> get getEngines async => null;

  @override
  Future<dynamic> get getDefaultEngine async => null;

  @override
  Future<dynamic> get getLanguages async {
    return _synth.getVoices().toDart.map((v) => v.lang).toSet().toList();
  }

  @override
  Future<dynamic> get getVoices async {
    return _synth
        .getVoices()
        .toDart
        .map((v) => <String, String>{'name': v.name, 'locale': v.lang})
        .toList();
  }

  @override
  Future<dynamic> setLanguage(String lang) async {
    _lang = lang;
    return 1;
  }

  @override
  Future<void> setSpeechRate(double rate) async => _rate = rate;

  @override
  Future<void> setVolume(double v) async => _volume = v;

  @override
  Future<void> setPitch(double p) async => _pitch = p;

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    _voiceName = voice['name'];
  }

  @override
  Future<void> awaitSpeakCompletion(bool flag) async => _awaitCompletion = flag;

  @override
  Future<dynamic> speak(String text) async {
    // Cancel any in-flight utterance before queuing the new one.
    _synth.cancel();

    final utter = web.SpeechSynthesisUtterance(text);
    utter.lang = _lang;
    utter.rate = _rate;
    utter.volume = _volume;
    utter.pitch = _pitch;

    // Match the stored voice name against the live voice list. The reading
    // screen retries _trySetWebVoice on every speak() call (kIsWeb branch),
    // so _voiceName is set before we get here on most browsers.
    if (_voiceName != null) {
      final voices = _synth.getVoices().toDart;
      final match = voices.where((v) => v.name == _voiceName).firstOrNull;
      if (match != null) utter.voice = match;
    }

    final completer = Completer<void>();
    _activeCompleter = completer;

    // Natural end — utterance ran to completion without cancel.
    utter.addEventListener(
      'end',
      ((web.SpeechSynthesisEvent _) {
        if (completer.isCompleted) return;
        completer.complete();
        _completionHandler?.call();
      }).toJS,
    );

    // Error — covers both benign "interrupted"/"canceled" (from stop()) and
    // real failures. Route "interrupted"/"canceled" to _cancelHandler so
    // _ttsSpeaking is cleared correctly; the reading screen already filters
    // those strings in its _errorHandler and would silently skip the state
    // reset if we sent them there instead.
    utter.addEventListener(
      'error',
      ((web.SpeechSynthesisErrorEvent e) {
        if (completer.isCompleted) return;
        completer.complete();
        final code = e.error.toString();
        if (code == 'interrupted' || code == 'canceled') {
          _cancelHandler?.call();
        } else {
          _errorHandler?.call(code);
        }
      }).toJS,
    );

    // Word-boundary events drive karaoke highlighting. Firefox omits
    // charLength (returns 0) — fall back to scanning ahead for whitespace.
    utter.addEventListener(
      'boundary',
      ((web.SpeechSynthesisEvent e) {
        if (e.name != 'word') return;
        final start = e.charIndex;
        int len = e.charLength;
        if (len <= 0) {
          final rest = text.substring(start);
          final spaceAt = rest.indexOf(RegExp(r'\s'));
          len = spaceAt > 0 ? spaceAt : rest.length;
        }
        final end = (start + len).clamp(0, text.length);
        _progressHandler?.call(text, start, end, text.substring(start, end));
      }).toJS,
    );

    _synth.speak(utter);

    if (_awaitCompletion) {
      await completer.future;
    }
    return 1;
  }

  @override
  Future<void> stop() async {
    // Complete the active speak()-awaited completer immediately so
    // `await _tts.stop()` in the reading screen returns before the browser's
    // asynchronous "interrupted" onerror fires. The onerror handler's
    // isCompleted guard prevents a double-completion.
    final c = _activeCompleter;
    _activeCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete();
      _cancelHandler?.call();
    }
    _synth.cancel();
  }

  @override
  void setProgressHandler(TtsProgressHandler h) => _progressHandler = h;

  @override
  void setCompletionHandler(void Function() h) => _completionHandler = h;

  @override
  void setCancelHandler(void Function() h) => _cancelHandler = h;

  @override
  void setErrorHandler(TtsErrorHandler h) => _errorHandler = h;
}
