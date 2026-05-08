import 'package:flutter/widgets.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import 'mobile_pdf_reader.dart';

/// Mobile (Android + iOS) implementation. This is the ONLY file in the
/// codebase allowed to import `package:flutter_pdfview/`.
Widget buildMobilePdfReader({
  Key? key,
  required String filePath,
  required ValueChanged<int?> onRender,
  required void Function(int? page, int? total) onPageChanged,
  required ValueChanged<MobilePdfReaderController> onControllerReady,
  required ValueChanged<Object> onError,
  required void Function(int? page, Object error) onPageError,
}) {
  return PDFView(
    key: key,
    filePath: filePath,
    enableSwipe: true,
    swipeHorizontal: false,
    autoSpacing: false,
    pageFling: false,
    pageSnap: false,
    fitPolicy: FitPolicy.WIDTH,
    onRender: onRender,
    onError: (e) => onError(e as Object),
    onPageError: (page, e) => onPageError(page, e as Object),
    onViewCreated: (controller) =>
        onControllerReady(_IoMobilePdfReaderController(controller)),
    onPageChanged: onPageChanged,
  );
}

/// Wraps a [PDFViewController] so the reader can call [setPage] without
/// pulling `package:flutter_pdfview` into its imports.
class _IoMobilePdfReaderController implements MobilePdfReaderController {
  _IoMobilePdfReaderController(this._inner);

  final PDFViewController _inner;

  @override
  Future<void> setPage(int pageIndex) async {
    await _inner.setPage(pageIndex);
  }
}
