import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  // --- Manrope ---
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w800,
    fontSize: 36,
    height: 1.11,
    color: AppColors.primary,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w700,
    fontSize: 30,
    letterSpacing: -0.75,
    height: 1.2,
    color: AppColors.primary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w700,
    fontSize: 24,
    letterSpacing: -0.6,
    height: 1.33,
    color: AppColors.primary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w700,
    fontSize: 18,
    letterSpacing: -0.9,
    height: 1.56,
    color: AppColors.primary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelButton = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 1.5,
    color: Colors.white,
  );

  // --- Inter ---
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.43,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.33,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 11,
    letterSpacing: 0.55,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const TextStyle captionBold = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w700,
    fontSize: 10,
    height: 1.5,
    color: AppColors.primary,
  );

  static const TextStyle captionRegular = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 10,
    letterSpacing: 0.5,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const TextStyle badgeLabel = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 10,
    height: 1.5,
    color: AppColors.statusText,
  );

  static const TextStyle sectionMeta = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 12,
    letterSpacing: 1.2,
    height: 1.33,
    color: AppColors.textDisabled,
  );

  static const TextStyle greeting = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    letterSpacing: 0.8,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const TextStyle navLabel = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 11,
    letterSpacing: 0.55,
    height: 1.5,
    color: AppColors.textNav,
  );

  static const TextStyle errorText = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.5,
    color: AppColors.error,
  );

  // Added: Note card heading from Figma node 25:741 — Inter Bold 20 / textSecondary.
  static const TextStyle noteTitle = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w700,
    fontSize: 20,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  // Added: Note card body from Figma node 25:741 — Inter Reg 14 / textPrimary / lh 22.75 (≈1.625).
  static const TextStyle noteBody = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.625,
    color: AppColors.textPrimary,
  );
}
