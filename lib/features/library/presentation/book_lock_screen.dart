import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/data/biometric_auth_service.dart';
import 'library_controller.dart';
import 'library_providers.dart';

/// Per-book PIN lock gate (Wave 3 of the per-book lock feature).
///
/// Routed in front of `/book/:id/reading` and `/book/:id/note` whenever the
/// underlying book is `isLocked` and the in-memory `BookUnlockSession` does
/// not already have it cached. Once the user satisfies the gate (PIN or
/// biometric), the screen marks the book unlocked for this session and pushes
/// the original [redirectTo] route via `context.go`.
///
/// Visual: filled/empty dots above a 3x4 numpad. No system keyboard — the
/// numpad handles input directly so users can type one-handed and we sidestep
/// keyboard-sniffer accessibility services on Android.
///
/// Failure handling: 5 wrong PINs -> input disabled for 30 s with an inline
/// countdown. The cooldown is screen-local ephemeral state so plain
/// `setState` is fine here per `CLAUDE.md` (UI-local exception).
class BookLockScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String redirectTo;

  const BookLockScreen({
    super.key,
    required this.bookId,
    required this.redirectTo,
  });

  @override
  ConsumerState<BookLockScreen> createState() => _BookLockScreenState();
}

class _BookLockScreenState extends ConsumerState<BookLockScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 6;
  static const int _failsBeforeCooldown = 5;
  static const Duration _cooldown = Duration(seconds: 30);

  // PIN buffer / failure state — UI-local ephemeral, so setState is allowed.
  final StringBuffer _pin = StringBuffer();
  int _failCount = 0;
  String? _errorText;
  int _cooldownSecondsLeft = 0;
  Timer? _cooldownTicker;

  // Keyboard highlight — which key is briefly "pressed" by a keyboard event.
  String? _highlightedDigit;
  bool _highlightBackspace = false;

  // Shake animation on bad PIN.
  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  // Biometric availability — probed once on mount, then cached.
  bool _biometricChecked = false;
  bool _biometricSupported = false;
  bool _biometricEnabled = false;
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

  static final _keyToDigit = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.digit0: '0', LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.digit1: '1', LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.digit2: '2', LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.digit3: '3', LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.digit4: '4', LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.digit5: '5', LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.digit6: '6', LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.digit7: '7', LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.digit8: '8', LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.digit9: '9', LogicalKeyboardKey.numpad9: '9',
  };

  Future<void> _probeBiometric() async {
    final svc = BiometricAuthService();
    final supported = await svc.isDeviceSupported();
    final enabled = supported && await svc.isEnabledForUser();
    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _biometricEnabled = enabled;
      _biometricChecked = true;
    });
  }

  // ── Input handling ─────────────────────────────────────────────────────

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
    final next = _pin.toString();
    setState(() {
      _pin.clear();
      _pin.write(next.substring(0, next.length - 1));
      _errorText = null;
    });
  }

  void _verify(String pin) {
    final ok = ref
        .read(libraryControllerProvider.notifier)
        .verifyBookLock(widget.bookId, pin);
    if (ok) {
      ref.read(bookUnlockSessionProvider).markUnlocked(widget.bookId);
      if (mounted) context.go(widget.redirectTo);
      return;
    }
    _onFailedAttempt();
  }

  void _onFailedAttempt() {
    setState(() {
      _failCount += 1;
      _pin.clear();
      _errorText = 'Incorrect PIN. Try again.';
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
      setState(() {
        _cooldownSecondsLeft -= 1;
      });
      if (_cooldownSecondsLeft <= 0) {
        timer.cancel();
        setState(() {
          _failCount = 0;
          _cooldownSecondsLeft = 0;
        });
      }
    });
  }

  Future<void> _useBiometric() async {
    if (_biometricInProgress || _inputDisabled) return;
    setState(() => _biometricInProgress = true);
    final ok = await BiometricAuthService().authenticate(reason: 'Unlock book');
    if (!mounted) return;
    setState(() => _biometricInProgress = false);
    if (ok) {
      ref.read(bookUnlockSessionProvider).markUnlocked(widget.bookId);
      if (mounted) context.go(widget.redirectTo);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showBiometric =
        _biometricChecked && _biometricSupported && _biometricEnabled;

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          _onBackspace();
          _flashBackspace();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
          return KeyEventResult.handled;
        }
        final digit = _keyToDigit[event.logicalKey];
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
        child: Column(
          children: [
            _TopBar(
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    _LockHeader(),
                    const SizedBox(height: 32),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_shake.value, 0),
                        child: child,
                      ),
                      child: _PinDots(filled: _pin.length, total: _pinLength),
                    ),
                    const SizedBox(height: 16),
                    _StatusLine(
                      errorText: _errorText,
                      cooldownSecondsLeft: _cooldownSecondsLeft,
                    ),
                    const SizedBox(height: 24),
                    _Numpad(
                      disabled: _inputDisabled,
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      highlightedDigit: _highlightedDigit,
                      highlightBackspace: _highlightBackspace,
                    ),
                    if (showBiometric) ...[
                      const SizedBox(height: 24),
                      _BiometricButton(
                        loading: _biometricInProgress,
                        onTap: _useBiometric,
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Top bar — back chevron + title.
// ──────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: SizedBox(
              width: 48,
              height: 48,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onBack,
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Locked Book',
              style: AppTypography.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
        Text('Enter PIN', style: AppTypography.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit PIN to open this book.',
          style: AppTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// PIN dots — filled / outlined indicator row.
// ──────────────────────────────────────────────────────────────────────────

class _PinDots extends StatelessWidget {
  final int filled;
  final int total;

  const _PinDots({required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PIN entry: $filled of $total digits entered',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final isFilled = i < filled;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isFilled ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFilled ? AppColors.primary : AppColors.borderSubtle,
                  width: 1.5,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Status — error text on bad PIN, countdown during cooldown.
// ──────────────────────────────────────────────────────────────────────────

class _StatusLine extends StatelessWidget {
  final String? errorText;
  final int cooldownSecondsLeft;

  const _StatusLine({
    required this.errorText,
    required this.cooldownSecondsLeft,
  });

  @override
  Widget build(BuildContext context) {
    if (cooldownSecondsLeft > 0) {
      return Semantics(
        liveRegion: true,
        child: Text(
          'Too many attempts. Try again in $cooldownSecondsLeft s.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (errorText != null) {
      return Semantics(
        liveRegion: true,
        child: Text(
          errorText!,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
          textAlign: TextAlign.center,
        ),
      );
    }
    // Reserve vertical room so the layout doesn't jitter when the message
    // appears/disappears.
    return SizedBox(
      height:
          AppTypography.bodyMedium.fontSize! * AppTypography.bodyMedium.height!,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Numpad — 3x4 grid: 1-2-3 / 4-5-6 / 7-8-9 / [empty]-0-backspace.
// ──────────────────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final bool disabled;
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final String? highlightedDigit;
  final bool highlightBackspace;

  const _Numpad({
    required this.disabled,
    required this.onDigit,
    required this.onBackspace,
    this.highlightedDigit,
    this.highlightBackspace = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          _row(['1', '2', '3']),
          const SizedBox(height: 12),
          _row(['4', '5', '6']),
          const SizedBox(height: 12),
          _row(['7', '8', '9']),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: SizedBox(height: 64)),
              const SizedBox(width: 12),
              Expanded(
                child: _DigitKey(
                  label: '0',
                  onTap: () => onDigit('0'),
                  disabled: disabled,
                  isPressed: highlightedDigit == '0',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BackspaceKey(
                  onTap: onBackspace,
                  disabled: disabled,
                  isPressed: highlightBackspace,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> digits) {
    return Row(
      children: [
        for (var i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _DigitKey(
              label: digits[i],
              onTap: () => onDigit(digits[i]),
              disabled: disabled,
              isPressed: highlightedDigit == digits[i],
            ),
          ),
        ],
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool disabled;
  final bool isPressed;

  const _DigitKey({
    required this.label,
    required this.onTap,
    required this.disabled,
    this.isPressed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'PIN digit $label',
      enabled: !disabled,
      child: SizedBox(
        height: 64,
        child: Material(
          color: isPressed
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: disabled ? null : onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppTypography.headlineMedium.copyWith(
                  color: disabled ? AppColors.textDisabled : AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  final VoidCallback onTap;
  final bool disabled;
  final bool isPressed;

  const _BackspaceKey({
    required this.onTap,
    required this.disabled,
    this.isPressed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Delete last PIN digit',
      enabled: !disabled,
      child: SizedBox(
        height: 64,
        child: Material(
          color: isPressed
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: disabled ? null : onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.backspace_outlined,
                color: disabled ? AppColors.textDisabled : AppColors.primary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Biometric quick-unlock button — only mounted if device supports + opted in.
// PIN remains the canonical credential per the plan; this is a shortcut.
// ──────────────────────────────────────────────────────────────────────────

class _BiometricButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _BiometricButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Unlock with Face ID or fingerprint',
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: loading ? null : onTap,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.fingerprint,
                  color: AppColors.primary,
                  size: 22,
                ),
          label: Text(
            'Use Face ID / Fingerprint',
            style: AppTypography.labelLarge.copyWith(color: AppColors.primary),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
