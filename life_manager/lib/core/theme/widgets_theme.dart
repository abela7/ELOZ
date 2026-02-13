import 'package:flutter/material.dart';
import 'color_schemes.dart';

/// Widget-specific theme configurations
/// Following official design system rules
class AppWidgetsTheme {
  /// Elevated Button Theme - Gold for primary actions only
  static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColorSchemes.primaryGold,
        foregroundColor: AppColorSchemes.textPrimary,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
    );
  }

  /// Card Theme - Floating cards with elevation
  static CardThemeData cardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: AppColorSchemes.surface,
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black.withOpacity(0.2),
    );
  }

  /// Bottom Navigation Bar Theme - Dark background
  static BottomNavigationBarThemeData bottomNavigationBarTheme(
    ColorScheme colorScheme,
  ) {
    return BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF212529), // Dark gray/charcoal
      selectedItemColor: AppColorSchemes.primaryGold,
      unselectedItemColor: AppColorSchemes.inactiveIcon,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    );
  }

  /// App Bar Theme
  static AppBarTheme appBarTheme(ColorScheme colorScheme) {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColorSchemes.textPrimary,
      titleTextStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: AppColorSchemes.textPrimary,
      ),
      iconTheme: const IconThemeData(
        color: AppColorSchemes.textPrimary,
        size: 24,
      ),
      toolbarHeight: 56,
    );
  }

  /// Floating Action Button Theme
  static FloatingActionButtonThemeData floatingActionButtonTheme(
    ColorScheme colorScheme,
  ) {
    return FloatingActionButtonThemeData(
      backgroundColor: AppColorSchemes.primaryGold,
      foregroundColor: AppColorSchemes.textPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
