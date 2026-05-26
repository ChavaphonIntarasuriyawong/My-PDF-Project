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
import 'widgets/pin_widgets.dart';

/// First-time PIN setup screen — mandatory after registration (and any time a
/// logged-in user has no PIN stored). The router redirects here automatically.
///
/// Two-step flow:
///   Step 1: enter a 6-digit PIN.
///   Step 2: confirm the PIN.
///
/// If the two entries match, the PIN is hashed and stored via [AppPinService],
/// the session is marked unlocked, and the user is sent to home. If they don't
/// match, a shake animation + error message is shown and both buffers clear.
///
/// There is intentionally no back button — PIN setup is mandatory.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 6;

  // Step 1 = entering first PIN, Step 2 = confirming it.
  int _step = 1;

  final StringBuffer _first = StringBuffer();
  final StringBuffer _confirm = StringBuffer();

  StringBuffer get _current => _step == 1 ? _first : _confirm;

  String? _errorText;

  // Keyboard highlight state — ephemeral UI, setState is fine.
  String? _highlightedDigit;
  bool _highlightBackspace = false;

  // Shake animation on mismatch.
  late final AnimationController _shakeController;
  late final Animation<double> _shake;

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
  }

  @override
  void dispose() {
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

  // ── Input handling ────────────────────────────────────────────────────────

  void _onDigit(String digit) {
    if (_current.length >= _pinLength) return;
    setState(() {
      _current.write(digit);
      _errorText = null;
    });
    if (_current.length == _pinLength) {
      _onPinComplete();
    }
  }

  void _onBackspace() {
    if (_current.isEmpty) return;
    final s = _current.toString();
    setState(() {
      _current.clear();
      _current.write(s.substring(0, s.length - 1));
      _errorText = null;
    });
  }

  void _onPinComplete() {
    if (_step == 1) {
      // Advance to confirm step.
      setState(() => _step = 2);
    } else {
      // Compare and save.
      if (_first.toString() == _confirm.toString()) {
        _savePin();
      } else {
        _shakeController.forward(from: 0);
        setState(() {
          _errorText = 'PINs don\'t match. Try again.';
          _first.clear();
          _confirm.clear();
          _step = 1;
        });
      }
    }
  }

  Future<void> _savePin() async {
    await ref.read(appPinServiceProvider).setPin(_first.toString());
    if (!mounted) return;
    ref.read(appPinSessionProvider.notifier).unlock();
    context.go(AppRoutes.home);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filled = _current.length;
    final stepLabel = _step == 1 ? 'Enter a 6-digit PIN' : 'Confirm your PIN';

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
                    Text(
                      'Create Your PIN',
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'ll enter this every time you open the app.',
                      style: AppTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Step indicator
                    Text(
                      stepLabel,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_shake.value, 0),
                        child: child,
                      ),
                      child: PinDots(filled: filled, total: _pinLength),
                    ),
                    const SizedBox(height: 16),
                    PinStatusLine(
                      errorText: _errorText,
                      cooldownSecondsLeft: 0,
                    ),
                    const SizedBox(height: 24),
                    PinNumpad(
                      disabled: false,
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      highlightedDigit: _highlightedDigit,
                      highlightBackspace: _highlightBackspace,
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
