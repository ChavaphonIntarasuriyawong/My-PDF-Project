import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory session flag: true = the user has entered the correct app-level
/// PIN this session (or just set one for the first time). Resets to false on
/// logout. NOT persisted — killing the app re-locks on next open.
class AppPinSession extends StateNotifier<bool> {
  AppPinSession() : super(false);

  /// Mark the session as unlocked (PIN verified or just set for the first time).
  void unlock() => state = true;

  /// Re-lock the session (called on logout).
  void lock() => state = false;
}

final appPinSessionProvider = StateNotifierProvider<AppPinSession, bool>(
  (ref) => AppPinSession(),
);
