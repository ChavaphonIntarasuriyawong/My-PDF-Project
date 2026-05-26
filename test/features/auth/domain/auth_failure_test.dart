import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/core/errors/failures.dart';

void main() {
  group('Failure hierarchy', () {
    test('AuthFailure is a Failure', () {
      const f = AuthFailure('bad creds');
      expect(f, isA<Failure>());
    });

    test('AuthFailure.message round-trips constructor string', () {
      const msg = 'Email not found';
      const f = AuthFailure(msg);
      expect(f.message, msg);
    });

    test('ServerFailure is a Failure', () {
      const f = ServerFailure('503');
      expect(f, isA<Failure>());
    });

    test('ServerFailure.message round-trips constructor string', () {
      const msg = 'Internal server error';
      const f = ServerFailure(msg);
      expect(f.message, msg);
    });

    test('AuthFailure and ServerFailure have distinct runtime types', () {
      const a = AuthFailure('x');
      const s = ServerFailure('x');
      expect(a.runtimeType, isNot(equals(s.runtimeType)));
    });

    test('AuthFailure is const-constructible', () {
      // If this compiles and runs without error the constructor is const.
      const f1 = AuthFailure('a');
      const f2 = AuthFailure('a');
      // Two const objects with identical arguments are the same instance.
      expect(identical(f1, f2), isTrue);
    });

    test('ServerFailure is const-constructible', () {
      const f1 = ServerFailure('s');
      const f2 = ServerFailure('s');
      expect(identical(f1, f2), isTrue);
    });

    test('Different messages produce non-identical const instances', () {
      const f1 = AuthFailure('a');
      const f2 = AuthFailure('b');
      expect(identical(f1, f2), isFalse);
      expect(f1.message, 'a');
      expect(f2.message, 'b');
    });
  });
}
