import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../library_controller.dart';

/// Bottom sheet for setting / changing / removing a per-book PIN lock.
///
/// Shown from the book info screen. Two flows depending on [currentlyLocked]:
///
/// * `false` — direct setup. Two `obscureText` numeric fields (enter +
///   confirm). On submit -> `LibraryController.setBookLock`.
/// * `true` — verify gate first. After the user enters the current PIN, two
///   buttons surface: change (re-runs the setup form) or remove
///   (`LibraryController.removeBookLock`).
///
/// Errors are surfaced via the [onError] callback rather than a SnackBar
/// in-sheet, because `ScaffoldMessenger` lookups inside a bottom-sheet often
/// resolve to the sheet's own un-mounted scaffold and silently swallow the
/// message. Parent owns the messenger.
class LockSetupSheet extends ConsumerStatefulWidget {
  final String bookId;
  final bool currentlyLocked;

  /// Optional error reporter — called with a user-facing message when a
  /// controller call fails. Bottom sheets cannot reliably surface their own
  /// SnackBars, so the parent (book info screen) owns the messenger.
  final void Function(String message)? onError;

  const LockSetupSheet({
    super.key,
    required this.bookId,
    required this.currentlyLocked,
    this.onError,
  });

  @override
  ConsumerState<LockSetupSheet> createState() => _LockSetupSheetState();
}

enum _LockStep {
  /// First screen for an already-locked book — prompt for current PIN.
  verifyCurrent,

  /// Manage screen after verify success — pick "change" or "remove".
  manage,

  /// PIN setup form (enter + confirm). Used for both new locks and changes.
  enterAndConfirm,
}

class _LockSetupSheetState extends ConsumerState<LockSetupSheet> {
  static const int _pinLength = 6;

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _confirmFocus = FocusNode();

  late _LockStep _step;
  bool _busy = false;
  String? _formError;

  // Holds the verified current PIN across the verify -> manage -> change flow
  // so we don't make the user re-enter it for "Change PIN".
  String? _verifiedCurrentPin;

  @override
  void initState() {
    super.initState();
    _step = widget.currentlyLocked
        ? _LockStep.verifyCurrent
        : _LockStep.enterAndConfirm;
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _verifyCurrent() async {
    final pin = _currentCtrl.text;
    if (pin.length != _pinLength) {
      setState(() => _formError = 'PIN must be $_pinLength digits.');
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    final ok = ref
        .read(libraryControllerProvider.notifier)
        .verifyBookLock(widget.bookId, pin);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      setState(() {
        _verifiedCurrentPin = pin;
        _step = _LockStep.manage;
        _currentCtrl.clear();
      });
    } else {
      setState(() => _formError = 'Incorrect PIN.');
    }
  }

  Future<void> _saveNewPin() async {
    final pin = _newCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pin.length != _pinLength) {
      setState(() => _formError = 'PIN must be $_pinLength digits.');
      return;
    }
    if (pin != confirm) {
      setState(() => _formError = 'PINs do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    final ok = await ref
        .read(libraryControllerProvider.notifier)
        .setBookLock(widget.bookId, pin);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(libraryControllerProvider).error;
      final message = err?.toString() ?? 'Could not save PIN. Try again.';
      widget.onError?.call(message);
      setState(() => _formError = message);
    }
  }

  Future<void> _removeLock() async {
    final pin = _verifiedCurrentPin;
    if (pin == null) {
      // Defensive — should never reach manage step without it.
      setState(() => _step = _LockStep.verifyCurrent);
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    final ok = await ref
        .read(libraryControllerProvider.notifier)
        .removeBookLock(widget.bookId, pin);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(libraryControllerProvider).error;
      final message = err?.toString() ?? 'Could not remove lock. Try again.';
      widget.onError?.call(message);
      setState(() => _formError = message);
    }
  }

  void _switchToChangeFlow() {
    setState(() {
      _step = _LockStep.enterAndConfirm;
      _newCtrl.clear();
      _confirmCtrl.clear();
      _formError = null;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetGrabber(),
            const SizedBox(height: 12),
            _buildHeader(),
            const SizedBox(height: 24),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final (title, subtitle) = switch (_step) {
      _LockStep.verifyCurrent => (
        'Enter current PIN',
        'Verify your existing PIN to continue.',
      ),
      _LockStep.manage => (
        'Manage lock',
        'Change or remove the PIN for this book.',
      ),
      _LockStep.enterAndConfirm => (
        widget.currentlyLocked ? 'Set new PIN' : 'Lock this book',
        'Choose a 6-digit PIN. You will need it to open this book.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.headlineMedium),
        const SizedBox(height: 8),
        Text(subtitle, style: AppTypography.bodyMedium),
      ],
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _LockStep.verifyCurrent:
        return _VerifyCurrentForm(
          controller: _currentCtrl,
          errorText: _formError,
          busy: _busy,
          onSubmit: _verifyCurrent,
        );
      case _LockStep.manage:
        return _ManageActions(
          busy: _busy,
          onChange: _switchToChangeFlow,
          onRemove: _removeLock,
        );
      case _LockStep.enterAndConfirm:
        return _EnterAndConfirmForm(
          newCtrl: _newCtrl,
          confirmCtrl: _confirmCtrl,
          confirmFocus: _confirmFocus,
          errorText: _formError,
          busy: _busy,
          onSubmit: _saveNewPin,
        );
    }
  }
}

class _SheetGrabber extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.borderSubtle,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Sub-forms.
// ──────────────────────────────────────────────────────────────────────────

class _VerifyCurrentForm extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final bool busy;
  final Future<void> Function() onSubmit;

  const _VerifyCurrentForm({
    required this.controller,
    required this.errorText,
    required this.busy,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PinTextField(
          label: 'CURRENT PIN',
          controller: controller,
          errorText: errorText,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmit,
        ),
        const SizedBox(height: 24),
        GradientButton(
          label: 'Verify',
          loading: busy,
          onPressed: () => onSubmit(),
          borderRadius: 12,
        ),
      ],
    );
  }
}

class _EnterAndConfirmForm extends StatelessWidget {
  final TextEditingController newCtrl;
  final TextEditingController confirmCtrl;
  final FocusNode confirmFocus;
  final String? errorText;
  final bool busy;
  final Future<void> Function() onSubmit;

  const _EnterAndConfirmForm({
    required this.newCtrl,
    required this.confirmCtrl,
    required this.confirmFocus,
    required this.errorText,
    required this.busy,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PinTextField(
          label: 'ENTER 6-DIGIT PIN',
          controller: newCtrl,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onSubmitted: () async => confirmFocus.requestFocus(),
        ),
        const SizedBox(height: 16),
        _PinTextField(
          label: 'CONFIRM PIN',
          controller: confirmCtrl,
          focusNode: confirmFocus,
          errorText: errorText,
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmit,
        ),
        const SizedBox(height: 24),
        GradientButton(
          label: 'Save PIN',
          loading: busy,
          onPressed: () => onSubmit(),
          borderRadius: 12,
        ),
      ],
    );
  }
}

class _ManageActions extends StatelessWidget {
  final bool busy;
  final VoidCallback onChange;
  final Future<void> Function() onRemove;

  const _ManageActions({
    required this.busy,
    required this.onChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Change PIN',
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onChange,
              icon: const Icon(
                Icons.lock_reset,
                color: AppColors.primary,
                size: 20,
              ),
              label: Text(
                'Change PIN',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: 'Remove lock',
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: busy ? null : () => onRemove(),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.error,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.lock_open_outlined,
                      color: AppColors.error,
                      size: 20,
                    ),
              label: Text(
                'Remove lock',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.error,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.error, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// PIN-only text field — numeric keyboard, obscured, clamped to 6 digits.
// Built inline (rather than reusing LabeledTextField) so we can wire
// `inputFormatters`, which the shared widget does not expose.
// ──────────────────────────────────────────────────────────────────────────

class _PinTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? errorText;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Future<void> Function()? onSubmitted;

  const _PinTextField({
    required this.label,
    required this.controller,
    this.errorText,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            letterSpacing: 0.55,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          textField: true,
          label: label.toLowerCase(),
          child: TextField(
            controller: controller,
            obscureText: true,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            focusNode: focusNode,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: '••••••',
              errorText: errorText,
            ),
          ),
        ),
      ],
    );
  }
}
