import 'dart:io' show File;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

import 'ocr_data_source.dart';

/// Factory used by the default branch of the conditional import in
/// `ocr_data_source.dart` (mobile / desktop / VM tests).
OcrDataSource createOcrDataSource() => MobileOcrDataSource();

/// Mobile (Android + iOS) implementation backed by the `tesseract_ocr`
/// plugin. The plugin's API takes a file path on disk, so we materialise
/// the JPEG bytes to the OS temp dir, run recognition, and clean up.
///
/// Trained data: the plugin auto-copies `assets/tessdata/*.traineddata`
/// to `${appDocs}/tessdata/` on first call. The user must drop the
/// `.traineddata` files into `assets/tessdata/` before building - see
/// `assets/tessdata/README.md`.
class MobileOcrDataSource implements OcrDataSource {
  final Random _rand = Random.secure();

  @override
  Future<String> recognize(
    Uint8List jpegBytes, {
    String langs = 'eng+tha',
  }) async {
    if (kIsWeb) {
      // Defensive: provider already kIsWeb-branches, but a future direct
      // instantiation must fail loudly instead of crashing on dart:io.
      throw UnsupportedError(
        'MobileOcrDataSource is not available on web; use WebOcrDataSource.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final filename =
        'ocr_${DateTime.now().millisecondsSinceEpoch}_${_rand.nextInt(1 << 32)}.jpg';
    final tempFile = File('${tempDir.path}/$filename');

    try {
      // For large payloads (>2 MB), do the file write off-isolate to avoid
      // hitching the UI thread (per CLAUDE.md performance gate). Tesseract
      // recognition itself runs on a native worker thread inside the plugin,
      // so we don't need to wrap the whole pipeline.
      if (jpegBytes.lengthInBytes > 2 * 1024 * 1024) {
        await compute(
          _writeBytesIsolate,
          _WriteBytesArgs(tempFile.path, jpegBytes),
        );
      } else {
        await tempFile.writeAsBytes(jpegBytes, flush: true);
      }

      try {
        final result = await TesseractOcr.extractText(
          tempFile.path,
          config: OCRConfig(language: langs, engine: OCREngine.tesseract),
        );
        return result;
      } catch (e) {
        // Surface a clearer error if the underlying issue is missing
        // traineddata - the plugin reports it as "Data path must not be
        // null!" or "Unable to load asset" depending on platform.
        final msg = e.toString();
        if (msg.contains('Data path must not be null') ||
            msg.contains('Unable to load asset') ||
            msg.contains('traineddata')) {
          throw StateError(
            'Tesseract language data missing - see assets/tessdata/README.md',
          );
        }
        rethrow;
      }
    } finally {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {
        /* best-effort cleanup */
      }
    }
  }

  @override
  Future<void> dispose() async {
    // The `tesseract_ocr` plugin uses a static method-channel API; the
    // native `TessBaseAPI` is allocated and released per-call inside the
    // plugin's Java/Swift code. Nothing to tear down on the Dart side.
  }
}

/// Argument record for [_writeBytesIsolate] - needs to be a top-level
/// type for `compute()` to send across the isolate boundary.
class _WriteBytesArgs {
  final String path;
  final Uint8List bytes;
  const _WriteBytesArgs(this.path, this.bytes);
}

/// Top-level so it's eligible for `compute()`.
Future<void> _writeBytesIsolate(_WriteBytesArgs args) async {
  await File(args.path).writeAsBytes(args.bytes, flush: true);
}
