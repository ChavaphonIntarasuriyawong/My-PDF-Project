// Wave 4 (OCR fallback) — focused round-trip suite for `BookModel.needsOcr`.
//
// Coverage of the field is also present in `test/models/book_model_test.dart`,
// but Wave 4's QA mandate (per the OCR plan) calls for a dedicated file
// scoped to the new field so future schema work can find it without sifting
// through unrelated assertions. The two suites are intentionally redundant —
// if either drifts, the other catches it.
//
// `BookModel` uses `toMap`/`fromMap` (Firestore semantics), not `toJson`. Tests
// here pin the on-disk shape that ships in the current Wave 1 implementation.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';

const _baseBook = BookModel(
  id: 'b1',
  title: 'Test Book',
  link: 'https://pdf.url/test.pdf',
  totalPages: 10,
  currentPage: 0,
  progress: 0,
  status: 'reading',
  shelfId: 's1',
  ownerId: 'u1',
);

void main() {
  group('BookModel.needsOcr', () {
    test('defaults to false on the const constructor', () {
      expect(_baseBook.needsOcr, isFalse);
    });

    test('fromMap with the field absent defaults to false (legacy doc)', () {
      // Books written before Wave 1 have no `needsOcr` field. The reader's
      // OCR-skip heuristic depends on this default never flipping.
      final m = BookModel.fromMap('legacy', {
        'title': 'Legacy',
        'link': 'https://pdf.url',
        'totalPages': 1,
        'currentPage': 0,
        'status': 'reading',
        'shelfId': 's1',
        'ownerId': 'u1',
      });
      expect(m.needsOcr, isFalse);
    });

    test('fromMap with needsOcr=true persists', () {
      final m = BookModel.fromMap('b1', {
        'title': 'Scanned',
        'link': 'https://pdf.url',
        'totalPages': 1,
        'currentPage': 0,
        'status': 'reading',
        'shelfId': 's1',
        'ownerId': 'u1',
        'needsOcr': true,
      });
      expect(m.needsOcr, isTrue);
    });

    test('fromMap with needsOcr=false explicit persists', () {
      final m = BookModel.fromMap('b1', {
        'title': 'Born digital',
        'link': 'https://pdf.url',
        'totalPages': 1,
        'currentPage': 0,
        'status': 'reading',
        'shelfId': 's1',
        'ownerId': 'u1',
        'needsOcr': false,
      });
      expect(m.needsOcr, isFalse);
    });

    test('fromMap with explicit null needsOcr defaults to false', () {
      // null is the one non-bool value the current `as bool?` cast tolerates —
      // every other non-bool input throws a TypeError (see the next test).
      final m = BookModel.fromMap('b1', {
        'title': 'x',
        'link': '',
        'totalPages': 1,
        'currentPage': 0,
        'status': 'reading',
        'shelfId': 's1',
        'ownerId': 'u1',
        'needsOcr': null,
      });
      expect(m.needsOcr, isFalse);
    });

    test('fromMap on garbage non-bool value degrades to false', () {
      // BUG-WAVE4-001 (qa_engineer find, fixed by flutter_engineer):
      // `book_model.dart` previously parsed `map['needsOcr'] as bool? ?? false`,
      // which threw TypeError on any non-null non-bool value (e.g. a
      // stringified "true" from a flaky import tool). The fromMap now uses
      // `rawNeedsOcr is bool ? rawNeedsOcr : false` so legacy / corrupted docs
      // degrade gracefully to `needsOcr=false` instead of refusing to load.
      // This test pins the new safe behaviour.
      for (final junk in <Object>[
        'true', // stringified bool
        1, // int (truthy in JS, ignored here)
        'yes',
      ]) {
        final m = BookModel.fromMap('b1', {
          'title': 'x',
          'link': '',
          'totalPages': 1,
          'currentPage': 0,
          'status': 'reading',
          'shelfId': 's1',
          'ownerId': 'u1',
          'needsOcr': junk,
        });
        expect(m.needsOcr, isFalse, reason: 'junk value: $junk');
      }
    });

    test('toMap always includes needsOcr (even when false)', () {
      // Critical: a partial Firestore write that round-trips through this map
      // must NOT drop the field, otherwise a `needsOcr=true` doc could be
      // accidentally reset by an unrelated update.
      final map = _baseBook.toMap();
      expect(map.containsKey('needsOcr'), isTrue);
      expect(map['needsOcr'], isFalse);
    });

    test('toMap serialises needsOcr=true', () {
      final scanned = _baseBook.copyWith(needsOcr: true);
      final map = scanned.toMap();
      expect(map['needsOcr'], isTrue);
    });

    test('toMap then fromMap round-trips needsOcr=true', () {
      final scanned = _baseBook.copyWith(needsOcr: true);
      final reconstructed = BookModel.fromMap(scanned.id, scanned.toMap());
      expect(reconstructed.needsOcr, isTrue);
    });

    test('toMap then fromMap round-trips needsOcr=false', () {
      final reconstructed = BookModel.fromMap(_baseBook.id, _baseBook.toMap());
      expect(reconstructed.needsOcr, isFalse);
    });

    test('copyWith without needsOcr preserves the existing value', () {
      final scanned = _baseBook.copyWith(needsOcr: true);
      final renamed = scanned.copyWith(title: 'Renamed');
      expect(renamed.needsOcr, isTrue);
    });

    test('copyWith(needsOcr: false) flips a true back to false', () {
      final scanned = _baseBook.copyWith(needsOcr: true);
      final cleared = scanned.copyWith(needsOcr: false);
      expect(cleared.needsOcr, isFalse);
    });
  });
}
