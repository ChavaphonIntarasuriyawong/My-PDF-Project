import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import 'user_model.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserModel>> register({
    required String name,
    required String email,
    required String password,
  });

  Future<Either<Failure, void>> logout();

  Stream<UserModel?> authStateChanges();

  UserModel? get currentUser;
}
