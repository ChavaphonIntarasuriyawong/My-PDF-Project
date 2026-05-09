import 'dart:typed_data';

// Conditional import: the IO variant is the default; web compiles in the
// js_interop variant. This keeps `dart:js_interop` / `package:web` out of
// the VM build so Flutter test (which targets the Dart VM) can load this
// library without crashing on missing platform libs.
import 'ocr_data_source_io.dart'
    if (dart.library.js_interop) 'ocr_data_source_web.dart'
    as impl;

/// Datasource that runs OCR on a rendered page image and returns the
/// recognised text.
///
/// Wave 2 wires real engines: the `tesseract_ocr` plugin on mobile
/// (Android Tesseract4Android, iOS SwiftyTesseract) and Tesseract.js v5
/// in a Web Worker on web. Both implementations accept the same
/// `eng+tha`-style language string so callers don't branch.
abstract class OcrDataSource {
  /// Recognise text in [imageBytes] (PNG preferred for lossless input).
  /// [langs] is a `+`-joined Tesseract language pack list, defaulting to
  /// English + Thai per the user-locked decisions.
  Future<String> recognize(Uint8List imageBytes, {String langs = 'eng+tha'});

  /// Tear down any worker / FFI handles. Called from `ref.onDispose` on the
  /// provider that owns the singleton.
  Future<void> dispose();
}

/// Constructs the platform-appropriate [OcrDataSource]. Selection happens
/// at compile time via the conditional import above, so callers don't need
/// `kIsWeb` branching.
OcrDataSource createOcrDataSource() => impl.createOcrDataSource();
