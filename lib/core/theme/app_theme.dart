import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'color_schemes.dart';
import 'widgets_theme.dart';

/// Main theme configuration following official design rules
class AppTheme {
  /// Light Theme
  static ThemeData lightTheme() {
    final colorScheme = AppColorSchemes.lightColorScheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColorSchemes.background,
      
      // Typography - Inter font
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: AppColorSchemes.textPrimary,
        displayColor: AppColorSchemes.textPrimary,
      ),
      
      // Component Themes
      elevatedButtonTheme: AppWidgetsTheme.elevatedButtonTheme(colorScheme),
      cardTheme: AppWidgetsTheme.cardTheme(colorScheme),
      bottomNavigationBarTheme: AppWidgetsTheme.bottomNavigationBarTheme(colorScheme),
      appBarTheme: AppWidgetsTheme.appBarTheme(colorScheme),
      floatingActionButtonTheme: AppWidgetsTheme.floatingActionButtonTheme(colorScheme),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorSchemes.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColorSchemes.primaryGold, width: 2),
        ),
      ),
    );
  }

  /// Dark Theme - Premium purple and gold
  static ThemeData darkTheme() {
    final colorScheme = AppColorSchemes.darkColorScheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF212529), // Dark gray background
      
      // Typography - Inter font with light text
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: const Color(0xFFE5E5E5), // Light text for dark bg
        displayColor: const Color(0xFFFFFFFF), // White for headers
      ),
      
      // Component Themes
      elevatedButtonTheme: _darkElevatedButtonTheme(colorScheme),
      cardTheme: _darkCardTheme(colorScheme),
      bottomNavigationBarTheme: AppWidgetsTheme.bottomNavigationBarTheme(colorScheme),
      appBarTheme: _darkAppBarTheme(colorScheme),
      floatingActionButtonTheme: AppWidgetsTheme.floatingActionButtonTheme(colorScheme),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2D3139), // Dark gray for inputs
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColorSchemes.primaryGold, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        labelStyle: const TextStyle(color: Color(0xFFBDBDBD)),
      ),
    );
  }

  /// Dark theme elevated button
  static ElevatedButtonThemeData _darkElevatedButtonTheme(ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColorSchemes.primaryGold,
        foregroundColor: const Color(0xFF1E1E1E), // Dark text on gold
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }

  /// Dark theme card
  static CardThemeData _darkCardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color(0xFF2D3139), // Dark gray per design rules (NO PURPLE!)
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black.withOpacity(0.3),
    );
  }

  /// Dark theme app bar
  static AppBarTheme _darkAppBarTheme(ColorScheme colorScheme) {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: const Color(0xFFFFFFFF), // White text
      titleTextStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: Color(0xFFFFFFFF),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFFE5E5E5),
        size: 24,
      ),
      toolbarHeight: 56,
    );
  }
}
