// Unit tests for BookshelfModel (lib/features/library/domain/bookshelf_model.dart).
//
// Coverage goals:
//   - constructor + field access
//   - toMap() serialisation
//   - fromMap() deserialisation (happy path + missing/null fields)
//   - createdAt ISO-8601 parsing and fallback
//   - toMap → fromMap round-trip

import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';

void main() {
  final fixedDate = DateTime.utc(2024, 1, 15, 8, 0, 0);

  group('BookshelfModel', () {
    // -----------------------------------------------------------------------
    // Constructor & field access
    // -----------------------------------------------------------------------

    group('constructor', () {
      test('stores all fields', () {
        final s = BookshelfModel(
          id: 's1',
          name: 'Favourites',
          ownerId: 'u1',
          createdAt: fixedDate,
        );

        expect(s.id, 's1');
        expect(s.name, 'Favourites');
        expect(s.ownerId, 'u1');
        expect(s.createdAt, fixedDate);
      });
    });

    // -----------------------------------------------------------------------
    // toMap()
    // -----------------------------------------------------------------------

    group('toMap()', () {
      test('contains name, ownerId, createdAt — omits id', () {
        final s = BookshelfModel(
          id: 's1',
          name: 'Reads',
          ownerId: 'u1',
          createdAt: fixedDate,
        );
        final map = s.toMap();

        expect(map['name'], 'Reads');
        expect(map['ownerId'], 'u1');
        expect(map['createdAt'], fixedDate.toIso8601String());
        expect(map.containsKey('id'), isFalse);
      });

      test('toMap() returns exactly 3 keys', () {
        final s = BookshelfModel(
          id: 's1',
          name: 'Test',
          ownerId: 'u1',
          createdAt: fixedDate,
        );
        expect(s.toMap().keys.length, 3);
      });

      test('createdAt is serialised as ISO-8601 string', () {
        final s = BookshelfModel(
          id: 's1',
          name: 'Test',
          ownerId: 'u1',
          createdAt: fixedDate,
        );
        expect(s.toMap()['createdAt'], isA<String>());
        expect(s.toMap()['createdAt'], fixedDate.toIso8601String());
      });
    });

    // -----------------------------------------------------------------------
    // fromMap()
    // -----------------------------------------------------------------------

    group('fromMap()', () {
      test('round-trips a complete map', () {
        final map = {
          'name': 'Tech',
          'ownerId': 'u2',
          'createdAt': fixedDate.toIso8601String(),
        };
        final s = BookshelfModel.fromMap('s2', map);

        expect(s.id, 's2');
        expect(s.name, 'Tech');
        expect(s.ownerId, 'u2');
        expect(s.createdAt, fixedDate);
      });

      test('uses id argument as id', () {
        final s = BookshelfModel.fromMap('doc-id', {
          'name': 'X',
          'ownerId': 'u1',
          'createdAt': fixedDate.toIso8601String(),
        });
        expect(s.id, 'doc-id');
      });

      test('missing name defaults to empty string', () {
        final s = BookshelfModel.fromMap('s1', {
          'ownerId': 'u1',
          'createdAt': fixedDate.toIso8601String(),
        });
        expect(s.name, '');
      });

      test('missing ownerId defaults to empty string', () {
        final s = BookshelfModel.fromMap('s1', {
          'name': 'N',
          'createdAt': fixedDate.toIso8601String(),
        });
        expect(s.ownerId, '');
      });

      test('missing createdAt falls back to DateTime.now() (does not throw)', () {
        // DateTime.tryParse(null ?? '') returns null → fallback to DateTime.now()
        final before = DateTime.now();
        final s = BookshelfModel.fromMap('s1', {'name': 'N', 'ownerId': 'u1'});
        final after = DateTime.now();

        expect(
          s.createdAt.isAfter(before) || s.createdAt.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          s.createdAt.isBefore(after) || s.createdAt.isAtSameMomentAs(after),
          isTrue,
        );
      });

      test(
        'garbled createdAt falls back to DateTime.now() (does not throw)',
        () {
          expect(
            () => BookshelfModel.fromMap('s1', {
              'name': 'N',
              'ownerId': 'u1',
              'createdAt': 'not-a-date',
            }),
            returnsNormally,
          );
        },
      );

      test('null name defaults to empty string', () {
        final s = BookshelfModel.fromMap('s1', <String, dynamic>{
          'name': null,
          'ownerId': 'u1',
          'createdAt': fixedDate.toIso8601String(),
        });
        expect(s.name, '');
      });

      test('null ownerId defaults to empty string', () {
        final s = BookshelfModel.fromMap('s1', <String, dynamic>{
          'name': 'N',
          'ownerId': null,
          'createdAt': fixedDate.toIso8601String(),
        });
        expect(s.ownerId, '');
      });

      test('empty map does not throw', () {
        expect(() => BookshelfModel.fromMap('s1', {}), returnsNormally);
      });
    });

    // -----------------------------------------------------------------------
    // toMap → fromMap round-trip
    // -----------------------------------------------------------------------

    group('toMap → fromMap round-trip', () {
      test('preserves all fields', () {
        final original = BookshelfModel(
          id: 's99',
          name: 'Science',
          ownerId: 'u5',
          createdAt: fixedDate,
        );
        final map = original.toMap();
        final reconstructed = BookshelfModel.fromMap('s99', map);

        expect(reconstructed.id, original.id);
        expect(reconstructed.name, original.name);
        expect(reconstructed.ownerId, original.ownerId);
        expect(reconstructed.createdAt, original.createdAt);
      });

      test('createdAt survives serialisation without microsecond drift', () {
        // ISO-8601 strings are millisecond-precision; DateTime.utc is exact.
        final s = BookshelfModel(
          id: 's1',
          name: 'N',
          ownerId: 'u1',
          createdAt: DateTime.utc(2024, 6, 1, 10, 0, 0, 500),
        );
        final back = BookshelfModel.fromMap('s1', s.toMap());
        expect(
          back.createdAt.millisecondsSinceEpoch,
          s.createdAt.millisecondsSinceEpoch,
        );
      });
    });
  });
}
