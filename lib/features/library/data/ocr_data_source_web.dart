import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

import 'ocr_data_source.dart';

/// Factory used by the conditional import in `ocr_data_source.dart` when the
/// target platform exposes `dart:js_interop` (i.e. Flutter web).
OcrDataSource createOcrDataSource() => WebOcrDataSource();

// ---------------------------------------------------------------------------
// Web implementation - Tesseract.js v5 inside a Web Worker
// ---------------------------------------------------------------------------

/// `dart:js_interop` representation of the `Tesseract` global created by
/// `web/ocr/tesseract.min.js`. We type only the surface we use.
@JS('Tesseract')
external _TesseractGlobal get _tesseract;

extension type _TesseractGlobal._(JSObject _) implements JSObject {
  /// `createWorker(langs, oem, options)` - returns a `Promise[Worker]`.
  /// `langs` is an array of language codes; `oem` is the engine mode (1 =
  /// LSTM-only).
  external JSPromise<JSObject> createWorker(
    JSArray<JSString> langs,
    int oem,
    JSObject options,
  );
}

/// Methods we call on the resolved worker handle.
extension type _TesseractWorker._(JSObject _) implements JSObject {
  /// Returns a `Promise[RecognizeResult]`. The result has `.data.text`.
  external JSPromise<JSObject?> recognize(JSAny image);
  external JSPromise<JSAny?> terminate();

  /// Sets Tesseract engine parameters (e.g. `tessedit_pageseg_mode`).
  external JSPromise<JSAny?> setParameters(JSObject params);
}

/// Web implementation. Lazy-loads `web/ocr/tesseract.min.js` via a
/// `<script>` tag on first `recognize` call, then spawns a Tesseract.js
/// Web Worker pre-loaded with English + Thai trained data. The worker is
/// cached for the life of the datasource (creation cost is ~5 s; reuse
/// dwarfs recreate).
///
/// Browser-only APIs touched: `document.head`, `HTMLScriptElement`,
/// `Blob`, `URL.createObjectURL`. All wrapped via `package:web` so a
/// future Wasm Flutter target keeps compiling.
class WebOcrDataSource implements OcrDataSource {
  Future<void>? _scriptLoadFuture;
  Future<_TesseractWorker>? _workerFuture;
  bool _disposed = false;

  static const String _scriptUrl = 'ocr/tesseract.min.js';
  static const String _scriptId = 'mypdf-tesseract-js-loader';

  @override
  Future<String> recognize(
    Uint8List imageBytes, {
    String langs = 'eng+tha',
  }) async {
    if (_disposed) {
      throw StateError('WebOcrDataSource has been disposed.');
    }

    await _ensureScriptLoaded();
    final worker = await _ensureWorker(langs);

    // Build a Blob URL the worker can fetch directly. We can't pass the
    // raw Uint8List across the worker boundary efficiently, and Blob URLs
    // are revocable so memory pressure stays bounded.
    final blob = web.Blob(
      [imageBytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );
    final url = web.URL.createObjectURL(blob);

    try {
      final resultJs = await worker.recognize(url.toJS).toDart;
      if (resultJs == null) return '';
      // Walk `result.data.text`. Use nullable getProperty to guard against
      // undefined — Tesseract.js can resolve with an empty result object.
      final data = resultJs.getProperty<JSObject?>('data'.toJS);
      if (data == null) return '';
      final textJs = data.getProperty<JSString?>('text'.toJS);
      if (textJs == null) return '';
      return textJs.toDart;
    } finally {
      web.URL.revokeObjectURL(url);
    }
  }

  Future<void> _ensureScriptLoaded() {
    return _scriptLoadFuture ??= _loadScriptOnce();
  }

  Future<void> _loadScriptOnce() async {
    // If a previous datasource instance (or hot-restart) already injected
    // the script, the global is present and we can short-circuit.
    if (web.document.getElementById(_scriptId) != null &&
        _tesseract.isDefinedAndNotNull) {
      return;
    }

    final completer = Completer<void>();
    final script = web.HTMLScriptElement()
      ..id = _scriptId
      ..src = _scriptUrl
      ..async = true;

    script.addEventListener(
      'load',
      ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS,
    );
    script.addEventListener(
      'error',
      ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError(
              'Failed to load Tesseract.js from $_scriptUrl - '
              'see web/ocr/README.md for the asset download instructions.',
            ),
          );
        }
      }).toJS,
    );

    web.document.head!.appendChild(script);
    await completer.future;
  }

  Future<_TesseractWorker> _ensureWorker(String langs) {
    return _workerFuture ??= _spawnWorker(langs);
  }

  Future<_TesseractWorker> _spawnWorker(String langs) async {
    // Tesseract.js takes an array of language codes (separate items, not a
    // `+`-joined string like the native lib).
    final langArray = langs
        .split('+')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final jsLangs = langArray.map((l) => l.toJS).toList().toJS;

    // OEM=1 -> LSTM-only (best accuracy on modern traineddata).
    // workerPath is relative to the page (main thread resolves it).
    // corePath / langPath are resolved by the worker relative to its own
    // script URL (/ocr/worker.min.js), so they must be absolute paths.
    //
    // corePath must end with ".js": the worker detects SIMD at runtime and
    // appends a variant name only when corePath is a bare directory.  Since
    // we only ship tesseract-core-simd-lstm.wasm.js, we pass the full path so
    // the worker uses it directly and skips variant auto-selection entirely.
    // lstmOnly=true is a redundant belt-and-suspenders flag for the same reason.
    final options = JSObject();
    options.setProperty('workerPath'.toJS, 'ocr/worker.min.js'.toJS);
    options.setProperty(
      'corePath'.toJS,
      '/ocr/tesseract-core-simd-lstm.wasm.js'.toJS,
    );
    options.setProperty('langPath'.toJS, '/ocr/lang/'.toJS);
    options.setProperty('lstmOnly'.toJS, true.toJS);

    final workerJs = await _tesseract.createWorker(jsLangs, 1, options).toDart;
    final worker = _TesseractWorker._(workerJs);

    // PSM 6 = single uniform block of text. Skips layout analysis, which
    // improves both speed and accuracy for the single-column scanned book
    // pages this app processes. Default (PSM 3 = auto) tends to split
    // columns incorrectly on dense text pages.
    final params = JSObject();
    params.setProperty('tessedit_pageseg_mode'.toJS, '6'.toJS);
    await worker.setParameters(params).toDart;

    return worker;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final wf = _workerFuture;
    _workerFuture = null;
    if (wf == null) return;
    try {
      final worker = await wf;
      await worker.terminate().toDart;
    } catch (_) {
      // Best-effort: a half-spawned worker may not terminate cleanly.
    }
  }
}

extension on _TesseractGlobal? {
  bool get isDefinedAndNotNull => this != null;
}
