// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_pin_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appPinSessionHash() => r'004ace8dbef2682fdadda05a26ed816a0752bbf7';

/// In-memory session flag: true = the user has entered the correct app-level
/// PIN this session (or just set one for the first time). Resets to false on
/// logout. NOT persisted — killing the app re-locks on next open.
///
/// Copied from [AppPinSession].
@ProviderFor(AppPinSession)
final appPinSessionProvider = NotifierProvider<AppPinSession, bool>.internal(
  AppPinSession.new,
  name: r'appPinSessionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appPinSessionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppPinSession = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
