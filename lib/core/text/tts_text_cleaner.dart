/// Cleans PDF-extracted (or OCR'd) text so a TTS engine reads it like prose:
///   - joins broken hyphenated words across lines
///   - turns single line breaks into spaces (engines pause on `\n`)
///   - keeps double newlines as paragraph breaks
///   - strips control chars and page-numberish noise the extractor emits
///   - skips runs of unreadable symbols (often left over from images / glyphs)
///
/// Pure Dart — safe for both reader and OCR pipeline (mobile + web).
String cleanForTts(String raw) {
  var text = raw.replaceAll('\r', '\n');
  text = text.replaceAll(RegExp(r'-\s*\n\s*'), ''); // "exam-\nple" -> "example"
  text = text.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' '); // single \n -> space
  text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
  // Replace runs of broken-font glyphs / exotic symbols with a single space.
  // Keep printable ASCII, Latin supplement, Latin Extended-A, curly quotes,
  // en/em dashes, and newlines.
  text = text.replaceAll(
      RegExp(r"[^ -~ -ſ‘’“”–—\n]+"),
      ' ');
  text = text.replaceAll(RegExp(r' {2,}'), ' ');
  return text.trim();
}
