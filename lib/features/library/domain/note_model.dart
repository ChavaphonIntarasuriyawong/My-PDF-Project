class NoteModel {
  final String id;
  final String bookId;
  final String title;
  final String content;
  final DateTime updatedAt;

  const NoteModel({
    required this.id,
    required this.bookId,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'bookId': bookId,
    'title': title,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory NoteModel.fromMap(String id, Map<String, dynamic> map) {
    return NoteModel(
      id: id,
      bookId: map['bookId'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
