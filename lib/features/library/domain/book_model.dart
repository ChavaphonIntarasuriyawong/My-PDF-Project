class BookModel {
  final String id;
  final String title;
  final String link;
  final int totalPages;
  final int currentPage;
  final double progress;
  final String status; // "reading" | "on_hold" | "finished"
  final String shelfId;
  final String ownerId;
  final DateTime? lastReadAt;
  final String? author;
  final int? year;
  // Set at upload time when `_isBitmapOnlyPdf` detects no text layer. Lets
  // the reader skip the text-extraction probe and route straight to OCR.
  // Defaults to false for backward compat with books written before this field.
  final bool needsOcr;
  // Per-book PIN lock (Wave 1). When true, opening the book requires PIN
  // entry against `lockHash` before the reader is allowed to mount.
  // `lockHash` is a salted SHA-256-crypt string (modular crypt format) — the
  // raw PIN is NEVER stored. Defaults preserve backward compat for books
  // written before this field existed.
  final bool isLocked;
  final String? lockHash;

  const BookModel({
    required this.id,
    required this.title,
    required this.link,
    required this.totalPages,
    required this.currentPage,
    required this.progress,
    required this.status,
    required this.shelfId,
    required this.ownerId,
    this.lastReadAt,
    this.author,
    this.year,
    this.needsOcr = false,
    this.isLocked = false,
    this.lockHash,
  });

  BookModel copyWith({
    String? title,
    String? link,
    int? totalPages,
    int? currentPage,
    double? progress,
    String? status,
    String? shelfId,
    DateTime? lastReadAt,
    String? author,
    int? year,
    bool? needsOcr,
    bool? isLocked,
    String? lockHash,
  }) {
    return BookModel(
      id: id,
      title: title ?? this.title,
      link: link ?? this.link,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      shelfId: shelfId ?? this.shelfId,
      ownerId: ownerId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      author: author ?? this.author,
      year: year ?? this.year,
      needsOcr: needsOcr ?? this.needsOcr,
      isLocked: isLocked ?? this.isLocked,
      lockHash: lockHash ?? this.lockHash,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'link': link,
    'totalPages': totalPages,
    'currentPage': currentPage,
    'progress': progress,
    'status': status,
    'shelfId': shelfId,
    'ownerId': ownerId,
    'lastReadAt': lastReadAt?.toIso8601String(),
    'author': author,
    'year': year,
    'needsOcr': needsOcr,
    'isLocked': isLocked,
    'lockHash': lockHash,
  };

  factory BookModel.fromMap(String id, Map<String, dynamic> map) {
    final total = (map['totalPages'] as num?)?.toInt() ?? 0;
    final current = (map['currentPage'] as num?)?.toInt() ?? 0;
    final rawNeedsOcr = map['needsOcr'];
    final rawIsLocked = map['isLocked'];
    return BookModel(
      id: id,
      title: map['title'] ?? '',
      link: map['link'] ?? '',
      totalPages: total,
      currentPage: current,
      progress: total > 0 ? (current / total * 100) : 0,
      status: map['status'] ?? 'reading',
      shelfId: map['shelfId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      lastReadAt: map['lastReadAt'] != null
          ? DateTime.tryParse(map['lastReadAt'])
          : null,
      author: map['author'] as String?,
      year: (map['year'] as num?)?.toInt(),
      needsOcr: rawNeedsOcr is bool ? rawNeedsOcr : false,
      isLocked: rawIsLocked is bool ? rawIsLocked : false,
      lockHash: map['lockHash'] as String?,
    );
  }
}
