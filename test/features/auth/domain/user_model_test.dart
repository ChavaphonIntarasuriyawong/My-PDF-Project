// Unit tests for UserModel (lib/features/auth/domain/user_model.dart).
//
// Coverage goals:
//   - constructor + field access
//   - toMap() serialisation
//   - fromMap() deserialisation (happy path + missing/null fields)
//   - copyWith() with every combination of overrides
//   - default role value

import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';

void main() {
  group('UserModel', () {
    // -----------------------------------------------------------------------
    // Constructor & field access
    // -----------------------------------------------------------------------

    group('constructor', () {
      test('stores all required fields', () {
        const u = UserModel(uid: 'u1', name: 'Alice', email: 'a@b.com');
        expect(u.uid, 'u1');
        expect(u.name, 'Alice');
        expect(u.email, 'a@b.com');
      });

      test('default role is "user"', () {
        const u = UserModel(uid: 'u1', name: 'Alice', email: 'a@b.com');
        expect(u.role, 'user');
      });

      test('explicit role is stored', () {
        const u = UserModel(
          uid: 'u1',
          name: 'Alice',
          email: 'a@b.com',
          role: 'admin',
        );
        expect(u.role, 'admin');
      });
    });

    // -----------------------------------------------------------------------
    // toMap()
    // -----------------------------------------------------------------------

    group('toMap()', () {
      test('includes name, email, and role — omits uid', () {
        const u = UserModel(
          uid: 'u1',
          name: 'Alice',
          email: 'a@b.com',
          role: 'user',
        );
        final map = u.toMap();

        expect(map['name'], 'Alice');
        expect(map['email'], 'a@b.com');
        expect(map['role'], 'user');
        // uid is the Firestore document ID — not in the map.
        expect(map.containsKey('uid'), isFalse);
      });

      test('reflects admin role in toMap()', () {
        const u = UserModel(
          uid: 'u2',
          name: 'Bob',
          email: 'b@c.com',
          role: 'admin',
        );
        expect(u.toMap()['role'], 'admin');
      });

      test('toMap() returns exactly 3 keys', () {
        const u = UserModel(uid: 'u1', name: 'Alice', email: 'a@b.com');
        expect(u.toMap().keys.length, 3);
      });
    });

    // -----------------------------------------------------------------------
    // fromMap()
    // -----------------------------------------------------------------------

    group('fromMap()', () {
      test('round-trips a complete map', () {
        final map = {'name': 'Alice', 'email': 'a@b.com', 'role': 'admin'};
        final u = UserModel.fromMap('u1', map);

        expect(u.uid, 'u1');
        expect(u.name, 'Alice');
        expect(u.email, 'a@b.com');
        expect(u.role, 'admin');
      });

      test('uses uid argument as uid', () {
        final u = UserModel.fromMap('uid-from-arg', {
          'name': 'X',
          'email': 'x@y.com',
        });
        expect(u.uid, 'uid-from-arg');
      });

      test('missing name defaults to empty string', () {
        final u = UserModel.fromMap('u1', {'email': 'a@b.com', 'role': 'user'});
        expect(u.name, '');
      });

      test('missing email defaults to empty string', () {
        final u = UserModel.fromMap('u1', {'name': 'Alice', 'role': 'user'});
        expect(u.email, '');
      });

      test('missing role defaults to "user"', () {
        final u = UserModel.fromMap('u1', {
          'name': 'Alice',
          'email': 'a@b.com',
        });
        expect(u.role, 'user');
      });

      test('null name defaults to empty string', () {
        final u = UserModel.fromMap('u1', <String, dynamic>{
          'name': null,
          'email': 'a@b.com',
          'role': 'user',
        });
        expect(u.name, '');
      });

      test('null email defaults to empty string', () {
        final u = UserModel.fromMap('u1', <String, dynamic>{
          'name': 'Alice',
          'email': null,
          'role': 'user',
        });
        expect(u.email, '');
      });

      test('null role defaults to "user"', () {
        final u = UserModel.fromMap('u1', <String, dynamic>{
          'name': 'Alice',
          'email': 'a@b.com',
          'role': null,
        });
        expect(u.role, 'user');
      });

      test('empty map produces safe defaults', () {
        final u = UserModel.fromMap('u1', {});
        expect(u.uid, 'u1');
        expect(u.name, '');
        expect(u.email, '');
        expect(u.role, 'user');
      });

      test('toMap → fromMap round-trip preserves all fields', () {
        const original = UserModel(
          uid: 'u9',
          name: 'Zara',
          email: 'z@z.com',
          role: 'admin',
        );
        final reconstructed = UserModel.fromMap('u9', original.toMap());

        expect(reconstructed.uid, original.uid);
        expect(reconstructed.name, original.name);
        expect(reconstructed.email, original.email);
        expect(reconstructed.role, original.role);
      });
    });

    // -----------------------------------------------------------------------
    // copyWith()
    // -----------------------------------------------------------------------

    group('copyWith()', () {
      const base = UserModel(uid: 'u1', name: 'Alice', email: 'a@b.com');

      test('no-arg copyWith returns equivalent object', () {
        final copy = base.copyWith();
        expect(copy.uid, base.uid);
        expect(copy.name, base.name);
        expect(copy.email, base.email);
        expect(copy.role, base.role);
      });

      test('copyWith(name:) updates name only', () {
        final copy = base.copyWith(name: 'Bob');
        expect(copy.name, 'Bob');
        expect(copy.uid, base.uid);
        expect(copy.email, base.email);
        expect(copy.role, base.role);
      });

      test('copyWith(email:) updates email only', () {
        final copy = base.copyWith(email: 'new@example.com');
        expect(copy.email, 'new@example.com');
        expect(copy.name, base.name);
      });

      test('copyWith(role:) updates role only', () {
        final copy = base.copyWith(role: 'admin');
        expect(copy.role, 'admin');
        expect(copy.name, base.name);
      });

      test('copyWith(uid:) updates uid only', () {
        final copy = base.copyWith(uid: 'u99');
        expect(copy.uid, 'u99');
        expect(copy.name, base.name);
        expect(copy.email, base.email);
      });

      test('original is not mutated by copyWith', () {
        base.copyWith(name: 'Changed');
        expect(base.name, 'Alice');
      });

      test('copyWith then copyWith chains correctly', () {
        final step1 = base.copyWith(name: 'Bob');
        final step2 = step1.copyWith(role: 'admin');
        expect(step2.name, 'Bob');
        expect(step2.role, 'admin');
        expect(step2.uid, 'u1');
      });
    });
  });
}
