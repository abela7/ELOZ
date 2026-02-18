import 'package:flutter/material.dart';
import 'color_schemes.dart';

/// Typography definitions following official design rules
/// Using Inter font family for modern, clean text
class AppTypography {
  static const String _fontFamily = 'Inter';

  /// Headline Large - For main titles (28-32px / Bold)
  static TextStyle headlineLarge(BuildContext context) {
    return const TextStyle(
      fontFamily: _fontFamily,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: AppColorSchemes.textPrimary,
    );
  }

  /// Title Medium - For card titles (18px / Medium)
  static TextStyle titleMedium(BuildContext context) {
    return const TextStyle(
      fontFamily: _fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: AppColorSchemes.textPrimary,
    );
  }

  /// Body Medium - For regular text (15-16px / Regular)
  static TextStyle bodyMedium(BuildContext context) {
    return const TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: AppColorSchemes.textPrimary,
      height: 1.5,
    );
  }

  /// Label Small - For labels and captions (12px / Medium)
  static TextStyle labelSmall(BuildContext context) {
    return const TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: AppColorSchemes.textSecondary,
    );
  }

  /// Get complete TextTheme for Material 3
  static TextTheme textTheme(BuildContext context) {
    final baseTextTheme = Theme.of(
      context,
    ).textTheme.apply(fontFamily: _fontFamily);

    return baseTextTheme.copyWith(
      headlineLarge: headlineLarge(context),
      titleMedium: titleMedium(context),
      bodyMedium: bodyMedium(context),
      labelSmall: labelSmall(context),
    );
  }
}
