// Conditional import: the IO variant is the default; web compiles in the
// js_interop variant. This keeps `package:flutter_pdf_text` (mobile-only,
// Android/iOS plugin platforms) out of the dart2js compile graph so the
// web build resolves cleanly.
import 'pdf_text_extractor_io.dart'
    if (dart.library.js_interop) 'pdf_text_extractor_web.dart'
    as impl;

/// Lightweight platform-agnostic facade over the mobile `flutter_pdf_text`
/// API. Used by the reader's TTS path on mobile to pull per-page text out of
/// a local PDF file. The web reader uses Syncfusion bytes directly and never
/// constructs an extractor, so the web impl is a stub that throws if called.
abstract class PdfTextExtractor {
  /// Total number of pages in the document.
  int get length;

  /// Returns the extracted text of [pageNumber] (1-indexed, matching
  /// `flutter_pdf_text`'s `PDFDoc.pageAt(n)` convention).
  Future<String> pageText(int pageNumber);

  /// Tear-down hook. The mobile impl is a no-op (the underlying plugin has no
  /// explicit dispose); callers should still null their reference so the GC
  /// can collect the instance.
  void dispose();
}

/// Opens the PDF at [pathOrUrl] and returns a platform-appropriate
/// [PdfTextExtractor]. On mobile [pathOrUrl] is a local file path; the web
/// stub throws if invoked because the web reader never reaches this code
/// path.
Future<PdfTextExtractor> openPdfTextExtractor(String pathOrUrl) =>
    impl.openPdfTextExtractor(pathOrUrl);
