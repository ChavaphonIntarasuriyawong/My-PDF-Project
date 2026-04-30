import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/network/pdf_fetcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/pdf_metadata.dart';
import '../domain/book_model.dart';
import '../domain/bookshelf_model.dart';
import 'library_controller.dart';
import 'library_providers.dart';

class NewBookScreen extends ConsumerStatefulWidget {
  const NewBookScreen({super.key});

  @override
  ConsumerState<NewBookScreen> createState() => _NewBookScreenState();
}

class _NewBookScreenState extends ConsumerState<NewBookScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _urlCtrl = TextEditingController();
  String? _urlShelfId;
  bool _loadingUrl = false;

  PlatformFile? _pickedFile;
  String? _fileShelfId;
  bool _loadingFile = false;
  bool _urlImportError = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  String _titleFromSource(String source) {
    String segment = source.split('/').last.split('\\').last;
    if (segment.contains('?')) segment = segment.split('?').first;
    if (segment.toLowerCase().endsWith('.pdf')) {
      segment = segment.substring(0, segment.length - 4);
    }
    if (segment.isEmpty) return 'Untitled';
    segment = segment.replaceAll(RegExp(r'[_\-+]'), ' ').trim();
    final words = segment.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'Untitled';
    return words
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        // Web has no path; Android SAF may also return null path → need bytes.
        // Mobile keeps path-based read to avoid OOM on big PDFs.
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;
      setState(() => _pickedFile = result.files.first);
    } catch (e) {
      if (!mounted) return;
      _showError('Could not open file picker: $e');
    }
  }

  Future<Uint8List> _readPickedBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }
    if (kIsWeb) {
      throw Exception('Could not read file. Try picking it again.');
    }
    if (file.path == null) {
      throw Exception('File path unavailable. Try picking the file again.');
    }
    final source = File(file.path!);
    if (!await source.exists()) {
      throw Exception('File no longer accessible. Try picking it again.');
    }
    return source.readAsBytes();
  }

  Future<({String link, PdfMetadata metadata})> _uploadPdf(
      PlatformFile file, String uid) async {
    final bytes = await _readPickedBytes(file);
    if (bytes.isEmpty) {
      throw Exception('Picked file is empty.');
    }
    final metadata = extractPdfMetadata(bytes);
    final supabasePath = '$uid/${DateTime.now().millisecondsSinceEpoch}.pdf';
    final supabase = Supabase.instance.client;
    try {
      await supabase.storage.from('pdfs').uploadBinary(
            supabasePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ),
          );
    } on StorageException catch (e) {
      throw Exception('Storage error: ${e.message}');
    }
    final publicUrl =
        supabase.storage.from('pdfs').getPublicUrl(supabasePath);
    return (link: publicUrl, metadata: metadata);
  }

  Future<PdfMetadata> _validateAndExtractMetadata(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw Exception('Invalid URL scheme.');
    }
    // Browsers block cross-origin GET on most PDF hosts (CORS). Skip the probe
    // on web — we trust the URL and let the reader fetch it later. Metadata
    // (author/year) is unavailable in this path.
    if (kIsWeb) {
      return const PdfMetadata();
    }
    final resp = await http.get(uri).timeout(const Duration(seconds: 30),
        onTimeout: () => throw Exception('Link unreachable.'));
    if (resp.statusCode < 200 || resp.statusCode >= 400) {
      throw Exception('Link returned ${resp.statusCode}.');
    }
    final ct = (resp.headers['content-type'] ?? '').toLowerCase();
    final pathLooksPdf = uri.path.toLowerCase().endsWith('.pdf');
    if (!ct.contains('pdf') && !pathLooksPdf) {
      throw Exception('Link is not a PDF.');
    }
    return extractPdfMetadata(resp.bodyBytes);
  }

  /// Probe whether the PDF has any extractable text in its first few pages.
  /// Returns true if text layer is effectively empty (image-only / scanned).
  /// Throws on extraction failure so caller can decide to skip the warning.
  bool _isBitmapOnlyPdf(Uint8List bytes) {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final pageCount = doc.pages.count;
      final sample = pageCount > 3 ? 3 : pageCount;
      if (sample <= 0) return false;
      final extractor = PdfTextExtractor(doc);
      final text =
          extractor.extractText(startPageIndex: 0, endPageIndex: sample - 1);
      // Threshold of 5 chars handles PDFs with tiny incidental vector text.
      return text.trim().length < 5;
    } finally {
      doc.dispose();
    }
  }

  /// Show a non-blocking warning when PDF has no text layer.
  /// Returns true if user chose to continue, false if they cancelled.
  Future<bool> _confirmBitmapPdfUpload() async {
    final result = await showAppModal<bool>(
      context: context,
      builder: (ctx) => AppModal(
        title: 'No text layer detected',
        titleIcon: Icons.warning_amber_rounded,
        body: Text(
          "This PDF appears to be a scanned or image-only document. Text-to-Speech won't work for this book.",
          style: AppTypography.bodyMedium,
        ),
        confirmLabel: 'Continue anyway',
        onConfirm: () async {
          Navigator.of(ctx).pop(true);
        },
      ),
    );
    return result == true;
  }

  /// Run the bitmap probe on already-fetched bytes. On extraction error
  /// (encrypted/corrupt) log + skip the warning so upload isn't blocked.
  /// Returns true to proceed, false to abort.
  Future<bool> _checkTextLayerOrConfirm(Uint8List bytes) async {
    bool isBitmap;
    try {
      isBitmap = _isBitmapOnlyPdf(bytes);
    } catch (e) {
      // ignore: avoid_print
      print('[BitmapProbe] error: $e');
      return true;
    }
    if (!isBitmap) return true;
    if (!mounted) return false;
    return _confirmBitmapPdfUpload();
  }

  Future<void> _createFromUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _showError('Please paste a PDF URL.');
      return;
    }
    setState(() {
      _loadingUrl = true;
      _urlImportError = false;
    });
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    try {
      // _validateAndExtractMetadata fetches bytes via http.get on mobile only.
      // For the bitmap probe we share `fetchPdfBytes` so web routes through the
      // Supabase Edge `pdf-proxy` (CLAUDE.md: always go through fetchPdfBytes).
      // On probe fetch failure (proxy timeout, 404, server down) we log and
      // proceed without warning — never block import on probe failure.
      final metadata = await _validateAndExtractMetadata(url);
      try {
        final probeResp = await fetchPdfBytes(url);
        final shouldContinue =
            await _checkTextLayerOrConfirm(probeResp.bodyBytes);
        if (!shouldContinue) {
          if (!mounted) return;
          setState(() => _loadingUrl = false);
          return;
        }
      } catch (e) {
        // ignore: avoid_print
        print('[BitmapProbe] fetch error: $e');
      }
      final book = BookModel(
        id: '',
        title: _titleFromSource(url),
        link: url,
        totalPages: 0,
        currentPage: 0,
        progress: 0,
        status: 'reading',
        shelfId: _urlShelfId ?? '',
        ownerId: uid,
        author: metadata.author,
        year: metadata.year,
      );
      final created =
          await ref.read(libraryControllerProvider.notifier).createBook(book);
      if (!mounted) return;
      setState(() => _loadingUrl = false);
      if (created != null) {
        // Reset stack to /home, then push book info so back-button returns to library.
        context.go('/home');
        context.push('/book/${created.id}');
      } else {
        final err = ref.read(libraryControllerProvider).error;
        if (err != null) _showError(err.toString());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUrl = false;
        _urlImportError = true;
      });
      // Surface real cause — generic banner alone hides CORS/network/parse errors.
      final msg = e.toString().replaceAll('Exception: ', '');
      _showError('Import failed: $msg');
    }
  }

  Future<void> _createFromFile() async {
    if (_pickedFile == null) {
      _showError('Please choose a PDF file.');
      return;
    }
    setState(() => _loadingFile = true);
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    try {
      // Probe text layer before paying for the Supabase upload. Bytes are
      // available pre-upload on both mobile + web in this path.
      final probeBytes = await _readPickedBytes(_pickedFile!);
      final shouldContinue = await _checkTextLayerOrConfirm(probeBytes);
      if (!shouldContinue) {
        if (!mounted) return;
        setState(() => _loadingFile = false);
        return;
      }
      final saved = await _uploadPdf(_pickedFile!, uid);
      final book = BookModel(
        id: '',
        title: _titleFromSource(_pickedFile!.name),
        link: saved.link,
        totalPages: 0,
        currentPage: 0,
        progress: 0,
        status: 'reading',
        shelfId: _fileShelfId ?? '',
        ownerId: uid,
        author: saved.metadata.author,
        year: saved.metadata.year,
      );
      final created =
          await ref.read(libraryControllerProvider.notifier).createBook(book);
      if (!mounted) return;
      setState(() => _loadingFile = false);
      if (created != null) {
        // Reset stack to /home, then push book info so back-button returns to library.
        context.go('/home');
        context.push('/book/${created.id}');
      } else {
        final err = ref.read(libraryControllerProvider).error;
        if (err != null) _showError(err.toString());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFile = false);
      final msg = e.toString().replaceAll('Exception: ', '');
      _showError('Upload failed: $msg');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final shelves = ref.watch(shelvesProvider).valueOrNull ?? [];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: AppDrawer(
        active: NavSection.create,
        onClose: () => _scaffoldKey.currentState?.closeDrawer(),
      ),
      bottomNavigationBar: AppBottomNavBar(
        onTap: (tab) {
          if (tab == NavTab.library) context.go('/home');
          if (tab == NavTab.profile) context.push('/profile');
        },
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top app bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.menu,
                            color: AppColors.primary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('MYPDF',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: -0.9,
                          color: AppColors.primary,
                        )),
                  ],
                ),
              ),

              // ── Editorial header ────────────────────────────────────
              const SizedBox(height: 8),
              Text(
                'KNOWLEDGE ACQUISITION',
                style: AppTypography.labelSmall.copyWith(
                  color: const Color(0xFF4A626B),
                  fontSize: 18,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Curate your\nlocal library.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                  fontSize: 46,
                  letterSpacing: -1.2,
                  height: 1.25,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Transform raw data into meaningful intelligence. Connect your documents directly to your library.',
                style:
                    AppTypography.bodyLarge.copyWith(fontSize: 20, height: 1.6),
              ),
              const SizedBox(height: 32),

              // ── Card 1: Import PDF via Link ──────────────────────────
              _ImportCard(
                icon: Icons.link,
                title: 'Import PDF via Link',
                loading: _loadingUrl,
                onSubmit: _createFromUrl,
                submitLabel: 'Create PDF',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('PUBLIC PDF URL'),
                    const SizedBox(height: 8),
                    _InputContainer(
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(Icons.link,
                                color: AppColors.primary, size: 18),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _urlCtrl,
                              keyboardType: TextInputType.url,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'https://example.com/document.pdf',
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.5),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _FieldHelper(
                        'Paste a direct public PDF URL here to add it to your library.'),
                    const SizedBox(height: 20),
                    _ShelfDropdown(
                      shelves: shelves,
                      value: _urlShelfId,
                      onChanged: (v) => setState(() => _urlShelfId = v),
                    ),
                    const _FieldHelper(
                        'Choose a shelf to store your PDF file link.'),
                    if (_urlImportError) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This PDF link cannot be imported',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Card 2: Upload PDF file ──────────────────────────────
              _ImportCard(
                icon: Icons.upload,
                title: 'Upload PDF file',
                loading: _loadingFile,
                onSubmit: _createFromFile,
                submitLabel: 'Create PDF',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('PDF FILE'),
                    const SizedBox(height: 8),
                    _InputContainer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf_outlined,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _pickedFile?.name ?? 'example.pdf',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  color: _pickedFile != null
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted
                                          .withValues(alpha: 0.5),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_pickedFile != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _pickedFile = null),
                                child: const Icon(Icons.close,
                                    color: AppColors.textMuted, size: 18),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const _FieldHelper('Open your browser to upload the PDF file.'),
                    const SizedBox(height: 16),
                    // Browse button between file input and shelf selector
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _pickFile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Browse',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ShelfDropdown(
                      shelves: shelves,
                      value: _fileShelfId,
                      onChanged: (v) => setState(() => _fileShelfId = v),
                    ),
                    const _FieldHelper(
                        'Choose a shelf to store your PDF file link.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Import card wrapper ────────────────────────────────────────────────────────

class _ImportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool loading;
  final VoidCallback onSubmit;
  final String submitLabel;
  final Widget child;

  const _ImportCard({
    required this.icon,
    required this.title,
    required this.loading,
    required this.onSubmit,
    required this.child,
    this.submitLabel = 'Create PDF',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderNav),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF191C1D).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: loading ? null : onSubmit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            submitLabel,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward,
                              color: Colors.white, size: 16),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.55,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _FieldHelper extends StatelessWidget {
  final String text;
  const _FieldHelper(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.5,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _InputContainer extends StatelessWidget {
  final Widget child;
  const _InputContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _ShelfDropdown extends StatelessWidget {
  final List<BookshelfModel> shelves;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _ShelfDropdown({
    required this.shelves,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('SHELF'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: value,
              isExpanded: true,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 18,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
              dropdownColor: AppColors.surface,
              hint: const Text(
                'All',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 18,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'All',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 18,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                ...shelves.map((s) => DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(
                        s.name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 18,
                          height: 1.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    )),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
