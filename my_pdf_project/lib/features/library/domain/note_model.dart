class NoteModel {
  final String id;
  final String bookId;
  final String content;
  final DateTime updatedAt;

  const NoteModel({
    required this.id,
    required this.bookId,
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'bookId': bookId,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory NoteModel.fromMap(String id, Map<String, dynamic> map) {
    return NoteModel(
      id: id,
      bookId: map['bookId'] ?? '',
      content: map['content'] ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
