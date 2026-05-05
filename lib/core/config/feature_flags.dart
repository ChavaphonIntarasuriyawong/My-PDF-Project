import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps [FirebaseRemoteConfig] so the rest of the app reads typed flags
/// without touching the SDK directly. Web-safe: Remote Config supports web,
/// so no `kIsWeb` guard is needed.
///
/// Failure mode: if [initialize] throws (e.g. offline cold start), the wrapper
/// silently falls through to defaults — never throws — so the app keeps booting.
class FeatureFlags {
  FeatureFlags({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  /// Default flag values. These are returned when Remote Config has not yet
  /// activated a fetched config (offline first launch, fetch failure, etc.).
  /// Keep keys here in sync with the Firebase Console parameter names.
  static const Map<String, dynamic> _defaults = <String, dynamic>{
    'ocr_fallback_enabled': true,
  };

  /// Fetch + activate the latest Remote Config values, then expose them via
  /// the typed getters on this class. Safe to call multiple times.
  ///
  /// Any error (no network, throttled fetch, plugin not registered) is logged
  /// and swallowed — callers must never need to wrap this in try/catch.
  Future<void> initialize() async {
    try {
      await _remoteConfig.setDefaults(_defaults);
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // 1h cache TTL — flags are not on a hot path, so ~hour-stale is fine.
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _remoteConfig.fetchAndActivate();
    } catch (e, st) {
      // Never let Remote Config wedge app startup. Log and fall through —
      // getters below will return the defaults registered above (or, if
      // setDefaults itself failed, the type-default — `false` for bool).
      debugPrint('[FeatureFlags] initialize failed: $e\n$st');
    }
  }

  /// Master switch for the OCR fallback pipeline (scanned-PDF text recovery).
  /// Defaults to `true` — flip to `false` in Firebase Console to kill the
  /// feature without redeploy.
  bool get ocrFallbackEnabled => _remoteConfig.getBool('ocr_fallback_enabled');
}

/// Riverpod handle for the singleton [FeatureFlags] instance created in
/// `main.dart`. The provider is overridden inside `ProviderScope` so every
/// `ref.read(featureFlagsProvider)` returns the same already-initialized
/// instance — never re-instantiate per read.
final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  throw UnimplementedError(
    'featureFlagsProvider must be overridden in ProviderScope with the '
    'instance built and initialized in main().',
  );
});
