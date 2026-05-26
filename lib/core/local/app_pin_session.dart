import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_pin_session.g.dart';

/// In-memory session flag: true = the user has entered the correct app-level
/// PIN this session (or just set one for the first time). Resets to false on
/// logout. NOT persisted — killing the app re-locks on next open.
@Riverpod(keepAlive: true)
class AppPinSession extends _$AppPinSession {
  @override
  bool build() => false;

  /// Mark the session as unlocked (PIN verified or just set for the first time).
  void unlock() => state = true;

  /// Re-lock the session (called on logout).
  void lock() => state = false;
}
