import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';

void main() {
  group('BookshelfModel', () {
    final dt = DateTime(2025, 3, 10);

    test('fromMap parses correctly', () {
      final shelf = BookshelfModel.fromMap('s1', {
        'name': 'Favourites',
        'ownerId': 'u1',
        'createdAt': dt.toIso8601String(),
      });
      expect(shelf.id, 's1');
      expect(shelf.name, 'Favourites');
      expect(shelf.ownerId, 'u1');
      expect(shelf.createdAt, dt);
    });

    test('fromMap uses DateTime.now() fallback for bad date', () {
      final before = DateTime.now();
      final shelf = BookshelfModel.fromMap('s2', {
        'name': 'X',
        'ownerId': 'u1',
        'createdAt': 'not-a-date',
      });
      expect(shelf.createdAt.isAfter(before) || shelf.createdAt.isAtSameMomentAs(before), isTrue);
    });

    test('toMap serializes correctly', () {
      final shelf = BookshelfModel(id: 's1', name: 'Sci-Fi', ownerId: 'u2', createdAt: dt);
      final map = shelf.toMap();
      expect(map['name'], 'Sci-Fi');
      expect(map['ownerId'], 'u2');
      expect(map['createdAt'], dt.toIso8601String());
      expect(map.containsKey('id'), isFalse);
    });
  });
}
