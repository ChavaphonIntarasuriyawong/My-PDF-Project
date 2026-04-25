import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background    = Color(0xFFF8FAFB);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceMuted  = Color(0xFFF2F4F5);
  static const Color primary       = Color(0xFF004253);
  static const Color primaryLight  = Color(0xFF005B71);
  static const Color textPrimary   = Color(0xFF191C1D);
  static const Color textSecondary = Color(0xFF40484C);
  static const Color textMuted     = Color(0xFF70787D);
  static const Color textNav       = Color(0xFF40484B);
  static const Color textDisabled  = Color(0xFFBFC8CC);
  static const Color progressTrack = Color(0xFFE6E8E9);
  static const Color borderSubtle  = Color(0x4DBFC8CC);
  static const Color borderNav     = Color(0x26BFC8CC);

  // Status badges
  static const Color statusReadingBg  = Color(0xFFB7EAFF);
  static const Color statusFinishedBg = Color(0xFFAEFFB1);
  static const Color statusOnHoldBg   = Color(0xFFFFE3A8);
  static const Color statusText       = Color(0xFF004253);

  // Error / destructive
  static const Color error          = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // Icon tints
  static const Color iconBlueTint   = Color(0xFFCDE7F2);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment(-0.82, -1.0),
    end: Alignment(0.82, 1.0),
    colors: [Color(0xFF004253), Color(0xFF005B71)],
  );
}
