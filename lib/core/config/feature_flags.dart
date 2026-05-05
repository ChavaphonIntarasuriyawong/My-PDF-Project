import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Default values applied to Remote Config before fetch lands. Mirrored in
/// `main.dart` via `setDefaults` so the very first read on a cold start
/// returns a sane value while the network fetch is in flight.
///
/// Changing a default here also requires updating `main.dart` to keep both
/// in sync (kept here for documentation only — the source of truth at boot
/// is `setDefaults`).
const Map<String, Object> kRemoteConfigDefaults = <String, Object>{
  'karaoke_tts_enabled': true,
  'ocr_fallback_enabled': true,
};

/// Synchronous read of the karaoke kill-switch.
///
/// Watches a re-fetch trigger so flipping the flag in Firebase console
/// doesn't require an app restart — `fetchAndActivate()` runs at boot and
/// any subsequent listener can bump [remoteConfigRefreshProvider] to force
/// a re-read.
final karaokeEnabledProvider = Provider<bool>((ref) {
  ref.watch(remoteConfigRefreshProvider);
  try {
    return FirebaseRemoteConfig.instance.getBool('karaoke_tts_enabled');
  } catch (e) {
    debugPrint('[remote_config] read failed: $e — defaulting to true');
    // Fail-open for the dogfooding window. Flip the default in
    // [kRemoteConfigDefaults] + console if we ever need fail-closed.
    return true;
  }
});

/// Synchronous read of the OCR fallback kill-switch.
///
/// When `true`, the reader's empty-text branch falls through to OCR via
/// `ocrPageTextProvider`. When `false`, original "scanned PDF?" snackbar
/// is shown. Watches the same refresh trigger so console flips take effect
/// without an app restart.
final ocrFallbackEnabledProvider = Provider<bool>((ref) {
  ref.watch(remoteConfigRefreshProvider);
  try {
    return FirebaseRemoteConfig.instance.getBool('ocr_fallback_enabled');
  } catch (e) {
    debugPrint('[remote_config] read failed: $e — defaulting to true');
    return true;
  }
});

/// Bump this to invalidate downstream feature-flag providers without a
/// restart. Read inside Provider bodies via `ref.watch` so a change triggers
/// rebuilds. Currently unused at the call site, but exposed for a future
/// "force refresh" button or onConfigUpdated listener wiring.
final remoteConfigRefreshProvider = StateProvider<int>((ref) => 0);
