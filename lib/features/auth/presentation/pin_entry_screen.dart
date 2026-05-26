import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/local/app_pin_service.dart';
import '../../../core/local/app_pin_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/layout/responsive.dart';
import '../data/biometric_auth_service.dart';
import 'auth_controller.dart';
import 'widgets/pin_widgets.dart';

/// App-level PIN entry screen — shown on every cold start / resume when the
/// user is logged in but the session has not been unlocked yet.
///
/// Failure handling: 5 wrong PINs → input disabled for 30 s with an inline
/// countdown. Biometric quick-unlock shown if device supports it. A
/// "Forgot PIN? Sign out" escape hatch is always visible at the bottom.
class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({super.key});

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 6;
  static const int _failsBeforeCooldown = 5;
  static const Duration _cooldown = Duration(seconds: 30);

  final StringBuffer _pin = StringBuffer();
  int _failCount = 0;
  String? _errorText;
  int _cooldownSecondsLeft = 0;
  Timer? _cooldownTicker;

  // Keyboard highlight — ephemeral UI, setState is fine.
  String? _highlightedDigit;
  bool _highlightBackspace = false;

  // Shake animation on bad PIN.
  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  // Biometric availability — probed once on mount.
  bool _biometricChecked = false;
  bool _biometricSupported = false;
  bool _biometricInProgress = false;

  bool get _inputDisabled => _cooldownSecondsLeft > 0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _shake = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) => _probeBiometric());
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Keyboard flash helpers ────────────────────────────────────────────────

  void _flashDigit(String digit) {
    setState(() => _highlightedDigit = digit);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _highlightedDigit = null);
    });
  }

  void _flashBackspace() {
    setState(() => _highlightBackspace = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _highlightBackspace = false);
    });
  }

  // ── Biometric ─────────────────────────────────────────────────────────────

  Future<void> _probeBiometric() async {
    final supported = await BiometricAuthService().isDeviceSupported();
    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _biometricChecked = true;
    });
  }

  Future<void> _useBiometric() async {
    if (_biometricInProgress || _inputDisabled) return;
    setState(() => _biometricInProgress = true);
    final ok = await BiometricAuthService().authenticate(
      reason: 'Unlock MyPDF',
    );
    if (!mounted) return;
    setState(() => _biometricInProgress = false);
    if (ok) {
      ref.read(appPinSessionProvider.notifier).unlock();
      if (mounted) context.go(AppRoutes.home);
    }
  }

  // ── Input handling ────────────────────────────────────────────────────────

  void _onDigit(String digit) {
    if (_inputDisabled) return;
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin.write(digit);
      _errorText = null;
    });
    if (_pin.length == _pinLength) {
      _verify(_pin.toString());
    }
  }

  void _onBackspace() {
    if (_inputDisabled) return;
    if (_pin.isEmpty) return;
    final s = _pin.toString();
    setState(() {
      _pin.clear();
      _pin.write(s.substring(0, s.length - 1));
      _errorText = null;
    });
  }

  void _verify(String pin) {
    final ok = ref.read(appPinServiceProvider).verifyPin(pin);
    if (ok) {
      ref.read(appPinSessionProvider.notifier).unlock();
      if (mounted) context.go(AppRoutes.home);
      return;
    }
    _onFailedAttempt();
  }

  void _onFailedAttempt() {
    setState(() {
      _failCount += 1;
      _pin.clear();
      _errorText = 'Incorrect PIN.';
    });
    _shakeController.forward(from: 0);
    if (_failCount >= _failsBeforeCooldown) {
      _startCooldown();
    }
  }

  void _startCooldown() {
    _cooldownTicker?.cancel();
    setState(() {
      _cooldownSecondsLeft = _cooldown.inSeconds;
      _errorText = null;
    });
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownSecondsLeft -= 1);
      if (_cooldownSecondsLeft <= 0) {
        timer.cancel();
        setState(() {
          _failCount = 0;
          _cooldownSecondsLeft = 0;
        });
      }
    });
  }

  // ── Sign-out escape ───────────────────────────────────────────────────────

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showBiometric = _biometricChecked && _biometricSupported;

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          _onBackspace();
          _flashBackspace();
          return KeyEventResult.handled;
        }
        final digit = pinKeyToDigit[event.logicalKey];
        if (digit != null) {
          _onDigit(digit);
          _flashDigit(digit);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop(context) ? 720 : 9999,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    // Icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.iconBlueTint,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Welcome Back', style: AppTypography.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your PIN to continue.',
                      style: AppTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_shake.value, 0),
                        child: child,
                      ),
                      child: PinDots(filled: _pin.length, total: _pinLength),
                    ),
                    const SizedBox(height: 16),
                    PinStatusLine(
                      errorText: _errorText,
                      cooldownSecondsLeft: _cooldownSecondsLeft,
                    ),
                    const SizedBox(height: 24),
                    PinNumpad(
                      disabled: _inputDisabled,
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      highlightedDigit: _highlightedDigit,
                      highlightBackspace: _highlightBackspace,
                    ),
                    if (showBiometric) ...[
                      const SizedBox(height: 24),
                      PinBiometricButton(
                        loading: _biometricInProgress,
                        onTap: _useBiometric,
                      ),
                    ],
                    const SizedBox(height: 32),
                    Semantics(
                      button: true,
                      label: 'Forgot PIN, sign out',
                      child: TextButton(
                        onPressed: _signOut,
                        child: Text(
                          'Forgot PIN? Sign out',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
