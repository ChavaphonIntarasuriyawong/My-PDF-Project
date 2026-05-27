// Unit tests for NoteModel (lib/features/library/domain/note_model.dart).
//
// Coverage goals:
//   - constructor + field access
//   - toMap() serialisation
//   - fromMap() deserialisation (happy path + missing/null fields)
//   - updatedAt ISO-8601 parsing and fallback
//   - toMap → fromMap round-trip

import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/library/domain/note_model.dart';

void main() {
  final fixedDate = DateTime.utc(2024, 5, 20, 14, 30, 0);

  group('NoteModel', () {
    // -----------------------------------------------------------------------
    // Constructor & field access
    // -----------------------------------------------------------------------

    group('constructor', () {
      test('stores all fields', () {
        final n = NoteModel(
          id: 'n1',
          bookId: 'b1',
          title: 'Chapter 1 notes',
          content: 'Very interesting intro.',
          updatedAt: fixedDate,
        );

        expect(n.id, 'n1');
        expect(n.bookId, 'b1');
        expect(n.title, 'Chapter 1 notes');
        expect(n.content, 'Very interesting intro.');
        expect(n.updatedAt, fixedDate);
      });
    });

    // -----------------------------------------------------------------------
    // toMap()
    // -----------------------------------------------------------------------

    group('toMap()', () {
      test('contains bookId, title, content, updatedAt — omits id', () {
        final n = NoteModel(
          id: 'n1',
          bookId: 'b1',
          title: 'My note',
          content: 'Content here.',
          updatedAt: fixedDate,
        );
        final map = n.toMap();

        expect(map['bookId'], 'b1');
        expect(map['title'], 'My note');
        expect(map['content'], 'Content here.');
        expect(map['updatedAt'], fixedDate.toIso8601String());
        expect(map.containsKey('id'), isFalse);
      });

      test('toMap() returns exactly 4 keys', () {
        final n = NoteModel(
          id: 'n1',
          bookId: 'b1',
          title: 'T',
          content: 'C',
          updatedAt: fixedDate,
        );
        expect(n.toMap().keys.length, 4);
      });

      test('updatedAt is serialised as ISO-8601 string', () {
        final n = NoteModel(
          id: 'n1',
          bookId: 'b1',
          title: 'T',
          content: 'C',
          updatedAt: fixedDate,
        );
        expect(n.toMap()['updatedAt'], isA<String>());
        expect(n.toMap()['updatedAt'], fixedDate.toIso8601String());
      });

      test('empty title and content are preserved as empty strings', () {
        final n = NoteModel(
          id: 'n1',
          bookId: 'b1',
          title: '',
          content: '',
          updatedAt: fixedDate,
        );
        final map = n.toMap();
        expect(map['title'], '');
        expect(map['content'], '');
      });
    });

    // -----------------------------------------------------------------------
    // fromMap()
    // -----------------------------------------------------------------------

    group('fromMap()', () {
      test('round-trips a complete map', () {
        final map = {
          'bookId': 'b5',
          'title': 'Round Trip',
          'content': 'All good.',
          'updatedAt': fixedDate.toIso8601String(),
        };
        final n = NoteModel.fromMap('n5', map);

        expect(n.id, 'n5');
        expect(n.bookId, 'b5');
        expect(n.title, 'Round Trip');
        expect(n.content, 'All good.');
        expect(n.updatedAt, fixedDate);
      });

      test('uses id argument as id', () {
        final n = NoteModel.fromMap('doc-id', {
          'bookId': 'b1',
          'title': 'T',
          'content': 'C',
          'updatedAt': fixedDate.toIso8601String(),
        });
        expect(n.id, 'doc-id');
      });

      test('missing bookId defaults to empty string', () {
        final n = NoteModel.fromMap('n1', {
          'title': 'T',
          'content': 'C',
          'updatedAt': fixedDate.toIso8601String(),
        });
        expect(n.bookId, '');
      });

      test('missing title defaults to empty string', () {
        final n = NoteModel.fromMap('n1', {
          'bookId': 'b1',
          'content': 'C',
          'updatedAt': fixedDate.toIso8601String(),
        });
        expect(n.title, '');
      });

      test('missing content defaults to empty string', () {
        final n = NoteModel.fromMap('n1', {
          'bookId': 'b1',
          'title': 'T',
          'updatedAt': fixedDate.toIso8601String(),
        });
        expect(n.content, '');
      });

      test(
        'missing updatedAt falls back to DateTime.now() (does not throw)',
        () {
          final before = DateTime.now();
          final n = NoteModel.fromMap('n1', {
            'bookId': 'b1',
            'title': 'T',
            'content': 'C',
          });
          final after = DateTime.now();

          expect(
            n.updatedAt.isAfter(before) || n.updatedAt.isAtSameMomentAs(before),
            isTrue,
          );
          expect(
            n.updatedAt.isBefore(after) || n.updatedAt.isAtSameMomentAs(after),
            isTrue,
          );
        },
      );

      test(
        'garbled updatedAt falls back to DateTime.now() (does not throw)',
        () {
          expect(
            () => NoteModel.fromMap('n1', {
              'bookId': 'b1',
              'title': 'T',
              'content': 'C',
              'updatedAt': 'not-a-date',
            }),
            returnsNormally,
          );
        },
      );

      test('null bookId defaults to empty string', () {
        final n = NoteModel.fromMap('n1', <String, dynamic>{
          'bookId': null,
          'title': 'T',
          'content': 'C',
          'updatedAt': fixedDate.toIso8601String(),
        });
        expect(n.bookId, '');
      });

      test('null title defaults to empty string', () {
        final n = NoteModel.fromMap('n1', <String, dynamic>{
          'bookId': 'b1',
          'title': null,
          'content': 'C',
          'updatedAt': fixedDate.toIso8601String(),
        });
        expect(n.title, '');
      });

      test('null content defaults to empty string', () {
        final n = NoteModel.fromMap('n1', <String, dynamic>{
          'bookId': 'b1',
          'title': 'T',
          'content': null,
          'updatedAt': fixedDate.toIso8601String(),
        });
        expect(n.content, '');
      });

      test('null updatedAt falls back to DateTime.now() (does not throw)', () {
        expect(
          () => NoteModel.fromMap('n1', <String, dynamic>{
            'bookId': 'b1',
            'title': 'T',
            'content': 'C',
            'updatedAt': null,
          }),
          returnsNormally,
        );
      });

      test('empty map does not throw', () {
        expect(() => NoteModel.fromMap('n1', {}), returnsNormally);
      });

      test('empty map produces empty-string defaults', () {
        final n = NoteModel.fromMap('n1', {});
        expect(n.id, 'n1');
        expect(n.bookId, '');
        expect(n.title, '');
        expect(n.content, '');
      });
    });

    // -----------------------------------------------------------------------
    // toMap → fromMap round-trip
    // -----------------------------------------------------------------------

    group('toMap → fromMap round-trip', () {
      test('preserves all fields', () {
        final original = NoteModel(
          id: 'n99',
          bookId: 'b99',
          title: 'Deep Thought',
          content: 'The answer is 42.',
          updatedAt: fixedDate,
        );
        final map = original.toMap();
        final reconstructed = NoteModel.fromMap('n99', map);

        expect(reconstructed.id, original.id);
        expect(reconstructed.bookId, original.bookId);
        expect(reconstructed.title, original.title);
        expect(reconstructed.content, original.content);
        expect(reconstructed.updatedAt, original.updatedAt);
      });

      test('updatedAt survives serialisation without microsecond drift', () {
        final n = NoteModel(
          id: 'n1',
          bookId: 'b1',
          title: 'T',
          content: 'C',
          updatedAt: DateTime.utc(2025, 3, 10, 9, 0, 0, 250),
        );
        final back = NoteModel.fromMap('n1', n.toMap());
        expect(
          back.updatedAt.millisecondsSinceEpoch,
          n.updatedAt.millisecondsSinceEpoch,
        );
      });

      test('multi-line content round-trips without truncation', () {
        const longContent = 'Line 1\nLine 2\nLine 3\n\nLast line.';
        final n = NoteModel(
          id: 'n1',
          bookId: 'b1',
          title: 'Multi',
          content: longContent,
          updatedAt: fixedDate,
        );
        final back = NoteModel.fromMap('n1', n.toMap());
        expect(back.content, longContent);
      });
    });
  });
}
