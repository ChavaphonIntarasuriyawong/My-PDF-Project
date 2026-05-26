// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'karaoke_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$karaokeControllerHash() => r'c0b35721bb803ef0c4906eec72fb85b32e3a0781';

/// Controller for the karaoke side-pane.
///
/// Wired from [ReadingScreen]'s TTS handlers:
/// - [onTtsStart] called immediately before each `_tts.speak(pageText)`.
/// - [onProgress] mirrors `setProgressHandler((text, start, end, word))`.
/// - [onSentenceTick] used only when [enableFallbackMode] has flipped the mode.
/// - [onTtsStop] called from completion / cancel / error handlers.
///
/// Copied from [KaraokeController].
@ProviderFor(KaraokeController)
final karaokeControllerProvider =
    AutoDisposeNotifierProvider<KaraokeController, KaraokeState>.internal(
      KaraokeController.new,
      name: r'karaokeControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$karaokeControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$KaraokeController = AutoDisposeNotifier<KaraokeState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
