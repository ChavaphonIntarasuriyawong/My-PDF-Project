import 'package:flutter/widgets.dart';

import 'mobile_pdf_reader.dart';

/// Web stub. Never executes at runtime — the reader's `kIsWeb` branch swaps
/// in `_WebPdfReader` instead of calling [buildMobilePdfReader]. The stub
/// exists solely to keep dart2js happy when resolving the conditional
/// import; `flutter_pdfview` has no `web` plugin platform.
Widget buildMobilePdfReader({
  Key? key,
  required String filePath,
  required ValueChanged<int?> onRender,
  required void Function(int? page, int? total) onPageChanged,
  required ValueChanged<MobilePdfReaderController> onControllerReady,
  required ValueChanged<Object> onError,
  required void Function(int? page, Object error) onPageError,
}) => const SizedBox.shrink();
