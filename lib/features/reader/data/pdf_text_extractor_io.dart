import 'package:flutter_pdf_text/flutter_pdf_text.dart';

import 'pdf_text_extractor.dart';

/// Factory used by the default branch of the conditional import in
/// `pdf_text_extractor.dart` (mobile / desktop / VM tests). This is the
/// ONLY file in the codebase allowed to import `package:flutter_pdf_text/`.
Future<PdfTextExtractor> openPdfTextExtractor(String path) async {
  return _IoPdfTextExtractor(await PDFDoc.fromPath(path));
}

/// Mobile (Android + iOS) implementation backed by the `flutter_pdf_text`
/// plugin. Wraps a [PDFDoc] handle and delegates page-level text extraction
/// through the same method-channel API the reader has used historically.
class _IoPdfTextExtractor implements PdfTextExtractor {
  _IoPdfTextExtractor(this._doc);

  final PDFDoc _doc;

  @override
  int get length => _doc.length;

  @override
  Future<String> pageText(int pageNumber) => _doc.pageAt(pageNumber).text;

  @override
  void dispose() {
    // No-op: `flutter_pdf_text` exposes no explicit teardown. The reader
    // nulls its reference so the wrapper (and the underlying PDFDoc) can be
    // garbage-collected on the next cycle.
  }
}
