import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';

void main() {
  group('UserModel', () {
    const user = UserModel(uid: 'u1', name: 'Alice', email: 'alice@test.com');

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
      expect(map.containsKey('uid'), isFalse);
    });

    test('copyWith with no args keeps everything', () {
      final clone = user.copyWith();
      expect(clone.uid, user.uid);
      expect(clone.name, user.name);
      expect(clone.email, user.email);
    });

    test('copyWith can override uid (e.g. linking accounts)', () {
      final updated = user.copyWith(uid: 'u2');
      expect(updated.uid, 'u2');
      expect(updated.name, 'Alice');
      expect(updated.email, 'alice@test.com');
    });

    test('copyWith can override email', () {
      final updated = user.copyWith(email: 'new@example.com');
      expect(updated.email, 'new@example.com');
      expect(updated.uid, 'u1');
      expect(updated.name, 'Alice');
    });

    test('handles unicode name and email', () {
      const u = UserModel(uid: 'u9', name: '日本語名前', email: 'tëst@ïdn.中国');
      expect(u.toMap(), {'name': '日本語名前', 'email': 'tëst@ïdn.中国'});
    });
  });
}
