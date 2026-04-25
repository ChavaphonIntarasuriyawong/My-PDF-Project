import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/core/errors/failures.dart';
import 'package:my_pdf/features/auth/domain/auth_repository.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_controller.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';

class _FakeRepo implements AuthRepository {
  Either<Failure, UserModel>? loginResult;
  Either<Failure, UserModel>? registerResult;

  @override
  Future<Either<Failure, UserModel>> login({required String email, required String password}) async =>
      loginResult!;

  @override
  Future<Either<Failure, UserModel>> register({required String name, required String email, required String password}) async =>
      registerResult!;

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Stream<UserModel?> authStateChanges() => const Stream.empty();

  @override
  UserModel? get currentUser => null;
}

ProviderContainer _makeContainer(_FakeRepo repo) {
  return ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
}

void main() {
  group('AuthController', () {
    late _FakeRepo repo;
    late ProviderContainer container;

    setUp(() {
      repo = _FakeRepo();
      container = _makeContainer(repo);
    });

    tearDown(() => container.dispose());

    test('initial state is idle', () {
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.idle);
    });

    test('login success sets status=success and user', () async {
      const user = UserModel(uid: 'u1', name: 'Alice', email: 'a@b.com');
      repo.loginResult = const Right(user);

      final result = await container.read(authControllerProvider.notifier).login(
        email: 'a@b.com',
        password: 'pass',
      );

      expect(result, isTrue);
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.success);
      expect(state.user?.uid, 'u1');
    });

    test('login failure sets status=error with message', () async {
      repo.loginResult = const Left(AuthFailure('Wrong password'));

      final result = await container.read(authControllerProvider.notifier).login(
        email: 'a@b.com',
        password: 'wrong',
      );

      expect(result, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, 'Wrong password');
    });

    test('register success sets status=success', () async {
      const user = UserModel(uid: 'u2', name: 'Bob', email: 'b@b.com');
      repo.registerResult = const Right(user);

      final result = await container.read(authControllerProvider.notifier).register(
        name: 'Bob',
        email: 'b@b.com',
        password: 'pass',
      );

      expect(result, isTrue);
      expect(container.read(authControllerProvider).status, AuthStatus.success);
    });

    test('register failure sets status=error', () async {
      repo.registerResult = const Left(AuthFailure('Email already in use'));

      final result = await container.read(authControllerProvider.notifier).register(
        name: 'Bob',
        email: 'b@b.com',
        password: 'pass',
      );

      expect(result, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, 'Email already in use');
    });

    test('logout resets state to idle', () async {
      const user = UserModel(uid: 'u1', name: 'Alice', email: 'a@b.com');
      repo.loginResult = const Right(user);
      await container.read(authControllerProvider.notifier).login(email: 'a@b.com', password: 'p');

      await container.read(authControllerProvider.notifier).logout();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.idle);
      expect(state.user, isNull);
    });

    test('clearError resets status to idle', () async {
      repo.loginResult = const Left(AuthFailure('Bad creds'));
      await container.read(authControllerProvider.notifier).login(email: 'x', password: 'y');
      expect(container.read(authControllerProvider).status, AuthStatus.error);

      container.read(authControllerProvider.notifier).clearError();

      expect(container.read(authControllerProvider).status, AuthStatus.idle);
    });
  });
}
