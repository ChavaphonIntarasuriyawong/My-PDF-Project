// Comprehensive unit tests for BookModel (lib/features/library/domain/book_model.dart).
//
// NOTE: needsOcr-specific tests live in book_model_needs_ocr_test.dart (by
// design, per Wave-4 QA plan). This file covers the rest of BookModel:
//   - constructor + defaults
//   - progress calculation in fromMap()
//   - lastReadAt ISO-8601 parsing
//   - PIN-lock fields (isLocked, lockHash)
//   - optional author/year fields
//   - toMap() completeness
//   - fromMap() resilience (missing keys, null values, non-bool booleans)
//   - copyWith() exhaustive override tests
//   - full toMap → fromMap round-trip

import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';

const _base = BookModel(
  id: 'b1',
  title: 'Flutter in Action',
  link: 'https://pdf.url/flutter.pdf',
  totalPages: 200,
  currentPage: 50,
  progress: 25.0,
  status: 'reading',
  shelfId: 's1',
  ownerId: 'u1',
);

void main() {
  group('BookModel', () {
    // -----------------------------------------------------------------------
    // Constructor defaults
    // -----------------------------------------------------------------------

    group('constructor defaults', () {
      test('needsOcr defaults to false', () => expect(_base.needsOcr, isFalse));
      test('isLocked defaults to false', () => expect(_base.isLocked, isFalse));
      test('lockHash defaults to null', () => expect(_base.lockHash, isNull));
      test(
        'lastReadAt defaults to null',
        () => expect(_base.lastReadAt, isNull),
      );
      test('author defaults to null', () => expect(_base.author, isNull));
      test('year defaults to null', () => expect(_base.year, isNull));
    });

    // -----------------------------------------------------------------------
    // Progress calculation in fromMap()
    // -----------------------------------------------------------------------

    group('fromMap() — progress calculation', () {
      BookModel make({required int total, required int current}) =>
          BookModel.fromMap('id', {
            'title': 'T',
            'link': 'l',
            'totalPages': total,
            'currentPage': current,
            'status': 'reading',
            'shelfId': 's1',
            'ownerId': 'u1',
          });

      test('50/200 → 25%', () {
        final b = make(total: 200, current: 50);
        expect(b.progress, closeTo(25.0, 0.001));
      });

      test('0/0 total → 0% (no divide-by-zero)', () {
        final b = make(total: 0, current: 0);
        expect(b.progress, 0.0);
      });

      test('100/100 → 100%', () {
        final b = make(total: 100, current: 100);
        expect(b.progress, closeTo(100.0, 0.001));
      });

      test('1/3 → ~33.33%', () {
        final b = make(total: 3, current: 1);
        expect(b.progress, closeTo(33.333, 0.001));
      });

      test('missing totalPages defaults to 0', () {
        final b = BookModel.fromMap('id', {
          'title': 'T',
          'link': 'l',
          'currentPage': 5,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
        });
        expect(b.totalPages, 0);
        expect(b.progress, 0.0);
      });
    });

    // -----------------------------------------------------------------------
    // lastReadAt ISO-8601 parsing
    // -----------------------------------------------------------------------

    group('fromMap() — lastReadAt', () {
      test('parses valid ISO-8601 string', () {
        final b = BookModel.fromMap('id', {
          'title': 'T',
          'link': 'l',
          'totalPages': 1,
          'currentPage': 0,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
          'lastReadAt': '2024-03-15T10:30:00.000Z',
        });
        expect(b.lastReadAt, isNotNull);
        expect(b.lastReadAt!.year, 2024);
        expect(b.lastReadAt!.month, 3);
        expect(b.lastReadAt!.day, 15);
      });

      test('null lastReadAt → null field', () {
        final b = BookModel.fromMap('id', {
          'title': 'T',
          'link': 'l',
          'totalPages': 1,
          'currentPage': 0,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
          'lastReadAt': null,
        });
        expect(b.lastReadAt, isNull);
      });

      test('absent lastReadAt → null field', () {
        final b = BookModel.fromMap('id', {
          'title': 'T',
          'link': 'l',
          'totalPages': 1,
          'currentPage': 0,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
        });
        expect(b.lastReadAt, isNull);
      });

      test('garbled date string → null (DateTime.tryParse returns null)', () {
        final b = BookModel.fromMap('id', {
          'title': 'T',
          'link': 'l',
          'totalPages': 1,
          'currentPage': 0,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
          'lastReadAt': 'not-a-date',
        });
        expect(b.lastReadAt, isNull);
      });

      test('toMap serialises lastReadAt as ISO-8601 string', () {
        final dt = DateTime.utc(2024, 6, 1, 12, 0);
        final b = _base.copyWith(lastReadAt: dt);
        final map = b.toMap();
        expect(map['lastReadAt'], dt.toIso8601String());
      });

      test('null lastReadAt serialises as null in toMap()', () {
        final map = _base.toMap(); // _base has no lastReadAt
        expect(map['lastReadAt'], isNull);
      });
    });

    // -----------------------------------------------------------------------
    // PIN-lock fields
    // -----------------------------------------------------------------------

    group('PIN-lock fields (isLocked / lockHash)', () {
      test('fromMap with isLocked=true and lockHash persists', () {
        final b = BookModel.fromMap('id', {
          'title': 'Locked',
          'link': 'l',
          'totalPages': 1,
          'currentPage': 0,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
          'isLocked': true,
          'lockHash': r'$5$salt$hashvalue',
        });
        expect(b.isLocked, isTrue);
        expect(b.lockHash, r'$5$salt$hashvalue');
      });

      test('fromMap with isLocked=false and no hash', () {
        final b = BookModel.fromMap('id', {
          'title': 'Unlocked',
          'link': 'l',
          'totalPages': 1,
          'currentPage': 0,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
          'isLocked': false,
        });
        expect(b.isLocked, isFalse);
        expect(b.lockHash, isNull);
      });

      test('fromMap absent isLocked defaults to false (backward compat)', () {
        final b = BookModel.fromMap('id', {
          'title': 'Legacy',
          'link': 'l',
          'totalPages': 1,
          'currentPage': 0,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
        });
        expect(b.isLocked, isFalse);
      });

      test('fromMap non-bool isLocked degrades to false', () {
        for (final junk in <Object>['true', 1, 'yes']) {
          final b = BookModel.fromMap('id', {
            'title': 'T',
            'link': 'l',
            'totalPages': 1,
            'currentPage': 0,
            'status': 'reading',
            'shelfId': 's1',
            'ownerId': 'u1',
            'isLocked': junk,
          });
          expect(b.isLocked, isFalse, reason: 'junk value: $junk');
        }
      });

      test('toMap includes isLocked and lockHash keys', () {
        final map = _base.toMap();
        expect(map.containsKey('isLocked'), isTrue);
        expect(map.containsKey('lockHash'), isTrue);
      });

      test('toMap → fromMap round-trips locked book', () {
        const locked = BookModel(
          id: 'b2',
          title: 'Secret',
          link: 'l',
          totalPages: 10,
          currentPage: 0,
          progress: 0,
          status: 'reading',
          shelfId: 's1',
          ownerId: 'u1',
          isLocked: true,
          lockHash: r'$5$abc$xyz',
        );
        final reconstructed = BookModel.fromMap('b2', locked.toMap());
        expect(reconstructed.isLocked, isTrue);
        expect(reconstructed.lockHash, r'$5$abc$xyz');
      });
    });

    // -----------------------------------------------------------------------
    // Optional author / year
    // -----------------------------------------------------------------------

    group('optional author and year', () {
      test('fromMap with author and year persists', () {
        final b = BookModel.fromMap('id', {
          'title': 'T',
          'link': 'l',
          'totalPages': 1,
          'currentPage': 0,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
          'author': 'George Orwell',
          'year': 1949,
        });
        expect(b.author, 'George Orwell');
        expect(b.year, 1949);
      });

      test('absent author and year → null', () {
        final b = BookModel.fromMap('id', {
          'title': 'T',
          'link': 'l',
          'totalPages': 1,
          'currentPage': 0,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
        });
        expect(b.author, isNull);
        expect(b.year, isNull);
      });

      test('year stored as double (Firestore num) is cast to int', () {
        final b = BookModel.fromMap('id', {
          'title': 'T',
          'link': 'l',
          'totalPages': 1,
          'currentPage': 0,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
          'year': 1984.0, // Firestore can return doubles
        });
        expect(b.year, 1984);
        expect(b.year, isA<int>());
      });
    });

    // -----------------------------------------------------------------------
    // toMap() completeness
    // -----------------------------------------------------------------------

    group('toMap()', () {
      test('contains all expected keys', () {
        final map = _base.toMap();
        for (final key in [
          'title',
          'link',
          'totalPages',
          'currentPage',
          'progress',
          'status',
          'shelfId',
          'ownerId',
          'lastReadAt',
          'author',
          'year',
          'needsOcr',
          'isLocked',
          'lockHash',
        ]) {
          expect(map.containsKey(key), isTrue, reason: 'Missing key: $key');
        }
      });

      test('does not include id (Firestore document ID)', () {
        expect(_base.toMap().containsKey('id'), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() resilience
    // -----------------------------------------------------------------------

    group('fromMap() resilience', () {
      test('empty map produces safe defaults without throwing', () {
        final b = BookModel.fromMap('id', {});
        expect(b.id, 'id');
        expect(b.title, '');
        expect(b.link, '');
        expect(b.totalPages, 0);
        expect(b.currentPage, 0);
        expect(b.progress, 0.0);
        expect(b.status, 'reading');
        expect(b.shelfId, '');
        expect(b.ownerId, '');
        expect(b.isLocked, isFalse);
        expect(b.needsOcr, isFalse);
      });

      test('status missing → defaults to "reading"', () {
        final b = BookModel.fromMap('id', {
          'title': 'T',
          'link': 'l',
          'totalPages': 1,
          'currentPage': 0,
          'shelfId': 's1',
          'ownerId': 'u1',
        });
        expect(b.status, 'reading');
      });
    });

    // -----------------------------------------------------------------------
    // copyWith()
    // -----------------------------------------------------------------------

    group('copyWith()', () {
      test('no-arg copyWith is equivalent', () {
        final copy = _base.copyWith();
        expect(copy.id, _base.id);
        expect(copy.title, _base.title);
        expect(copy.status, _base.status);
      });

      test('copyWith(title:) changes title only', () {
        final copy = _base.copyWith(title: 'New Title');
        expect(copy.title, 'New Title');
        expect(copy.id, _base.id);
        expect(copy.status, _base.status);
      });

      test('copyWith(status:) changes status only', () {
        final copy = _base.copyWith(status: 'finished');
        expect(copy.status, 'finished');
        expect(copy.title, _base.title);
      });

      test('copyWith(currentPage:) updates currentPage', () {
        final copy = _base.copyWith(currentPage: 100);
        expect(copy.currentPage, 100);
      });

      test('copyWith(isLocked: true) locks the book', () {
        final locked = _base.copyWith(isLocked: true, lockHash: 'hash');
        expect(locked.isLocked, isTrue);
        expect(locked.lockHash, 'hash');
        expect(locked.id, _base.id);
      });

      test('copyWith(isLocked: false) unlocks the book', () {
        const locked = BookModel(
          id: 'b2',
          title: 'T',
          link: 'l',
          totalPages: 1,
          currentPage: 0,
          progress: 0,
          status: 'reading',
          shelfId: 's1',
          ownerId: 'u1',
          isLocked: true,
          lockHash: 'hash',
        );
        final unlocked = locked.copyWith(isLocked: false);
        expect(unlocked.isLocked, isFalse);
      });

      test('copyWith preserves ownerId (it is immutable)', () {
        final copy = _base.copyWith(title: 'Changed');
        expect(copy.ownerId, _base.ownerId);
      });

      test('original is not mutated', () {
        _base.copyWith(title: 'Mutated?');
        expect(_base.title, 'Flutter in Action');
      });
    });

    // -----------------------------------------------------------------------
    // Full toMap → fromMap round-trip
    // -----------------------------------------------------------------------

    group('toMap → fromMap round-trip', () {
      test('default book round-trips without loss', () {
        final map = _base.toMap();
        final b = BookModel.fromMap(_base.id, map);

        expect(b.id, _base.id);
        expect(b.title, _base.title);
        expect(b.link, _base.link);
        expect(b.totalPages, _base.totalPages);
        expect(b.currentPage, _base.currentPage);
        expect(b.status, _base.status);
        expect(b.shelfId, _base.shelfId);
        expect(b.ownerId, _base.ownerId);
        expect(b.isLocked, _base.isLocked);
        expect(b.needsOcr, _base.needsOcr);
      });

      test('book with all optional fields round-trips', () {
        final dt = DateTime.utc(2025, 1, 1);
        const full = BookModel(
          id: 'bf',
          title: 'Full Book',
          link: 'https://pdf.url/full.pdf',
          totalPages: 300,
          currentPage: 150,
          progress: 50.0,
          status: 'on_hold',
          shelfId: 's2',
          ownerId: 'u2',
          author: 'Author Name',
          year: 2020,
          needsOcr: true,
          isLocked: true,
          lockHash: r'$5$salt$hash',
        );
        final fullWithDate = full.copyWith(lastReadAt: dt);
        final map = fullWithDate.toMap();
        final b = BookModel.fromMap('bf', map);

        expect(b.author, 'Author Name');
        expect(b.year, 2020);
        expect(b.needsOcr, isTrue);
        expect(b.isLocked, isTrue);
        expect(b.lockHash, r'$5$salt$hash');
        expect(b.lastReadAt?.year, 2025);
      });
    });
  });
}
