import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'color_schemes.dart';

/// Typography definitions following official design rules
/// Using Inter font family for modern, clean text
class AppTypography {
  /// Headline Large - For main titles (28-32px / Bold)
  static TextStyle headlineLarge(BuildContext context) {
    return GoogleFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: AppColorSchemes.textPrimary,
    );
  }

  /// Title Medium - For card titles (18px / Medium)
  static TextStyle titleMedium(BuildContext context) {
    return GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: AppColorSchemes.textPrimary,
    );
  }

  /// Body Medium - For regular text (15-16px / Regular)
  static TextStyle bodyMedium(BuildContext context) {
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: AppColorSchemes.textPrimary,
      height: 1.5,
    );
  }

  /// Label Small - For labels and captions (12px / Medium)
  static TextStyle labelSmall(BuildContext context) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: AppColorSchemes.textSecondary,
    );
  }

  /// Get complete TextTheme for Material 3
  static TextTheme textTheme(BuildContext context) {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return baseTextTheme.copyWith(
      headlineLarge: headlineLarge(context),
      titleMedium: titleMedium(context),
      bodyMedium: bodyMedium(context),
      labelSmall: labelSmall(context),
    );
  }
}
