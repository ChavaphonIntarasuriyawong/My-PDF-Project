import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/core/errors/failures.dart';
import 'package:my_pdf/features/auth/domain/auth_repository.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';

// ---------------------------------------------------------------------------
// Top-level fixture — must be const for use inside const Right(...).
// ---------------------------------------------------------------------------

const _kAlice = UserModel(uid: 'u1', name: 'Alice', email: 'a@b.com');

// ---------------------------------------------------------------------------
// Hand-rolled fake — the project has no mocktail/mockito in dev_dependencies.
// ---------------------------------------------------------------------------

class _FakeAuthRepository implements AuthRepository {
  Either<Failure, UserModel>? loginResult;
  Either<Failure, UserModel>? registerResult;
  Either<Failure, void>? logoutResult;
  Stream<UserModel?> Function()? authStateChangesFactory;
  UserModel? _currentUser;

  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
  }) async => loginResult!;

  @override
  Future<Either<Failure, UserModel>> register({
    required String name,
    required String email,
    required String password,
  }) async => registerResult!;

  @override
  Future<Either<Failure, void>> logout() async {
    _currentUser = null;
    return logoutResult ?? const Right(null);
  }

  @override
  Stream<UserModel?> authStateChanges() => authStateChangesFactory != null
      ? authStateChangesFactory!()
      : const Stream.empty();

  @override
  UserModel? get currentUser => _currentUser;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AuthRepository contract', () {
    late _FakeAuthRepository repo;

    setUp(() => repo = _FakeAuthRepository());

    // ---- login ----

    test('login returns Right(user) on success', () async {
      repo.loginResult = const Right(_kAlice);

      final result = await repo.login(email: 'a@b.com', password: 'correct');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (user) => expect(user.uid, 'u1'),
      );
    });

    test('login returns Left(AuthFailure) on bad credentials', () async {
      repo.loginResult = const Left(AuthFailure('Wrong password'));

      final result = await repo.login(email: 'a@b.com', password: 'bad');

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<AuthFailure>());
        expect(failure.message, 'Wrong password');
      }, (_) => fail('Expected Left'));
    });

    // ---- register ----

    test('register returns Right(user) on success', () async {
      repo.registerResult = const Right(_kAlice);

      final result = await repo.register(
        name: 'Alice',
        email: 'a@b.com',
        password: 'pass',
      );

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('Expected Right'), (user) {
        expect(user.name, 'Alice');
      });
    });

    test('register returns Left(AuthFailure) on duplicate email', () async {
      repo.registerResult = const Left(AuthFailure('Email already in use'));

      final result = await repo.register(
        name: 'Alice',
        email: 'dup@b.com',
        password: 'pass',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f.message, 'Email already in use'),
        (_) => fail('Expected Left'),
      );
    });

    // ---- logout ----

    test('logout returns Right(null) on success', () async {
      repo.logoutResult = const Right(null);
      final result = await repo.logout();
      expect(result.isRight(), isTrue);
    });

    // ---- authStateChanges ----

    test('authStateChanges returns a Stream', () {
      final ctrl = StreamController<UserModel?>();
      repo.authStateChangesFactory = () => ctrl.stream;

      final stream = repo.authStateChanges();
      expect(stream, isA<Stream<UserModel?>>());

      ctrl.close();
    });

    test('authStateChanges emits user values in order', () async {
      final ctrl = StreamController<UserModel?>();
      repo.authStateChangesFactory = () => ctrl.stream;

      final values = <UserModel?>[];
      final sub = repo.authStateChanges().listen(values.add);

      ctrl.add(_kAlice);
      ctrl.add(null);
      await ctrl.close();
      await sub.cancel();

      expect(values, [_kAlice, null]);
    });

    test('authStateChanges emits null when no user is signed in', () async {
      repo.authStateChangesFactory = () => Stream.value(null);
      final emitted = await repo.authStateChanges().first;
      expect(emitted, isNull);
    });
  });
}
