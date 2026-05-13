import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'gradient_button.dart';

class AppModal extends StatefulWidget {
  final String title;
  final IconData? titleIcon;
  final Widget body;
  final String confirmLabel;
  final bool confirmDestructive;
  final Future<void> Function() onConfirm;

  const AppModal({
    super.key,
    required this.title,
    this.titleIcon,
    required this.body,
    this.confirmLabel = 'Confirm',
    this.confirmDestructive = false,
    required this.onConfirm,
  });

  @override
  State<AppModal> createState() => _AppModalState();
}

class _AppModalState extends State<AppModal> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      // Cap modal width on wide viewports — Dialog would otherwise grow to
      // its parent constraints and look gigantic on desktop.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.titleIcon != null)
                  Row(
                    children: [
                      Icon(
                        widget.titleIcon,
                        size: 22,
                        color: widget.confirmDestructive
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: AppTypography.headlineMedium.copyWith(
                            color: widget.confirmDestructive
                                ? AppColors.error
                                : null,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(widget.title, style: AppTypography.headlineMedium),
                const SizedBox(height: 16),
                widget.body,
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: AppColors.surfaceMuted,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTypography.labelButton.copyWith(
                          color: AppColors.primary,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: widget.confirmDestructive
                      ? _DestructiveButton(
                          label: widget.confirmLabel,
                          loading: _loading,
                          onPressed: _loading
                              ? null
                              : () async {
                                  setState(() => _loading = true);
                                  try {
                                    await widget.onConfirm();
                                  } finally {
                                    if (mounted) {
                                      setState(() => _loading = false);
                                    }
                                  }
                                },
                        )
                      : GradientButton(
                          label: widget.confirmLabel,
                          loading: _loading,
                          onPressed: _loading
                              ? null
                              : () async {
                                  setState(() => _loading = true);
                                  try {
                                    await widget.onConfirm();
                                  } finally {
                                    if (mounted) {
                                      setState(() => _loading = false);
                                    }
                                  }
                                },
                          borderRadius: 12,
                        ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _DestructiveButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const _DestructiveButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: AppColors.error,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                // height: 1.0 keeps descenders ('g','p','y') from being clipped
                // by the button's bounded height. labelButton ships height: 1.5.
                style: AppTypography.labelButton.copyWith(
                  color: AppColors.error,
                  height: 1.0,
                ),
              ),
      ),
    );
  }
}

Future<T?> showAppModal<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: builder,
  );
}
