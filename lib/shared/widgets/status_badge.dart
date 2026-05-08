import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final bg = switch (status) {
      'reading' => AppColors.statusReadingBg,
      'finished' => AppColors.statusFinishedBg,
      'on_hold' => AppColors.statusOnHoldBg,
      _ => AppColors.surfaceMuted,
    };
    final label = switch (status) {
      'reading' => 'Reading',
      'finished' => 'Finished',
      'on_hold' => 'On Hold',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(label.toUpperCase(), style: AppTypography.badgeLabel),
    );
  }
}
