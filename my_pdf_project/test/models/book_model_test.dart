import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';

void main() {
  group('BookModel', () {
    const book = BookModel(
      id: 'b1',
      title: 'Test Book',
      link: 'https://pdf.url',
      totalPages: 100,
      currentPage: 50,
      progress: 50.0,
      status: 'reading',
      ownerId: 'u1',
    );

    test('fromMap computes progress correctly', () {
      final m = BookModel.fromMap('b1', {
        'title': 'Test Book',
        'link': 'https://pdf.url',
        'totalPages': 200,
        'currentPage': 100,
        'status': 'reading',
        'ownerId': 'u1',
      });
      expect(m.progress, 50.0);
    });

    test('fromMap progress zero when totalPages is 0', () {
      final m = BookModel.fromMap('b2', {
        'title': 'Empty',
        'link': '',
        'totalPages': 0,
        'currentPage': 0,
        'status': 'reading',
        'ownerId': 'u1',
      });
      expect(m.progress, 0.0);
    });

    test('fromMap parses lastReadAt', () {
      final dt = DateTime(2025, 1, 15);
      final m = BookModel.fromMap('b3', {
        'title': 'Book',
        'link': '',
        'totalPages': 10,
        'currentPage': 5,
        'status': 'reading',
        'ownerId': 'u1',
        'lastReadAt': dt.toIso8601String(),
      });
      expect(m.lastReadAt, dt);
    });

    test('fromMap handles null lastReadAt', () {
      final m = BookModel.fromMap('b4', {
        'title': 'Book',
        'link': '',
        'totalPages': 10,
        'currentPage': 0,
        'status': 'reading',
        'ownerId': 'u1',
      });
      expect(m.lastReadAt, isNull);
    });

    test('toMap serializes all fields', () {
      final map = book.toMap();
      expect(map['title'], 'Test Book');
      expect(map['totalPages'], 100);
      expect(map['currentPage'], 50);
      expect(map['progress'], 50.0);
      expect(map['status'], 'reading');
      expect(map['ownerId'], 'u1');
    });

    test('copyWith preserves ownerId', () {
      final updated = book.copyWith(title: 'New Title', currentPage: 75);
      expect(updated.ownerId, 'u1');
      expect(updated.title, 'New Title');
      expect(updated.currentPage, 75);
    });

    test('status valid values', () {
      for (final s in ['reading', 'on_hold', 'finished']) {
        final m = book.copyWith(status: s);
        expect(m.status, s);
      }
    });
  });
}
