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
      shelfId: 's1',
      ownerId: 'u1',
    );

    test('fromMap computes progress correctly', () {
      final m = BookModel.fromMap('b1', {
        'title': 'Test Book',
        'link': 'https://pdf.url',
        'totalPages': 200,
        'currentPage': 100,
        'status': 'reading',
        'shelfId': 's1',
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
        'shelfId': 's1',
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
        'shelfId': 's1',
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
        'shelfId': 's1',
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
      expect(map['shelfId'], 's1');
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

    // -----------------------------------------------------------------
    // needsOcr round-trip (Wave 4 OCR fallback)
    // -----------------------------------------------------------------
    // The flag is persisted on the Firestore book doc when the upload
    // probe sees no text layer. fromMap/toMap and copyWith all need to
    // carry it without surprises so the reader's text-extraction probe
    // skip is reliable.

    test('needsOcr defaults to false on the const constructor', () {
      expect(book.needsOcr, isFalse);
    });

    test('toMap serializes needsOcr=true', () {
      const scanned = BookModel(
        id: 'b1',
        title: 'Scanned Book',
        link: 'https://pdf.url',
        totalPages: 10,
        currentPage: 0,
        progress: 0,
        status: 'reading',
        shelfId: 's1',
        ownerId: 'u1',
        needsOcr: true,
      );
      expect(scanned.toMap()['needsOcr'], isTrue);
    });

    test('toMap serializes needsOcr=false explicitly', () {
      // Even though false is the default, the on-disk shape must include
      // the field so old clients don't accidentally re-write a true to
      // false during a partial update.
      expect(book.toMap()['needsOcr'], isFalse);
      expect(book.toMap().containsKey('needsOcr'), isTrue);
    });

    test('fromMap reads needsOcr=true', () {
      final m = BookModel.fromMap('b1', {
        'title': 'Scanned',
        'link': 'https://pdf.url',
        'totalPages': 10,
        'currentPage': 0,
        'status': 'reading',
        'shelfId': 's1',
        'ownerId': 'u1',
        'needsOcr': true,
      });
      expect(m.needsOcr, isTrue);
    });

    test('fromMap with missing needsOcr key defaults to false (backward compat)',
        () {
      // Existing books written before Wave 4 have no `needsOcr` field;
      // fromMap must tolerate the absence and return false.
      final m = BookModel.fromMap('legacy_book', {
        'title': 'Legacy',
        'link': 'https://pdf.url',
        'totalPages': 10,
        'currentPage': 0,
        'status': 'reading',
        'shelfId': 's1',
        'ownerId': 'u1',
      });
      expect(m.needsOcr, isFalse);
    });

    test('fromMap with explicit null needsOcr defaults to false', () {
      final m = BookModel.fromMap('b1', {
        'title': 'Book',
        'link': '',
        'totalPages': 10,
        'currentPage': 0,
        'status': 'reading',
        'shelfId': 's1',
        'ownerId': 'u1',
        'needsOcr': null,
      });
      expect(m.needsOcr, isFalse);
    });

    test('copyWith(needsOcr: true) flips the field while preserving siblings',
        () {
      final updated = book.copyWith(needsOcr: true);
      expect(updated.needsOcr, isTrue);
      expect(updated.title, book.title);
      expect(updated.link, book.link);
      expect(updated.id, book.id);
      expect(updated.ownerId, book.ownerId);
    });

    test('copyWith without needsOcr preserves the existing value', () {
      const scanned = BookModel(
        id: 'b1',
        title: 'Scanned',
        link: '',
        totalPages: 1,
        currentPage: 0,
        progress: 0,
        status: 'reading',
        shelfId: 's1',
        ownerId: 'u1',
        needsOcr: true,
      );
      // Mutating an unrelated field must not silently reset needsOcr.
      final updated = scanned.copyWith(title: 'Renamed');
      expect(updated.needsOcr, isTrue);
    });

    test('toMap then fromMap round-trips needsOcr=true', () {
      const scanned = BookModel(
        id: 'b1',
        title: 'Scanned',
        link: 'https://pdf.url',
        totalPages: 10,
        currentPage: 0,
        progress: 0,
        status: 'reading',
        shelfId: 's1',
        ownerId: 'u1',
        needsOcr: true,
      );
      final reconstructed = BookModel.fromMap('b1', scanned.toMap());
      expect(reconstructed.needsOcr, isTrue);
    });
  });
}
