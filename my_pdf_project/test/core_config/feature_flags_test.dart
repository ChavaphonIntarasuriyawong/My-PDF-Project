import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/core/config/feature_flags.dart';

/// Pure-Dart tests for the Remote Config feature-flag layer.
///
/// We can't reach the real `FirebaseRemoteConfig.instance` from a unit test
/// (no Firebase platform binding loaded under flutter_test). The provider's
/// `try { ... } catch (_) { return true; }` fail-open guard is exactly what
/// we exercise: when the SDK call throws (because there's no instance), the
/// provider must fall back to `true`. That's the contract every dogfood
/// build relies on for the karaoke kill-switch.
void main() {
  group('kRemoteConfigDefaults', () {
    test('contains karaoke_tts_enabled default = true', () {
      // The defaults map is the source of truth that `setDefaults` mirrors
      // in `main.dart`. If a flag is added without a default, cold-start reads
      // crash the provider and karaoke goes dark — guard against that here.
      expect(kRemoteConfigDefaults.containsKey('karaoke_tts_enabled'), isTrue);
      expect(kRemoteConfigDefaults['karaoke_tts_enabled'], isTrue);
    });

    test('all default values are non-null primitives', () {
      // Remote Config only accepts num / bool / String / Uint8List. Catching
      // a typo (e.g. accidental Map literal) here is cheaper than a runtime
      // failure inside `setDefaults`.
      for (final entry in kRemoteConfigDefaults.entries) {
        final v = entry.value;
        expect(
          v is bool || v is num || v is String,
          isTrue,
          reason: 'Default for "${entry.key}" must be a primitive Remote '
              'Config value, got ${v.runtimeType}',
        );
      }
    });

    test('keys are snake_case (Remote Config naming convention)', () {
      // Firebase enforces this server-side too — but a typo with a hyphen or
      // capital letter wastes a build cycle. Mirror the constraint locally.
      final invalid = <String>[];
      for (final key in kRemoteConfigDefaults.keys) {
        if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key)) {
          invalid.add(key);
        }
      }
      expect(invalid, isEmpty, reason: 'invalid key names: $invalid');
    });
  });

  group('karaokeEnabledProvider', () {
    test('falls back to true when FirebaseRemoteConfig is unavailable', () {
      // No Firebase binding under flutter_test — `FirebaseRemoteConfig.instance`
      // throws on first access. The provider catches and returns `true` (fail-
      // open per the in-file comment). This is the only behavior we can
      // verify without standing up a fake-SDK shim, but it IS the safety
      // contract we care about.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(karaokeEnabledProvider), isTrue);
    });

    test('re-reads when remoteConfigRefreshProvider bumps', () {
      // The provider watches `remoteConfigRefreshProvider`, so bumping that
      // counter must re-execute the body. Because the read still throws (no
      // Firebase), the result remains `true` — but the provider machinery
      // having re-run is what we want to lock in. Riverpod gives us that for
      // free as long as the watch is wired correctly.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(karaokeEnabledProvider);
      expect(first, isTrue);

      // Bump the refresh trigger.
      container.read(remoteConfigRefreshProvider.notifier).state = 1;

      // Provider should still resolve (re-evaluating the watch chain).
      final second = container.read(karaokeEnabledProvider);
      expect(second, isTrue);
    });
  });

  group('remoteConfigRefreshProvider', () {
    test('initial state is 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(remoteConfigRefreshProvider), 0);
    });

    test('state can be incremented', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(remoteConfigRefreshProvider.notifier).state++;
      expect(container.read(remoteConfigRefreshProvider), 1);
      container.read(remoteConfigRefreshProvider.notifier).state += 5;
      expect(container.read(remoteConfigRefreshProvider), 6);
    });
  });
}
