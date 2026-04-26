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
                      Icon(widget.titleIcon,
                          size: 22, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(widget.title,
                            style: AppTypography.headlineMedium),
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
                    height: 48,
                    child: OutlinedButton(
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTypography.labelButton.copyWith(
                          color: AppColors.primary,
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
                                    if (mounted) setState(() => _loading = false);
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
                                    if (mounted) setState(() => _loading = false);
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
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                label,
                style: AppTypography.labelButton,
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
