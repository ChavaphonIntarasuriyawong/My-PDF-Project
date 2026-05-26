import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// ──────────────────────────────────────────────────────────────────────────
// PIN dots — filled / outlined indicator row.
// ──────────────────────────────────────────────────────────────────────────

class PinDots extends StatelessWidget {
  final int filled;
  final int total;

  const PinDots({super.key, required this.filled, required this.total});

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

class PinStatusLine extends StatelessWidget {
  final String? errorText;
  final int cooldownSecondsLeft;

  const PinStatusLine({
    super.key,
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
    // appears / disappears. Scale the reserved height with the OS text scale
    // so the space matches the actual rendered line height.
    final lineHeight =
        AppTypography.bodyMedium.fontSize! * AppTypography.bodyMedium.height!;
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(lineHeight),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Numpad — 3x4 grid: 1-2-3 / 4-5-6 / 7-8-9 / [empty]-0-backspace.
// ──────────────────────────────────────────────────────────────────────────

class PinNumpad extends StatelessWidget {
  final bool disabled;
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final String? highlightedDigit;
  final bool highlightBackspace;

  const PinNumpad({
    super.key,
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
              Expanded(child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 64))),
              const SizedBox(width: 12),
              Expanded(
                child: PinDigitKey(
                  label: '0',
                  onTap: () => onDigit('0'),
                  disabled: disabled,
                  isPressed: highlightedDigit == '0',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PinBackspaceKey(
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
            child: PinDigitKey(
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

class PinDigitKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool disabled;
  final bool isPressed;

  const PinDigitKey({
    super.key,
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
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

class PinBackspaceKey extends StatelessWidget {
  final VoidCallback onTap;
  final bool disabled;
  final bool isPressed;

  const PinBackspaceKey({
    super.key,
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
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
// Biometric quick-unlock button.
// ──────────────────────────────────────────────────────────────────────────

class PinBiometricButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const PinBiometricButton({
    super.key,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Unlock with Face ID or fingerprint',
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
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Keyboard key → digit map — shared between PinSetupScreen and PinEntryScreen.
// ──────────────────────────────────────────────────────────────────────────

final Map<LogicalKeyboardKey, String> pinKeyToDigit = {
  LogicalKeyboardKey.digit0: '0',
  LogicalKeyboardKey.numpad0: '0',
  LogicalKeyboardKey.digit1: '1',
  LogicalKeyboardKey.numpad1: '1',
  LogicalKeyboardKey.digit2: '2',
  LogicalKeyboardKey.numpad2: '2',
  LogicalKeyboardKey.digit3: '3',
  LogicalKeyboardKey.numpad3: '3',
  LogicalKeyboardKey.digit4: '4',
  LogicalKeyboardKey.numpad4: '4',
  LogicalKeyboardKey.digit5: '5',
  LogicalKeyboardKey.numpad5: '5',
  LogicalKeyboardKey.digit6: '6',
  LogicalKeyboardKey.numpad6: '6',
  LogicalKeyboardKey.digit7: '7',
  LogicalKeyboardKey.numpad7: '7',
  LogicalKeyboardKey.digit8: '8',
  LogicalKeyboardKey.numpad8: '8',
  LogicalKeyboardKey.digit9: '9',
  LogicalKeyboardKey.numpad9: '9',
};
