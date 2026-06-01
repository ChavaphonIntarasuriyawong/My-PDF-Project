// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'font_scale_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$fontScaleNotifierHash() => r'8e23a72edb27214d9109b4b8da27f2b8bf97477b';

/// Exposes the current in-app font scale factor and persists changes via
/// [FontScaleService]. Initial value is read synchronously from Hive in
/// [build] — safe because the `app_prefs` box is opened in `main.dart`
/// before `runApp`.
///
/// Copied from [FontScaleNotifier].
@ProviderFor(FontScaleNotifier)
final fontScaleNotifierProvider =
    NotifierProvider<FontScaleNotifier, double>.internal(
      FontScaleNotifier.new,
      name: r'fontScaleNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$fontScaleNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FontScaleNotifier = Notifier<double>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
