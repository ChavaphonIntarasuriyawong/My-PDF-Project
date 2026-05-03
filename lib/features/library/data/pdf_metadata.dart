import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfMetadata {
  final String? author;
  final int? year;

  const PdfMetadata({this.author, this.year});
}

/// Reads author + creation-year from the embedded PDF document info dictionary.
/// Returns nulls if metadata is missing or the bytes don't parse — never throws.
PdfMetadata extractPdfMetadata(Uint8List bytes) {
  try {
    final doc = PdfDocument(inputBytes: bytes);
    final info = doc.documentInformation;
    final rawAuthor = info.author.trim();
    final author = rawAuthor.isEmpty ? null : rawAuthor;
    final year = info.creationDate.year;
    doc.dispose();
    // PDF default creationDate is 2001-01-01 when unset — treat that as missing.
    final reasonableYear = (year < 1970 || year > DateTime.now().year + 1) ? null : year;
    return PdfMetadata(author: author, year: reasonableYear);
  } catch (_) {
    return const PdfMetadata();
  }
}
