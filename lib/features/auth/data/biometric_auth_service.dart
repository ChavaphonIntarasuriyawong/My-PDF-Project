// Biometric authentication service (Face ID / Touch ID / fingerprint).
//
// Thin wrapper around `package:local_auth` that:
// - Probes hardware support + enrollment.
// - Persists a per-user opt-in flag in the existing Hive `app_prefs` box
//   (key: `biometric_enabled`).
// - Provides a single `authenticate()` entry point used by the login screen
//   as an acceleration over email/password — never as the sole credential.
//
// Web: `local_auth` does not support browsers. `isDeviceSupported()` returns
// false on web and `authenticate()` is a no-op. A WebAuthn-based path is a
// future wave (out of scope here).
//
// Stateless / no Riverpod / no Firebase imports — pure data layer adapter.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/logging/app_logger.dart';

class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? auth, Box<dynamic>? prefsBox})
    : _auth = auth ?? LocalAuthentication(),
      _prefsBox = prefsBox;

  static const String _logTag = 'AUTH_BIOMETRIC';
  static const String _prefsBoxName = 'app_prefs';
  static const String _enabledKey = 'biometric_enabled';

  final LocalAuthentication _auth;
  final Box<dynamic>? _prefsBox;

  Box<dynamic> get _box => _prefsBox ?? Hive.box<dynamic>(_prefsBoxName);

  /// True only when the device exposes biometric hardware AND the user has
  /// at least one biometric enrolled. Always false on web.
  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException catch (e, st) {
      AppLogger.warn(
        _logTag,
        'isDeviceSupported failed: ${e.code}',
        error: e,
        st: st,
      );
      return false;
    }
  }

  /// Whether the current user opted in to biometric unlock.
  Future<bool> isEnabledForUser() async {
    try {
      return _box.get(_enabledKey, defaultValue: false) as bool;
    } catch (e, st) {
      AppLogger.warn(_logTag, 'isEnabledForUser read failed', error: e, st: st);
      return false;
    }
  }

  Future<void> setEnabledForUser(bool enabled) async {
    try {
      await _box.put(_enabledKey, enabled);
    } catch (e, st) {
      AppLogger.warn(_logTag, 'setEnabledForUser failed', error: e, st: st);
    }
  }

  /// Prompts the OS biometric sheet. Returns true on success, false on
  /// cancellation, lockout, missing hardware, or any platform error.
  Future<bool> authenticate({String reason = 'Sign in to MyPDF'}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e, st) {
      AppLogger.warn(
        _logTag,
        'authenticate failed: ${e.code}',
        error: e,
        st: st,
      );
      return false;
    } catch (e, st) {
      AppLogger.warn(
        _logTag,
        'authenticate unexpected error',
        error: e,
        st: st,
      );
      return false;
    }
  }
}
