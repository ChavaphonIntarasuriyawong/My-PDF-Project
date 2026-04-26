import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/errors/failures.dart';
import '../domain/auth_repository.dart';
import '../domain/user_model.dart';
import 'firebase_auth_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  static String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak — use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'Email sign-in is not enabled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _dataSource.login(email: email, password: password);
      return Right(user);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_friendlyError(e)));
    } catch (_) {
      return const Left(ServerFailure('Something went wrong. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, UserModel>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final user = await _dataSource.register(name: name, email: email, password: password);
      return Right(user);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_friendlyError(e)));
    } catch (_) {
      return const Left(ServerFailure('Something went wrong. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _dataSource.logout();
      return const Right(null);
    } catch (_) {
      return const Left(ServerFailure('Logout failed.'));
    }
  }

  @override
  Stream<UserModel?> authStateChanges() => _dataSource.authStateChanges();

  @override
  UserModel? get currentUser => _dataSource.currentUser;
}
