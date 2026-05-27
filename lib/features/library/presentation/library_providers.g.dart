// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firestoreDataSourceHash() =>
    r'6e23ee21a9c4d7cf36f3e5426e4f6b1d5c576b79';

/// See also [firestoreDataSource].
@ProviderFor(firestoreDataSource)
final firestoreDataSourceProvider = Provider<FirestoreDataSource>.internal(
  firestoreDataSource,
  name: r'firestoreDataSourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firestoreDataSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirestoreDataSourceRef = ProviderRef<FirestoreDataSource>;
String _$recentBooksServiceHash() =>
    r'e626f3f0a3dc4c2c6205409f5e2e308caae13b71';

/// See also [recentBooksService].
@ProviderFor(recentBooksService)
final recentBooksServiceProvider = Provider<RecentBooksService>.internal(
  recentBooksService,
  name: r'recentBooksServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recentBooksServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentBooksServiceRef = ProviderRef<RecentBooksService>;
String _$recentBookIdsHash() => r'a74f91a3b85f95b6895f59a8146066ea43363dbd';

/// Reactive stream of locally-stored recent book IDs (most recent first).
///
/// Copied from [recentBookIds].
@ProviderFor(recentBookIds)
final recentBookIdsProvider = StreamProvider<List<String>>.internal(
  recentBookIds,
  name: r'recentBookIdsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recentBookIdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentBookIdsRef = StreamProviderRef<List<String>>;
String _$recentBooksHash() => r'51af9382f662ad05991c0b1fe11aab156227810c';

/// Joins recent IDs with current books, drops missing (e.g. deleted) entries,
/// preserves recency order.
///
/// Copied from [recentBooks].
@ProviderFor(recentBooks)
final recentBooksProvider = Provider<List<BookModel>>.internal(
  recentBooks,
  name: r'recentBooksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recentBooksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentBooksRef = ProviderRef<List<BookModel>>;
String _$shelvesHash() => r'6285b773a04eed78bbf185906eee0560639428af';

/// See also [shelves].
@ProviderFor(shelves)
final shelvesProvider = StreamProvider<List<BookshelfModel>>.internal(
  shelves,
  name: r'shelvesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$shelvesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ShelvesRef = StreamProviderRef<List<BookshelfModel>>;
String _$booksByShelfHash() => r'b236bacf88e5bca01104864efac34c127ef88553';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [booksByShelf].
@ProviderFor(booksByShelf)
const booksByShelfProvider = BooksByShelfFamily();

/// See also [booksByShelf].
class BooksByShelfFamily extends Family<AsyncValue<List<BookModel>>> {
  /// See also [booksByShelf].
  const BooksByShelfFamily();

  /// See also [booksByShelf].
  BooksByShelfProvider call(String shelfId) {
    return BooksByShelfProvider(shelfId);
  }

  @override
  BooksByShelfProvider getProviderOverride(
    covariant BooksByShelfProvider provider,
  ) {
    return call(provider.shelfId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'booksByShelfProvider';
}

/// See also [booksByShelf].
class BooksByShelfProvider extends StreamProvider<List<BookModel>> {
  /// See also [booksByShelf].
  BooksByShelfProvider(String shelfId)
    : this._internal(
        (ref) => booksByShelf(ref as BooksByShelfRef, shelfId),
        from: booksByShelfProvider,
        name: r'booksByShelfProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$booksByShelfHash,
        dependencies: BooksByShelfFamily._dependencies,
        allTransitiveDependencies:
            BooksByShelfFamily._allTransitiveDependencies,
        shelfId: shelfId,
      );

  BooksByShelfProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.shelfId,
  }) : super.internal();

  final String shelfId;

  @override
  Override overrideWith(
    Stream<List<BookModel>> Function(BooksByShelfRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BooksByShelfProvider._internal(
        (ref) => create(ref as BooksByShelfRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        shelfId: shelfId,
      ),
    );
  }

  @override
  StreamProviderElement<List<BookModel>> createElement() {
    return _BooksByShelfProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BooksByShelfProvider && other.shelfId == shelfId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, shelfId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BooksByShelfRef on StreamProviderRef<List<BookModel>> {
  /// The parameter `shelfId` of this provider.
  String get shelfId;
}

class _BooksByShelfProviderElement
    extends StreamProviderElement<List<BookModel>>
    with BooksByShelfRef {
  _BooksByShelfProviderElement(super.provider);

  @override
  String get shelfId => (origin as BooksByShelfProvider).shelfId;
}

String _$allBooksHash() => r'69f14b2a0c8630df7d7f90c454dac6dc9c2c9c10';

/// See also [allBooks].
@ProviderFor(allBooks)
final allBooksProvider = StreamProvider<List<BookModel>>.internal(
  allBooks,
  name: r'allBooksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$allBooksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AllBooksRef = StreamProviderRef<List<BookModel>>;
String _$notesByBookHash() => r'8b5e5506ac170877f74e58ecec5b873274df636f';

/// See also [notesByBook].
@ProviderFor(notesByBook)
const notesByBookProvider = NotesByBookFamily();

/// See also [notesByBook].
class NotesByBookFamily extends Family<AsyncValue<List<NoteModel>>> {
  /// See also [notesByBook].
  const NotesByBookFamily();

  /// See also [notesByBook].
  NotesByBookProvider call(String bookId) {
    return NotesByBookProvider(bookId);
  }

  @override
  NotesByBookProvider getProviderOverride(
    covariant NotesByBookProvider provider,
  ) {
    return call(provider.bookId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'notesByBookProvider';
}

/// See also [notesByBook].
class NotesByBookProvider extends StreamProvider<List<NoteModel>> {
  /// See also [notesByBook].
  NotesByBookProvider(String bookId)
    : this._internal(
        (ref) => notesByBook(ref as NotesByBookRef, bookId),
        from: notesByBookProvider,
        name: r'notesByBookProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$notesByBookHash,
        dependencies: NotesByBookFamily._dependencies,
        allTransitiveDependencies: NotesByBookFamily._allTransitiveDependencies,
        bookId: bookId,
      );

  NotesByBookProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.bookId,
  }) : super.internal();

  final String bookId;

  @override
  Override overrideWith(
    Stream<List<NoteModel>> Function(NotesByBookRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: NotesByBookProvider._internal(
        (ref) => create(ref as NotesByBookRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        bookId: bookId,
      ),
    );
  }

  @override
  StreamProviderElement<List<NoteModel>> createElement() {
    return _NotesByBookProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is NotesByBookProvider && other.bookId == bookId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, bookId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin NotesByBookRef on StreamProviderRef<List<NoteModel>> {
  /// The parameter `bookId` of this provider.
  String get bookId;
}

class _NotesByBookProviderElement extends StreamProviderElement<List<NoteModel>>
    with NotesByBookRef {
  _NotesByBookProviderElement(super.provider);

  @override
  String get bookId => (origin as NotesByBookProvider).bookId;
}

String _$noteByIdHash() => r'9eedd1c95e511f02905159580191c3a9c88057fa';

/// See also [noteById].
@ProviderFor(noteById)
const noteByIdProvider = NoteByIdFamily();

/// See also [noteById].
class NoteByIdFamily extends Family<AsyncValue<NoteModel?>> {
  /// See also [noteById].
  const NoteByIdFamily();

  /// See also [noteById].
  NoteByIdProvider call(String noteId) {
    return NoteByIdProvider(noteId);
  }

  @override
  NoteByIdProvider getProviderOverride(covariant NoteByIdProvider provider) {
    return call(provider.noteId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'noteByIdProvider';
}

/// See also [noteById].
class NoteByIdProvider extends FutureProvider<NoteModel?> {
  /// See also [noteById].
  NoteByIdProvider(String noteId)
    : this._internal(
        (ref) => noteById(ref as NoteByIdRef, noteId),
        from: noteByIdProvider,
        name: r'noteByIdProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$noteByIdHash,
        dependencies: NoteByIdFamily._dependencies,
        allTransitiveDependencies: NoteByIdFamily._allTransitiveDependencies,
        noteId: noteId,
      );

  NoteByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.noteId,
  }) : super.internal();

  final String noteId;

  @override
  Override overrideWith(
    FutureOr<NoteModel?> Function(NoteByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: NoteByIdProvider._internal(
        (ref) => create(ref as NoteByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        noteId: noteId,
      ),
    );
  }

  @override
  FutureProviderElement<NoteModel?> createElement() {
    return _NoteByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is NoteByIdProvider && other.noteId == noteId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, noteId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin NoteByIdRef on FutureProviderRef<NoteModel?> {
  /// The parameter `noteId` of this provider.
  String get noteId;
}

class _NoteByIdProviderElement extends FutureProviderElement<NoteModel?>
    with NoteByIdRef {
  _NoteByIdProviderElement(super.provider);

  @override
  String get noteId => (origin as NoteByIdProvider).noteId;
}

String _$bookByIdHash() => r'f6af8a55991c8ee5c10b5e06a0dede14da2af7b9';

/// See also [bookById].
@ProviderFor(bookById)
const bookByIdProvider = BookByIdFamily();

/// See also [bookById].
class BookByIdFamily extends Family<AsyncValue<BookModel?>> {
  /// See also [bookById].
  const BookByIdFamily();

  /// See also [bookById].
  BookByIdProvider call(String bookId) {
    return BookByIdProvider(bookId);
  }

  @override
  BookByIdProvider getProviderOverride(covariant BookByIdProvider provider) {
    return call(provider.bookId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'bookByIdProvider';
}

/// See also [bookById].
class BookByIdProvider extends StreamProvider<BookModel?> {
  /// See also [bookById].
  BookByIdProvider(String bookId)
    : this._internal(
        (ref) => bookById(ref as BookByIdRef, bookId),
        from: bookByIdProvider,
        name: r'bookByIdProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$bookByIdHash,
        dependencies: BookByIdFamily._dependencies,
        allTransitiveDependencies: BookByIdFamily._allTransitiveDependencies,
        bookId: bookId,
      );

  BookByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.bookId,
  }) : super.internal();

  final String bookId;

  @override
  Override overrideWith(
    Stream<BookModel?> Function(BookByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BookByIdProvider._internal(
        (ref) => create(ref as BookByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        bookId: bookId,
      ),
    );
  }

  @override
  StreamProviderElement<BookModel?> createElement() {
    return _BookByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BookByIdProvider && other.bookId == bookId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, bookId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BookByIdRef on StreamProviderRef<BookModel?> {
  /// The parameter `bookId` of this provider.
  String get bookId;
}

class _BookByIdProviderElement extends StreamProviderElement<BookModel?>
    with BookByIdRef {
  _BookByIdProviderElement(super.provider);

  @override
  String get bookId => (origin as BookByIdProvider).bookId;
}

String _$userNotesCountHash() => r'0c2ed2fbeebbf8d6f47da64ed3ffad8c2cb7faa6';

/// See also [userNotesCount].
@ProviderFor(userNotesCount)
final userNotesCountProvider = StreamProvider<int>.internal(
  userNotesCount,
  name: r'userNotesCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userNotesCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserNotesCountRef = StreamProviderRef<int>;
String _$pdfPathHash() => r'4d5843bff2b8c46e68cb78ec11f0ef7e1bf1a6b2';

/// Downloads a PDF URL to a local file and returns the path.
/// Stored in application documents (NOT temp) so Android doesn't purge it
/// between download and the native PDFView open call (causes ENOENT).
///
/// Copied from [pdfPath].
@ProviderFor(pdfPath)
const pdfPathProvider = PdfPathFamily();

/// Downloads a PDF URL to a local file and returns the path.
/// Stored in application documents (NOT temp) so Android doesn't purge it
/// between download and the native PDFView open call (causes ENOENT).
///
/// Copied from [pdfPath].
class PdfPathFamily extends Family<AsyncValue<String>> {
  /// Downloads a PDF URL to a local file and returns the path.
  /// Stored in application documents (NOT temp) so Android doesn't purge it
  /// between download and the native PDFView open call (causes ENOENT).
  ///
  /// Copied from [pdfPath].
  const PdfPathFamily();

  /// Downloads a PDF URL to a local file and returns the path.
  /// Stored in application documents (NOT temp) so Android doesn't purge it
  /// between download and the native PDFView open call (causes ENOENT).
  ///
  /// Copied from [pdfPath].
  PdfPathProvider call(String url) {
    return PdfPathProvider(url);
  }

  @override
  PdfPathProvider getProviderOverride(covariant PdfPathProvider provider) {
    return call(provider.url);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'pdfPathProvider';
}

/// Downloads a PDF URL to a local file and returns the path.
/// Stored in application documents (NOT temp) so Android doesn't purge it
/// between download and the native PDFView open call (causes ENOENT).
///
/// Copied from [pdfPath].
class PdfPathProvider extends FutureProvider<String> {
  /// Downloads a PDF URL to a local file and returns the path.
  /// Stored in application documents (NOT temp) so Android doesn't purge it
  /// between download and the native PDFView open call (causes ENOENT).
  ///
  /// Copied from [pdfPath].
  PdfPathProvider(String url)
    : this._internal(
        (ref) => pdfPath(ref as PdfPathRef, url),
        from: pdfPathProvider,
        name: r'pdfPathProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$pdfPathHash,
        dependencies: PdfPathFamily._dependencies,
        allTransitiveDependencies: PdfPathFamily._allTransitiveDependencies,
        url: url,
      );

  PdfPathProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.url,
  }) : super.internal();

  final String url;

  @override
  Override overrideWith(FutureOr<String> Function(PdfPathRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: PdfPathProvider._internal(
        (ref) => create(ref as PdfPathRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        url: url,
      ),
    );
  }

  @override
  FutureProviderElement<String> createElement() {
    return _PdfPathProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PdfPathProvider && other.url == url;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, url.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PdfPathRef on FutureProviderRef<String> {
  /// The parameter `url` of this provider.
  String get url;
}

class _PdfPathProviderElement extends FutureProviderElement<String>
    with PdfPathRef {
  _PdfPathProviderElement(super.provider);

  @override
  String get url => (origin as PdfPathProvider).url;
}

String _$pdfPageImageHash() => r'1e35f146d406ecc9f082357735fe32e86b6048ac';

/// Renders an arbitrary page of a PDF as JPEG bytes.
///
/// `pageIndex` is **0-based** to match the reader screen convention; we add
/// `+1` at the `pdfx` call site (its API is 1-based).
///
/// Render dimensions are clamped to 1600 px on the long edge to keep memory
/// bounded — phone-shot scans routinely report 4-5 k pixel pages and would
/// OOM mid-stream during background OCR otherwise.
///
/// Mobile caches the JPEG to `${docs}/page_imgs/img_{hash(url)}_{pageIndex}.jpg`
/// so repeat reads are zero-cost. Web has no filesystem, so it renders fresh
/// every time (the OCR cache layer handles dedupe at the text level).
///
/// Copied from [pdfPageImage].
@ProviderFor(pdfPageImage)
const pdfPageImageProvider = PdfPageImageFamily();

/// Renders an arbitrary page of a PDF as JPEG bytes.
///
/// `pageIndex` is **0-based** to match the reader screen convention; we add
/// `+1` at the `pdfx` call site (its API is 1-based).
///
/// Render dimensions are clamped to 1600 px on the long edge to keep memory
/// bounded — phone-shot scans routinely report 4-5 k pixel pages and would
/// OOM mid-stream during background OCR otherwise.
///
/// Mobile caches the JPEG to `${docs}/page_imgs/img_{hash(url)}_{pageIndex}.jpg`
/// so repeat reads are zero-cost. Web has no filesystem, so it renders fresh
/// every time (the OCR cache layer handles dedupe at the text level).
///
/// Copied from [pdfPageImage].
class PdfPageImageFamily extends Family<AsyncValue<Uint8List?>> {
  /// Renders an arbitrary page of a PDF as JPEG bytes.
  ///
  /// `pageIndex` is **0-based** to match the reader screen convention; we add
  /// `+1` at the `pdfx` call site (its API is 1-based).
  ///
  /// Render dimensions are clamped to 1600 px on the long edge to keep memory
  /// bounded — phone-shot scans routinely report 4-5 k pixel pages and would
  /// OOM mid-stream during background OCR otherwise.
  ///
  /// Mobile caches the JPEG to `${docs}/page_imgs/img_{hash(url)}_{pageIndex}.jpg`
  /// so repeat reads are zero-cost. Web has no filesystem, so it renders fresh
  /// every time (the OCR cache layer handles dedupe at the text level).
  ///
  /// Copied from [pdfPageImage].
  const PdfPageImageFamily();

  /// Renders an arbitrary page of a PDF as JPEG bytes.
  ///
  /// `pageIndex` is **0-based** to match the reader screen convention; we add
  /// `+1` at the `pdfx` call site (its API is 1-based).
  ///
  /// Render dimensions are clamped to 1600 px on the long edge to keep memory
  /// bounded — phone-shot scans routinely report 4-5 k pixel pages and would
  /// OOM mid-stream during background OCR otherwise.
  ///
  /// Mobile caches the JPEG to `${docs}/page_imgs/img_{hash(url)}_{pageIndex}.jpg`
  /// so repeat reads are zero-cost. Web has no filesystem, so it renders fresh
  /// every time (the OCR cache layer handles dedupe at the text level).
  ///
  /// Copied from [pdfPageImage].
  PdfPageImageProvider call({required String url, required int pageIndex}) {
    return PdfPageImageProvider(url: url, pageIndex: pageIndex);
  }

  @override
  PdfPageImageProvider getProviderOverride(
    covariant PdfPageImageProvider provider,
  ) {
    return call(url: provider.url, pageIndex: provider.pageIndex);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'pdfPageImageProvider';
}

/// Renders an arbitrary page of a PDF as JPEG bytes.
///
/// `pageIndex` is **0-based** to match the reader screen convention; we add
/// `+1` at the `pdfx` call site (its API is 1-based).
///
/// Render dimensions are clamped to 1600 px on the long edge to keep memory
/// bounded — phone-shot scans routinely report 4-5 k pixel pages and would
/// OOM mid-stream during background OCR otherwise.
///
/// Mobile caches the JPEG to `${docs}/page_imgs/img_{hash(url)}_{pageIndex}.jpg`
/// so repeat reads are zero-cost. Web has no filesystem, so it renders fresh
/// every time (the OCR cache layer handles dedupe at the text level).
///
/// Copied from [pdfPageImage].
class PdfPageImageProvider extends FutureProvider<Uint8List?> {
  /// Renders an arbitrary page of a PDF as JPEG bytes.
  ///
  /// `pageIndex` is **0-based** to match the reader screen convention; we add
  /// `+1` at the `pdfx` call site (its API is 1-based).
  ///
  /// Render dimensions are clamped to 1600 px on the long edge to keep memory
  /// bounded — phone-shot scans routinely report 4-5 k pixel pages and would
  /// OOM mid-stream during background OCR otherwise.
  ///
  /// Mobile caches the JPEG to `${docs}/page_imgs/img_{hash(url)}_{pageIndex}.jpg`
  /// so repeat reads are zero-cost. Web has no filesystem, so it renders fresh
  /// every time (the OCR cache layer handles dedupe at the text level).
  ///
  /// Copied from [pdfPageImage].
  PdfPageImageProvider({required String url, required int pageIndex})
    : this._internal(
        (ref) => pdfPageImage(
          ref as PdfPageImageRef,
          url: url,
          pageIndex: pageIndex,
        ),
        from: pdfPageImageProvider,
        name: r'pdfPageImageProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$pdfPageImageHash,
        dependencies: PdfPageImageFamily._dependencies,
        allTransitiveDependencies:
            PdfPageImageFamily._allTransitiveDependencies,
        url: url,
        pageIndex: pageIndex,
      );

  PdfPageImageProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.url,
    required this.pageIndex,
  }) : super.internal();

  final String url;
  final int pageIndex;

  @override
  Override overrideWith(
    FutureOr<Uint8List?> Function(PdfPageImageRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PdfPageImageProvider._internal(
        (ref) => create(ref as PdfPageImageRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        url: url,
        pageIndex: pageIndex,
      ),
    );
  }

  @override
  FutureProviderElement<Uint8List?> createElement() {
    return _PdfPageImageProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PdfPageImageProvider &&
        other.url == url &&
        other.pageIndex == pageIndex;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, url.hashCode);
    hash = _SystemHash.combine(hash, pageIndex.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PdfPageImageRef on FutureProviderRef<Uint8List?> {
  /// The parameter `url` of this provider.
  String get url;

  /// The parameter `pageIndex` of this provider.
  int get pageIndex;
}

class _PdfPageImageProviderElement extends FutureProviderElement<Uint8List?>
    with PdfPageImageRef {
  _PdfPageImageProviderElement(super.provider);

  @override
  String get url => (origin as PdfPageImageProvider).url;
  @override
  int get pageIndex => (origin as PdfPageImageProvider).pageIndex;
}

String _$pdfThumbnailHash() => r'2c4404d1bd3b890dd1b9777d2d18f5aeeb45d49a';

/// Renders the first page of a PDF as JPEG bytes (cached to disk).
///
/// Backward-compat thin wrapper around [pdfPageImageProvider]; kept so
/// existing thumbnail call sites (`pdf_card`, `note_edit_screen`,
/// `book_info_screen`) need no changes.
///
/// Copied from [pdfThumbnail].
@ProviderFor(pdfThumbnail)
const pdfThumbnailProvider = PdfThumbnailFamily();

/// Renders the first page of a PDF as JPEG bytes (cached to disk).
///
/// Backward-compat thin wrapper around [pdfPageImageProvider]; kept so
/// existing thumbnail call sites (`pdf_card`, `note_edit_screen`,
/// `book_info_screen`) need no changes.
///
/// Copied from [pdfThumbnail].
class PdfThumbnailFamily extends Family<AsyncValue<Uint8List?>> {
  /// Renders the first page of a PDF as JPEG bytes (cached to disk).
  ///
  /// Backward-compat thin wrapper around [pdfPageImageProvider]; kept so
  /// existing thumbnail call sites (`pdf_card`, `note_edit_screen`,
  /// `book_info_screen`) need no changes.
  ///
  /// Copied from [pdfThumbnail].
  const PdfThumbnailFamily();

  /// Renders the first page of a PDF as JPEG bytes (cached to disk).
  ///
  /// Backward-compat thin wrapper around [pdfPageImageProvider]; kept so
  /// existing thumbnail call sites (`pdf_card`, `note_edit_screen`,
  /// `book_info_screen`) need no changes.
  ///
  /// Copied from [pdfThumbnail].
  PdfThumbnailProvider call(String url) {
    return PdfThumbnailProvider(url);
  }

  @override
  PdfThumbnailProvider getProviderOverride(
    covariant PdfThumbnailProvider provider,
  ) {
    return call(provider.url);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'pdfThumbnailProvider';
}

/// Renders the first page of a PDF as JPEG bytes (cached to disk).
///
/// Backward-compat thin wrapper around [pdfPageImageProvider]; kept so
/// existing thumbnail call sites (`pdf_card`, `note_edit_screen`,
/// `book_info_screen`) need no changes.
///
/// Copied from [pdfThumbnail].
class PdfThumbnailProvider extends FutureProvider<Uint8List?> {
  /// Renders the first page of a PDF as JPEG bytes (cached to disk).
  ///
  /// Backward-compat thin wrapper around [pdfPageImageProvider]; kept so
  /// existing thumbnail call sites (`pdf_card`, `note_edit_screen`,
  /// `book_info_screen`) need no changes.
  ///
  /// Copied from [pdfThumbnail].
  PdfThumbnailProvider(String url)
    : this._internal(
        (ref) => pdfThumbnail(ref as PdfThumbnailRef, url),
        from: pdfThumbnailProvider,
        name: r'pdfThumbnailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$pdfThumbnailHash,
        dependencies: PdfThumbnailFamily._dependencies,
        allTransitiveDependencies:
            PdfThumbnailFamily._allTransitiveDependencies,
        url: url,
      );

  PdfThumbnailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.url,
  }) : super.internal();

  final String url;

  @override
  Override overrideWith(
    FutureOr<Uint8List?> Function(PdfThumbnailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PdfThumbnailProvider._internal(
        (ref) => create(ref as PdfThumbnailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        url: url,
      ),
    );
  }

  @override
  FutureProviderElement<Uint8List?> createElement() {
    return _PdfThumbnailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PdfThumbnailProvider && other.url == url;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, url.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PdfThumbnailRef on FutureProviderRef<Uint8List?> {
  /// The parameter `url` of this provider.
  String get url;
}

class _PdfThumbnailProviderElement extends FutureProviderElement<Uint8List?>
    with PdfThumbnailRef {
  _PdfThumbnailProviderElement(super.provider);

  @override
  String get url => (origin as PdfThumbnailProvider).url;
}

String _$ocrPageImageHash() => r'bb1b5eae0193fd0d9648ffed4d45080ceca61ead';

/// Renders a PDF page as PNG bytes for OCR input.
///
/// Distinct from [pdfPageImageProvider] in two ways that improve OCR accuracy:
/// - PNG (lossless) eliminates JPEG compression artefacts around character edges.
/// - 2400 px long-edge cap (~280 DPI for A4/Letter) vs the display provider's
///   1600 px (~189 DPI), keeping render size inside Tesseract's recommended
///   250-400 DPI sweet spot.
///
/// Not cached to disk — the rendered bytes are large and short-lived; the OCR
/// text result is what gets cached (see [ocrPageTextProvider]).
///
/// Copied from [ocrPageImage].
@ProviderFor(ocrPageImage)
const ocrPageImageProvider = OcrPageImageFamily();

/// Renders a PDF page as PNG bytes for OCR input.
///
/// Distinct from [pdfPageImageProvider] in two ways that improve OCR accuracy:
/// - PNG (lossless) eliminates JPEG compression artefacts around character edges.
/// - 2400 px long-edge cap (~280 DPI for A4/Letter) vs the display provider's
///   1600 px (~189 DPI), keeping render size inside Tesseract's recommended
///   250-400 DPI sweet spot.
///
/// Not cached to disk — the rendered bytes are large and short-lived; the OCR
/// text result is what gets cached (see [ocrPageTextProvider]).
///
/// Copied from [ocrPageImage].
class OcrPageImageFamily extends Family<AsyncValue<Uint8List?>> {
  /// Renders a PDF page as PNG bytes for OCR input.
  ///
  /// Distinct from [pdfPageImageProvider] in two ways that improve OCR accuracy:
  /// - PNG (lossless) eliminates JPEG compression artefacts around character edges.
  /// - 2400 px long-edge cap (~280 DPI for A4/Letter) vs the display provider's
  ///   1600 px (~189 DPI), keeping render size inside Tesseract's recommended
  ///   250-400 DPI sweet spot.
  ///
  /// Not cached to disk — the rendered bytes are large and short-lived; the OCR
  /// text result is what gets cached (see [ocrPageTextProvider]).
  ///
  /// Copied from [ocrPageImage].
  const OcrPageImageFamily();

  /// Renders a PDF page as PNG bytes for OCR input.
  ///
  /// Distinct from [pdfPageImageProvider] in two ways that improve OCR accuracy:
  /// - PNG (lossless) eliminates JPEG compression artefacts around character edges.
  /// - 2400 px long-edge cap (~280 DPI for A4/Letter) vs the display provider's
  ///   1600 px (~189 DPI), keeping render size inside Tesseract's recommended
  ///   250-400 DPI sweet spot.
  ///
  /// Not cached to disk — the rendered bytes are large and short-lived; the OCR
  /// text result is what gets cached (see [ocrPageTextProvider]).
  ///
  /// Copied from [ocrPageImage].
  OcrPageImageProvider call({required String url, required int pageIndex}) {
    return OcrPageImageProvider(url: url, pageIndex: pageIndex);
  }

  @override
  OcrPageImageProvider getProviderOverride(
    covariant OcrPageImageProvider provider,
  ) {
    return call(url: provider.url, pageIndex: provider.pageIndex);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'ocrPageImageProvider';
}

/// Renders a PDF page as PNG bytes for OCR input.
///
/// Distinct from [pdfPageImageProvider] in two ways that improve OCR accuracy:
/// - PNG (lossless) eliminates JPEG compression artefacts around character edges.
/// - 2400 px long-edge cap (~280 DPI for A4/Letter) vs the display provider's
///   1600 px (~189 DPI), keeping render size inside Tesseract's recommended
///   250-400 DPI sweet spot.
///
/// Not cached to disk — the rendered bytes are large and short-lived; the OCR
/// text result is what gets cached (see [ocrPageTextProvider]).
///
/// Copied from [ocrPageImage].
class OcrPageImageProvider extends FutureProvider<Uint8List?> {
  /// Renders a PDF page as PNG bytes for OCR input.
  ///
  /// Distinct from [pdfPageImageProvider] in two ways that improve OCR accuracy:
  /// - PNG (lossless) eliminates JPEG compression artefacts around character edges.
  /// - 2400 px long-edge cap (~280 DPI for A4/Letter) vs the display provider's
  ///   1600 px (~189 DPI), keeping render size inside Tesseract's recommended
  ///   250-400 DPI sweet spot.
  ///
  /// Not cached to disk — the rendered bytes are large and short-lived; the OCR
  /// text result is what gets cached (see [ocrPageTextProvider]).
  ///
  /// Copied from [ocrPageImage].
  OcrPageImageProvider({required String url, required int pageIndex})
    : this._internal(
        (ref) => ocrPageImage(
          ref as OcrPageImageRef,
          url: url,
          pageIndex: pageIndex,
        ),
        from: ocrPageImageProvider,
        name: r'ocrPageImageProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$ocrPageImageHash,
        dependencies: OcrPageImageFamily._dependencies,
        allTransitiveDependencies:
            OcrPageImageFamily._allTransitiveDependencies,
        url: url,
        pageIndex: pageIndex,
      );

  OcrPageImageProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.url,
    required this.pageIndex,
  }) : super.internal();

  final String url;
  final int pageIndex;

  @override
  Override overrideWith(
    FutureOr<Uint8List?> Function(OcrPageImageRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: OcrPageImageProvider._internal(
        (ref) => create(ref as OcrPageImageRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        url: url,
        pageIndex: pageIndex,
      ),
    );
  }

  @override
  FutureProviderElement<Uint8List?> createElement() {
    return _OcrPageImageProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OcrPageImageProvider &&
        other.url == url &&
        other.pageIndex == pageIndex;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, url.hashCode);
    hash = _SystemHash.combine(hash, pageIndex.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin OcrPageImageRef on FutureProviderRef<Uint8List?> {
  /// The parameter `url` of this provider.
  String get url;

  /// The parameter `pageIndex` of this provider.
  int get pageIndex;
}

class _OcrPageImageProviderElement extends FutureProviderElement<Uint8List?>
    with OcrPageImageRef {
  _OcrPageImageProviderElement(super.provider);

  @override
  String get url => (origin as OcrPageImageProvider).url;
  @override
  int get pageIndex => (origin as OcrPageImageProvider).pageIndex;
}

String _$ocrCacheServiceHash() => r'28eb69afdabbcab1fda8be671c63036cd9052776';

/// Cache for OCR'd page text. Backed by Hive (`app_prefs` box) and keyed by
/// `ocr_v1_{bookId}_{pageIndex}` so a future engine swap can cut a new
/// namespace without colliding with stale entries.
///
/// Copied from [ocrCacheService].
@ProviderFor(ocrCacheService)
final ocrCacheServiceProvider = Provider<OcrCacheService>.internal(
  ocrCacheService,
  name: r'ocrCacheServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ocrCacheServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OcrCacheServiceRef = ProviderRef<OcrCacheService>;
String _$ocrDataSourceHash() => r'e38e27d7a0baac09bd2fffa4b5caefaac79e104b';

/// Owns the OCR engine for the current platform. Disposed automatically when
/// the provider scope tears down (e.g. on logout / hot restart).
///
/// Copied from [ocrDataSource].
@ProviderFor(ocrDataSource)
final ocrDataSourceProvider = Provider<OcrDataSource>.internal(
  ocrDataSource,
  name: r'ocrDataSourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ocrDataSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OcrDataSourceRef = ProviderRef<OcrDataSource>;
String _$ocrPageTextHash() => r'50e8d1196ad3929ae9dcf2d3bd2bc4422e2cba40';

/// OCR pipeline for a single PDF page. Cache → render → recognise → clean →
/// cache → return.
///
/// Caller passes the book identity (`bookId` for cache scoping), the resolved
/// `url` that `pdfPageImageProvider` keys off (mobile = local file path, web =
/// remote/proxy URL), and the 0-based `pageIndex`. Returns the cleaned text
/// ready to feed straight into TTS; an empty string means "the page truly
/// has no recoverable text" (caller surfaces a snackbar).
///
/// The page image is invalidated from the Riverpod cache on the way out
/// (success OR failure) so the rendered JPEG bytes don't pin memory during
/// background pre-OCR of long PDFs — without this, a 200-page scan would
/// climb to ~3 GB resident on phones.
///
/// Copied from [ocrPageText].
@ProviderFor(ocrPageText)
const ocrPageTextProvider = OcrPageTextFamily();

/// OCR pipeline for a single PDF page. Cache → render → recognise → clean →
/// cache → return.
///
/// Caller passes the book identity (`bookId` for cache scoping), the resolved
/// `url` that `pdfPageImageProvider` keys off (mobile = local file path, web =
/// remote/proxy URL), and the 0-based `pageIndex`. Returns the cleaned text
/// ready to feed straight into TTS; an empty string means "the page truly
/// has no recoverable text" (caller surfaces a snackbar).
///
/// The page image is invalidated from the Riverpod cache on the way out
/// (success OR failure) so the rendered JPEG bytes don't pin memory during
/// background pre-OCR of long PDFs — without this, a 200-page scan would
/// climb to ~3 GB resident on phones.
///
/// Copied from [ocrPageText].
class OcrPageTextFamily extends Family<AsyncValue<String>> {
  /// OCR pipeline for a single PDF page. Cache → render → recognise → clean →
  /// cache → return.
  ///
  /// Caller passes the book identity (`bookId` for cache scoping), the resolved
  /// `url` that `pdfPageImageProvider` keys off (mobile = local file path, web =
  /// remote/proxy URL), and the 0-based `pageIndex`. Returns the cleaned text
  /// ready to feed straight into TTS; an empty string means "the page truly
  /// has no recoverable text" (caller surfaces a snackbar).
  ///
  /// The page image is invalidated from the Riverpod cache on the way out
  /// (success OR failure) so the rendered JPEG bytes don't pin memory during
  /// background pre-OCR of long PDFs — without this, a 200-page scan would
  /// climb to ~3 GB resident on phones.
  ///
  /// Copied from [ocrPageText].
  const OcrPageTextFamily();

  /// OCR pipeline for a single PDF page. Cache → render → recognise → clean →
  /// cache → return.
  ///
  /// Caller passes the book identity (`bookId` for cache scoping), the resolved
  /// `url` that `pdfPageImageProvider` keys off (mobile = local file path, web =
  /// remote/proxy URL), and the 0-based `pageIndex`. Returns the cleaned text
  /// ready to feed straight into TTS; an empty string means "the page truly
  /// has no recoverable text" (caller surfaces a snackbar).
  ///
  /// The page image is invalidated from the Riverpod cache on the way out
  /// (success OR failure) so the rendered JPEG bytes don't pin memory during
  /// background pre-OCR of long PDFs — without this, a 200-page scan would
  /// climb to ~3 GB resident on phones.
  ///
  /// Copied from [ocrPageText].
  OcrPageTextProvider call({
    required String bookId,
    required String url,
    required int pageIndex,
  }) {
    return OcrPageTextProvider(bookId: bookId, url: url, pageIndex: pageIndex);
  }

  @override
  OcrPageTextProvider getProviderOverride(
    covariant OcrPageTextProvider provider,
  ) {
    return call(
      bookId: provider.bookId,
      url: provider.url,
      pageIndex: provider.pageIndex,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'ocrPageTextProvider';
}

/// OCR pipeline for a single PDF page. Cache → render → recognise → clean →
/// cache → return.
///
/// Caller passes the book identity (`bookId` for cache scoping), the resolved
/// `url` that `pdfPageImageProvider` keys off (mobile = local file path, web =
/// remote/proxy URL), and the 0-based `pageIndex`. Returns the cleaned text
/// ready to feed straight into TTS; an empty string means "the page truly
/// has no recoverable text" (caller surfaces a snackbar).
///
/// The page image is invalidated from the Riverpod cache on the way out
/// (success OR failure) so the rendered JPEG bytes don't pin memory during
/// background pre-OCR of long PDFs — without this, a 200-page scan would
/// climb to ~3 GB resident on phones.
///
/// Copied from [ocrPageText].
class OcrPageTextProvider extends FutureProvider<String> {
  /// OCR pipeline for a single PDF page. Cache → render → recognise → clean →
  /// cache → return.
  ///
  /// Caller passes the book identity (`bookId` for cache scoping), the resolved
  /// `url` that `pdfPageImageProvider` keys off (mobile = local file path, web =
  /// remote/proxy URL), and the 0-based `pageIndex`. Returns the cleaned text
  /// ready to feed straight into TTS; an empty string means "the page truly
  /// has no recoverable text" (caller surfaces a snackbar).
  ///
  /// The page image is invalidated from the Riverpod cache on the way out
  /// (success OR failure) so the rendered JPEG bytes don't pin memory during
  /// background pre-OCR of long PDFs — without this, a 200-page scan would
  /// climb to ~3 GB resident on phones.
  ///
  /// Copied from [ocrPageText].
  OcrPageTextProvider({
    required String bookId,
    required String url,
    required int pageIndex,
  }) : this._internal(
         (ref) => ocrPageText(
           ref as OcrPageTextRef,
           bookId: bookId,
           url: url,
           pageIndex: pageIndex,
         ),
         from: ocrPageTextProvider,
         name: r'ocrPageTextProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$ocrPageTextHash,
         dependencies: OcrPageTextFamily._dependencies,
         allTransitiveDependencies:
             OcrPageTextFamily._allTransitiveDependencies,
         bookId: bookId,
         url: url,
         pageIndex: pageIndex,
       );

  OcrPageTextProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.bookId,
    required this.url,
    required this.pageIndex,
  }) : super.internal();

  final String bookId;
  final String url;
  final int pageIndex;

  @override
  Override overrideWith(
    FutureOr<String> Function(OcrPageTextRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: OcrPageTextProvider._internal(
        (ref) => create(ref as OcrPageTextRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        bookId: bookId,
        url: url,
        pageIndex: pageIndex,
      ),
    );
  }

  @override
  FutureProviderElement<String> createElement() {
    return _OcrPageTextProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OcrPageTextProvider &&
        other.bookId == bookId &&
        other.url == url &&
        other.pageIndex == pageIndex;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, bookId.hashCode);
    hash = _SystemHash.combine(hash, url.hashCode);
    hash = _SystemHash.combine(hash, pageIndex.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin OcrPageTextRef on FutureProviderRef<String> {
  /// The parameter `bookId` of this provider.
  String get bookId;

  /// The parameter `url` of this provider.
  String get url;

  /// The parameter `pageIndex` of this provider.
  int get pageIndex;
}

class _OcrPageTextProviderElement extends FutureProviderElement<String>
    with OcrPageTextRef {
  _OcrPageTextProviderElement(super.provider);

  @override
  String get bookId => (origin as OcrPageTextProvider).bookId;
  @override
  String get url => (origin as OcrPageTextProvider).url;
  @override
  int get pageIndex => (origin as OcrPageTextProvider).pageIndex;
}

String _$bookOcrProgressHash() => r'a07b28d94fb90c05f5cde67e7dfd8c007883e566';

/// Surfaces background-OCR progress (done / total) for the app-bar chip in
/// Wave 3. `null` means no background pre-OCR is currently running.
///
/// Copied from [BookOcrProgress].
@ProviderFor(BookOcrProgress)
final bookOcrProgressProvider =
    NotifierProvider<BookOcrProgress, ({int done, int total})?>.internal(
      BookOcrProgress.new,
      name: r'bookOcrProgressProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$bookOcrProgressHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BookOcrProgress = Notifier<({int done, int total})?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
