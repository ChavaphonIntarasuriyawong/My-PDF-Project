import 'package:flutter/widgets.dart';

// Conditional import: the IO variant pulls in `package:flutter_pdfview`
// (Android/iOS only); the web stub returns a `SizedBox.shrink()` and is
// never reached at runtime because the reader's `kIsWeb` branch swaps in
// `_WebPdfReader`. This isolates the mobile-only plugin from dart2js so the
// web build resolves cleanly.
import 'mobile_pdf_reader_io.dart'
    if (dart.library.js_interop) 'mobile_pdf_reader_web.dart'
    as impl;

/// Platform-agnostic handle exposed back to [ReadingScreen] so it can drive
/// the underlying `PDFViewController` (mobile) without importing the plugin
/// directly.
abstract class MobilePdfReaderController {
  /// Jumps to [pageIndex] (0-indexed, matching `PDFView.setPage` semantics).
  /// The underlying plugin returns `Future<bool?>`; we widen to `Future<void>`
  /// because callers don't inspect the result.
  Future<void> setPage(int pageIndex);
}

/// Constructs the platform-appropriate `PDFView` widget. All callbacks are
/// forwarded verbatim from the original `flutter_pdfview` API surface so the
/// reader doesn't have to change its handler shapes.
Widget buildMobilePdfReader({
  Key? key,
  required String filePath,
  required ValueChanged<int?> onRender,
  required void Function(int? page, int? total) onPageChanged,
  required ValueChanged<MobilePdfReaderController> onControllerReady,
  required ValueChanged<Object> onError,
  required void Function(int? page, Object error) onPageError,
}) => impl.buildMobilePdfReader(
  key: key,
  filePath: filePath,
  onRender: onRender,
  onPageChanged: onPageChanged,
  onControllerReady: onControllerReady,
  onError: onError,
  onPageError: onPageError,
);
