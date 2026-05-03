class BookshelfModel {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;

  const BookshelfModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BookshelfModel.fromMap(String id, Map<String, dynamic> map) {
    return BookshelfModel(
      id: id,
      name: map['name'] ?? '',
      ownerId: map['ownerId'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
