import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';

void main() {
  group('UserModel', () {
    const user = UserModel(uid: 'u1', name: 'Alice', email: 'alice@test.com', avatarUrl: 'https://img');

    test('copyWith overrides given fields', () {
      final updated = user.copyWith(name: 'Bob');
      expect(updated.name, 'Bob');
      expect(updated.uid, 'u1');
      expect(updated.email, 'alice@test.com');
    });

    test('toMap excludes uid', () {
      final map = user.toMap();
      expect(map['name'], 'Alice');
      expect(map['email'], 'alice@test.com');
      expect(map['avatarUrl'], 'https://img');
      expect(map.containsKey('uid'), isFalse);
    });

    test('avatarUrl defaults to empty string', () {
      const u = UserModel(uid: 'x', name: 'X', email: 'x@x.com');
      expect(u.avatarUrl, '');
    });
  });
}
