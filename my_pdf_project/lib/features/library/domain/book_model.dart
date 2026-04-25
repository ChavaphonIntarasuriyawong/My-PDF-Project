class BookModel {
  final String id;
  final String title;
  final String link;
  final String coverUrl;
  final int totalPages;
  final int currentPage;
  final double progress;
  final String status; // "reading" | "on_hold" | "finished"
  final String shelfId;
  final String ownerId;
  final DateTime? lastReadAt;

  const BookModel({
    required this.id,
    required this.title,
    required this.link,
    this.coverUrl = '',
    required this.totalPages,
    required this.currentPage,
    required this.progress,
    required this.status,
    required this.shelfId,
    required this.ownerId,
    this.lastReadAt,
  });

  BookModel copyWith({
    String? title,
    String? link,
    String? coverUrl,
    int? totalPages,
    int? currentPage,
    double? progress,
    String? status,
    String? shelfId,
    DateTime? lastReadAt,
  }) {
    return BookModel(
      id: id,
      title: title ?? this.title,
      link: link ?? this.link,
      coverUrl: coverUrl ?? this.coverUrl,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      shelfId: shelfId ?? this.shelfId,
      ownerId: ownerId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'link': link,
    'coverUrl': coverUrl,
    'totalPages': totalPages,
    'currentPage': currentPage,
    'progress': progress,
    'status': status,
    'shelfId': shelfId,
    'ownerId': ownerId,
    'lastReadAt': lastReadAt?.toIso8601String(),
  };

  factory BookModel.fromMap(String id, Map<String, dynamic> map) {
    final total = (map['totalPages'] as num?)?.toInt() ?? 0;
    final current = (map['currentPage'] as num?)?.toInt() ?? 0;
    return BookModel(
      id: id,
      title: map['title'] ?? '',
      link: map['link'] ?? '',
      coverUrl: map['coverUrl'] ?? '',
      totalPages: total,
      currentPage: current,
      progress: total > 0 ? (current / total * 100) : 0,
      status: map['status'] ?? 'reading',
      shelfId: map['shelfId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      lastReadAt: map['lastReadAt'] != null ? DateTime.tryParse(map['lastReadAt']) : null,
    );
  }
}
