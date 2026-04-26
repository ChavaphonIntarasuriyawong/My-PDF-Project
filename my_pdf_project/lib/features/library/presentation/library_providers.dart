import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import '../data/firestore_data_source.dart';
import '../domain/book_model.dart';
import '../domain/bookshelf_model.dart';
import '../domain/note_model.dart';
import '../../auth/presentation/auth_providers.dart';

final firestoreDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  return FirestoreDataSource(ref.watch(firestoreProvider));
});

final shelvesProvider = StreamProvider<List<BookshelfModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreDataSourceProvider).watchShelves(uid);
});

final booksByShelfProvider = StreamProvider.family<List<BookModel>, String>((ref, shelfId) {
  return ref.watch(firestoreDataSourceProvider).watchBooksByShelf(shelfId);
});

final allBooksProvider = StreamProvider<List<BookModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreDataSourceProvider).watchBooks(uid);
});

final notesByBookProvider = StreamProvider.family<List<NoteModel>, String>((ref, bookId) {
  return ref.watch(firestoreDataSourceProvider).watchNotesByBookId(bookId);
});

final noteByIdProvider = FutureProvider.family<NoteModel?, String>((ref, noteId) {
  return ref.watch(firestoreDataSourceProvider).getNoteById(noteId);
});

final bookByIdProvider = StreamProvider.family<BookModel?, String>((ref, bookId) {
  return ref.watch(firestoreDataSourceProvider).watchBook(bookId);
});

final userNotesCountProvider = StreamProvider<int>((ref) {
  final books = ref.watch(allBooksProvider).valueOrNull ?? [];
  final bookIds = books.map((b) => b.id).toList();
  return ref.watch(firestoreDataSourceProvider).watchUserNotesCount(bookIds);
});

/// PDF spec lets up to ~1024 bytes of garbage precede the `%PDF-` header.
/// Scan the first 1100 bytes for the signature.
bool _looksLikePdf(List<int> bytes) {
  final limit = bytes.length < 1100 ? bytes.length : 1100;
  for (var i = 0; i < limit - 3; i++) {
    if (bytes[i] == 0x25 &&
        bytes[i + 1] == 0x50 &&
        bytes[i + 2] == 0x44 &&
        bytes[i + 3] == 0x46) {
      return true;
    }
  }
  return false;
}

/// Downloads a PDF URL to a local file and returns the path.
/// Stored in application documents (NOT temp) so Android doesn't purge it
/// between download and the native PDFView open call (causes ENOENT).
final pdfPathProvider = FutureProvider.family<String, String>((ref, url) async {
  final docs = await getApplicationDocumentsDirectory();

  // local:// marker means the PDF was saved locally at upload time — no download.
  if (url.startsWith('local://')) {
    final filename = url.substring('local://'.length);
    final localFile = File('${docs.path}/local_pdfs/$filename');
    if (!await localFile.exists()) {
      throw Exception(
          'This PDF is stored on another device and is not available here.');
    }
    return localFile.absolute.path;
  }

  final file = File('${docs.path}/pdf_${url.hashCode.abs()}.pdf');

  if (await file.exists()) {
    if (await file.length() > 100) {
      final raf = await file.open();
      try {
        final head = await raf.read(1100);
        if (_looksLikePdf(head)) return file.absolute.path;
      } finally {
        await raf.close();
      }
    }
    await file.delete();
  }

  final response = await http
      .get(
    Uri.parse(url),
    headers: const {
      'User-Agent': 'Mozilla/5.0 (Mobile; MyPDF) AppleWebKit/537.36',
      'Accept': 'application/pdf,*/*',
    },
  )
      .timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw Exception(
        'PDF download timed out after 30s. Check your network or the URL.'),
  );
  if (response.statusCode != 200) {
    throw Exception(
        'Download failed (HTTP ${response.statusCode}). Make sure the URL is publicly accessible.');
  }
  if (response.bodyBytes.length < 100) {
    throw Exception('Downloaded file is too small to be a PDF.');
  }
  if (!_looksLikePdf(response.bodyBytes)) {
    final ct = response.headers['content-type'] ?? 'unknown';
    throw Exception(
        'URL did not return a PDF (content-type: $ct). For Google Drive use the direct download link, not the share preview.');
  }
  await file.writeAsBytes(response.bodyBytes, flush: true);

  // Verify write actually landed on disk before returning the path.
  if (!await file.exists()) {
    throw Exception('Failed to write PDF to ${file.path}');
  }
  final size = await file.length();
  if (size < 100) {
    throw Exception('Wrote PDF but size is only $size bytes');
  }
  return file.absolute.path;
});

/// Renders the first page of a PDF as JPEG bytes (cached to disk).
final pdfThumbnailProvider = FutureProvider.family<Uint8List?, String>((ref, url) async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final thumbsDir = Directory('${docs.path}/thumbs');
    if (!await thumbsDir.exists()) {
      await thumbsDir.create(recursive: true);
    }
    final thumbFile = File('${thumbsDir.path}/thumb_${url.hashCode.abs()}.jpg');
    if (await thumbFile.exists()) return await thumbFile.readAsBytes();

    final pdfPath = await ref.read(pdfPathProvider(url).future);
    final document = await PdfDocument.openFile(pdfPath);
    final page = await document.getPage(1);
    final pageImage = await page.render(
      width: page.width,
      height: page.height,
      format: PdfPageImageFormat.jpeg,
    );
    await page.close();
    await document.close();

    final bytes = pageImage?.bytes;
    if (bytes != null) await thumbFile.writeAsBytes(bytes);
    return bytes;
  } catch (_) {
    return null;
  }
});
