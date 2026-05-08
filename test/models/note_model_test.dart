import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/library/domain/note_model.dart';

void main() {
  group('NoteModel', () {
    final dt = DateTime(2025, 6, 1, 10, 0);

    test('fromMap parses correctly', () {
      final note = NoteModel.fromMap('n1', {
        'bookId': 'b1',
        'content': 'Chapter 1 notes',
        'updatedAt': dt.toIso8601String(),
      });
      expect(note.id, 'n1');
      expect(note.bookId, 'b1');
      expect(note.content, 'Chapter 1 notes');
      expect(note.updatedAt, dt);
    });

    test('fromMap falls back updatedAt to now on bad date', () {
      final before = DateTime.now();
      final note = NoteModel.fromMap('n2', {
        'bookId': 'b1',
        'content': '',
        'updatedAt': 'bad',
      });
      expect(
        note.updatedAt.isAfter(before) ||
            note.updatedAt.isAtSameMomentAs(before),
        isTrue,
      );
    });

    test('toMap excludes id', () {
      final note = NoteModel(
        id: 'n1',
        bookId: 'b1',
        title: 'My Note',
        content: 'hello',
        updatedAt: dt,
      );
      final map = note.toMap();
      expect(map['bookId'], 'b1');
      expect(map['title'], 'My Note');
      expect(map['content'], 'hello');
      expect(map['updatedAt'], dt.toIso8601String());
      expect(map.containsKey('id'), isFalse);
    });
  });
}
