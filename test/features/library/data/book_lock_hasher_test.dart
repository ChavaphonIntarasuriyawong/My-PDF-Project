import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/library/data/book_lock_hasher.dart';

void main() {
  group('BookLockHasher', () {
    test('hash + verify roundtrip succeeds for the right PIN', () {
      final stored = BookLockHasher.hash('123456');
      expect(stored, isNotEmpty);
      // SHA-256 crypt modular format always starts with `$5$`.
      expect(stored.startsWith(r'$5$'), isTrue);
      expect(BookLockHasher.verify('123456', stored), isTrue);
    });

    test('verify rejects the wrong PIN', () {
      final stored = BookLockHasher.hash('123456');
      expect(BookLockHasher.verify('654321', stored), isFalse);
      expect(BookLockHasher.verify('', stored), isFalse);
      expect(BookLockHasher.verify('1234567', stored), isFalse);
    });

    test('salt is unique per call (same PIN hashes to different strings)', () {
      final a = BookLockHasher.hash('123456');
      final b = BookLockHasher.hash('123456');
      expect(a, isNot(equals(b)));
      // Both still verify against the original PIN — fresh salt does not
      // break correctness, only deterministic equality.
      expect(BookLockHasher.verify('123456', a), isTrue);
      expect(BookLockHasher.verify('123456', b), isTrue);
    });

    test(
      'verify returns false on a malformed stored hash instead of throwing',
      () {
        // Plain text — exercises the FormatException branch (no `$` segments).
        expect(BookLockHasher.verify('123456', 'not-a-crypt-string'), isFalse);
        expect(BookLockHasher.verify('123456', ''), isFalse);
        // Truncated crypt string — exercises the RangeError branch where the
        // parser tries to slice past the end of a too-short field.
        expect(BookLockHasher.verify('123456', r'$5$'), isFalse);
        expect(BookLockHasher.verify('123456', r'$5$salt'), isFalse);
      },
    );
  });
}
