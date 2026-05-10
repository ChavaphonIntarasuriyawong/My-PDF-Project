// Checks web/ocr/ for required Tesseract.js assets and downloads any that are
// missing. Safe to re-run — skips files that already exist.
//
// Usage:  dart run tool/setup_web_ocr.dart
//
// Run this once per machine before `flutter run -d chrome` or
// `flutter build web`. The CI workflow runs it automatically.

import 'dart:io';

// Direct-download assets (saved as-is).
const _files = <String, String>{
  'web/ocr/tesseract.min.js':
      'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js',
  'web/ocr/worker.min.js':
      'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/worker.min.js',
  'web/ocr/tesseract-core-simd-lstm.wasm.js':
      'https://cdn.jsdelivr.net/npm/tesseract.js-core@5/tesseract-core-simd-lstm.wasm.js',
};

// Raw .traineddata files — fetched then gzip-compressed in-process so we
// don't need the `gzip` CLI tool on the machine.
const _langFiles = <String, String>{
  'web/ocr/lang/eng.traineddata.gz':
      'https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata',
  'web/ocr/lang/tha.traineddata.gz':
      'https://github.com/tesseract-ocr/tessdata_best/raw/main/tha.traineddata',
};

Future<void> main() async {
  var allPresent = true;

  for (final entry in _files.entries) {
    if (File(entry.key).existsSync()) continue;
    allPresent = false;
    _log('Downloading ${entry.key} ...');
    final bytes = await _fetchBytes(entry.value);
    _writeFile(entry.key, bytes);
  }

  for (final entry in _langFiles.entries) {
    if (File(entry.key).existsSync()) continue;
    allPresent = false;
    _log('Downloading + compressing ${entry.key} ...');
    final raw = await _fetchBytes(entry.value);
    final gz = GZipCodec().encode(raw);
    _writeFile(entry.key, gz);
  }

  if (allPresent) {
    _log('All Tesseract.js assets present — nothing to do.');
  } else {
    _log('Done. All assets downloaded.');
  }
}

void _writeFile(String path, List<int> bytes) {
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  _log('  -> $path (${bytes.length} bytes)');
}

Future<List<int>> _fetchBytes(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} for $url');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return bytes;
  } finally {
    client.close(force: false);
  }
}

void _log(String msg) => stdout.writeln('[ocr-setup] $msg');
