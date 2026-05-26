import 'package:crypt/crypt.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_pin_service.g.dart';

/// Owns the app-level PIN hash in the `app_prefs` Hive box.
///
/// Key: `app_pin_hash` — a salted SHA-256 crypt string (modular crypt format).
/// The raw PIN is NEVER stored. SHA-256 crypt is the same KDF used by the
/// former per-book lock (`BookLockHasher`), now applied at the app level.
///
/// [hasPinSet] and [verifyPin] are synchronous because the Hive box is
/// already open by the time any screen can read them (opened in `main.dart`).
class AppPinService {
  static const String _boxName = 'app_prefs';
  static const String _pinHashKey = 'app_pin_hash';

  Box<dynamic> get _box => Hive.box<dynamic>(_boxName);

  /// Returns true when a PIN hash is stored in Hive.
  bool hasPinSet() {
    final value = _box.get(_pinHashKey);
    return value != null && (value as String).isNotEmpty;
  }

  /// Hash [pin] with a fresh random salt and write it to Hive.
  Future<void> setPin(String pin) async {
    final hash = Crypt.sha256(pin).toString();
    await _box.put(_pinHashKey, hash);
  }

  /// Constant-time verify [pin] against the stored hash.
  /// Returns false if no PIN is set or if the hash is malformed.
  bool verifyPin(String pin) {
    final stored = _box.get(_pinHashKey) as String?;
    if (stored == null || stored.isEmpty) return false;
    try {
      return Crypt(stored).match(pin);
    } on FormatException {
      return false;
    } on RangeError {
      return false;
    }
  }

  /// Remove the stored PIN hash. Used only when wiping app data; NOT called
  /// on logout (same user returning to the same device reuses their PIN).
  Future<void> clearPin() async {
    await _box.delete(_pinHashKey);
  }
}

@Riverpod(keepAlive: true)
AppPinService appPinService(AppPinServiceRef ref) => AppPinService();
