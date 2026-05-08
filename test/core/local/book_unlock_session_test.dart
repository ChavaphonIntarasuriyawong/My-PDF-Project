import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/core/local/book_unlock_session.dart';

void main() {
  group('BookUnlockSession', () {
    test('initially nothing is unlocked', () {
      final session = BookUnlockSession();
      expect(session.isUnlocked('b1'), isFalse);
      expect(session.isUnlocked(''), isFalse);
    });

    test('markUnlocked then isUnlocked returns true for that book only', () {
      final session = BookUnlockSession();
      session.markUnlocked('b1');
      expect(session.isUnlocked('b1'), isTrue);
      expect(session.isUnlocked('b2'), isFalse);
    });

    test('lock removes a single entry without touching the rest', () {
      final session = BookUnlockSession();
      session.markUnlocked('b1');
      session.markUnlocked('b2');
      session.lock('b1');
      expect(session.isUnlocked('b1'), isFalse);
      expect(session.isUnlocked('b2'), isTrue);
    });

    test('lock on an unknown bookId is a no-op', () {
      final session = BookUnlockSession();
      session.markUnlocked('b1');
      session.lock('nonexistent');
      expect(session.isUnlocked('b1'), isTrue);
    });

    test('clear empties the session', () {
      final session = BookUnlockSession();
      session.markUnlocked('b1');
      session.markUnlocked('b2');
      session.markUnlocked('b3');
      session.clear();
      expect(session.isUnlocked('b1'), isFalse);
      expect(session.isUnlocked('b2'), isFalse);
      expect(session.isUnlocked('b3'), isFalse);
    });

    test('markUnlocked is idempotent (Set semantics)', () {
      final session = BookUnlockSession();
      session.markUnlocked('b1');
      session.markUnlocked('b1');
      session.lock('b1');
      // Single lock removes a single Set entry — no need to call lock twice.
      expect(session.isUnlocked('b1'), isFalse);
    });
  });
}
