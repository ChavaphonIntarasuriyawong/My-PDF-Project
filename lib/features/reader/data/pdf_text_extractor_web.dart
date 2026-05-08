import 'pdf_text_extractor.dart';

/// Factory used by the web branch of the conditional import in
/// `pdf_text_extractor.dart`. The web reader extracts text via Syncfusion
/// bytes directly inside [ReadingScreen]'s `kIsWeb` branch and never reaches
/// this code path. The stub exists solely to keep dart2js happy when
/// resolving the conditional import — `flutter_pdf_text` has no `web`
/// plugin platform and would otherwise fail compile.
Future<PdfTextExtractor> openPdfTextExtractor(String url) async {
  throw UnsupportedError(
    'Web reader uses Syncfusion bytes — see reading_screen kIsWeb branch.',
  );
}
