import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../auth/presentation/auth_providers.dart';
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
        withData: false, // avoid OOM for large PDFs; bytes read from path at upload time
      );
      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;
      setState(() => _pickedFile = result.files.first);
    } catch (e) {
      if (!mounted) return;
      _showError('Could not open file picker: $e');
    }
  }

  Future<String> _uploadPdfFile(PlatformFile file, String uid) async {
    if (file.path == null) {
      throw Exception('File path unavailable. Try picking the file again.');
    }
    final localFile = File(file.path!);
    if (!await localFile.exists()) {
      throw Exception('File no longer accessible. Try picking it again.');
    }
    final size = await localFile.length();
    if (size == 0) {
      throw Exception('Picked file is empty.');
    }

    // Supabase storage requires an authenticated session even with the anon key.
    // App uses Firebase Auth — sign into Supabase anonymously so RLS allows the upload.
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) {
      try {
        await supabase.auth.signInAnonymously();
      } on AuthException catch (e) {
        throw Exception(
            'Supabase anonymous sign-in failed: ${e.message}. Enable Anonymous Sign-In in your Supabase Auth settings, or add an insert policy to the "pdfs" bucket that allows the anon role.');
      } catch (_) {
        // Other errors — try upload anyway in case bucket has open insert policy.
      }
    }

    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.pdf';
    try {
      await supabase.storage
          .from('pdfs')
          .upload(
            path,
            localFile,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw Exception(
                'Upload timed out after 60s. Check your network and that the "pdfs" bucket exists.'),
          );
    } on StorageException catch (e) {
      final code = e.statusCode ?? '';
      String hint;
      if (code == '404') {
        hint = 'Bucket "pdfs" not found — create it in Supabase Storage.';
      } else if (code == '403' || code == '401') {
        hint = 'Permission denied — add an INSERT policy on bucket "pdfs" for the anon role, OR enable Anonymous Sign-In.';
      } else if (code == '413') {
        hint = 'File too large for the bucket.';
      } else {
        hint = e.message;
      }
      throw Exception('Storage error ($code): $hint');
    }
    return supabase.storage.from('pdfs').getPublicUrl(path);
  }

  Future<void> _validatePdfUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw Exception('Invalid URL scheme.');
    }
    final resp = await http
        .head(uri)
        .timeout(const Duration(seconds: 10),
            onTimeout: () => throw Exception('Link unreachable.'));
    if (resp.statusCode < 200 || resp.statusCode >= 400) {
      throw Exception('Link returned ${resp.statusCode}.');
    }
    final ct = (resp.headers['content-type'] ?? '').toLowerCase();
    final pathLooksPdf = uri.path.toLowerCase().endsWith('.pdf');
    if (!ct.contains('pdf') && !pathLooksPdf) {
      throw Exception('Link is not a PDF.');
    }
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
      await _validatePdfUrl(url);
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingUrl = false;
        _urlImportError = true;
      });
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
      final link = await _uploadPdfFile(_pickedFile!, uid);
      final book = BookModel(
        id: '',
        title: _titleFromSource(_pickedFile!.name),
        link: link,
        totalPages: 0,
        currentPage: 0,
        progress: 0,
        status: 'reading',
        shelfId: _fileShelfId ?? '',
        ownerId: uid,
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
