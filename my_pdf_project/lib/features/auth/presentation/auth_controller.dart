import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_model.dart';
import 'auth_providers.dart';

enum AuthStatus { idle, loading, success, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final UserModel? user;

  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.user,
  });

  AuthState copyWith({AuthStatus? status, String? errorMessage, UserModel? user}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      user: user ?? this.user,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthController(this._ref) : super(const AuthState());

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);
    final result = await _ref.read(authRepositoryProvider).login(email: email, password: password);
    return result.fold(
      (failure) {
        state = AuthState(status: AuthStatus.error, errorMessage: failure.message);
        return false;
      },
      (user) {
        state = AuthState(status: AuthStatus.success, user: user);
        return true;
      },
    );
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    final result = await _ref.read(authRepositoryProvider).register(
      name: name,
      email: email,
      password: password,
    );
    return result.fold(
      (failure) {
        state = AuthState(status: AuthStatus.error, errorMessage: failure.message);
        return false;
      },
      (user) {
        state = AuthState(status: AuthStatus.success, user: user);
        return true;
      },
    );
  }

  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).logout();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(status: AuthStatus.idle);
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
