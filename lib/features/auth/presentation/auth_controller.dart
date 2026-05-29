import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/local/app_pin_service.dart';
import '../../../core/local/app_pin_session.dart';
import '../../library/presentation/library_providers.dart';
import '../domain/user_model.dart';
import 'auth_providers.dart';

part 'auth_controller.g.dart';

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

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    Object? errorMessage = _sentinel,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      user: user ?? this.user,
    );
  }

  static const _sentinel = Object();
}

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  AuthState build() => const AuthState();

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);
    final result = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    return result.fold(
      (failure) {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: failure.message,
        );
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
    final result = await ref
        .read(authRepositoryProvider)
        .register(name: name, email: email, password: password);
    return result.fold(
      (failure) {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: failure.message,
        );
        return false;
      },
      (user) {
        state = AuthState(status: AuthStatus.success, user: user);
        return true;
      },
    );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    // Clear local user-scoped state so the next account doesn't inherit
    // the previous user's "Recently Opened" rail.
    try {
      await ref.read(recentBooksServiceProvider).clear();
    } catch (_) {
      /* best-effort */
    }
    await ref.read(appPinServiceProvider).clearPin();
    ref.read(appPinSessionProvider.notifier).lock();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(status: AuthStatus.idle);
}
