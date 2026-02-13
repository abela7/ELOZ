import 'package:flutter/material.dart';

/// Official Life Manager Color Scheme
/// Following design_rules.md specifications

class AppColorSchemes {
  // Primary Brand Colors
  static const Color primaryGold = Color(0xFFCDAF56);
  static const Color primaryGoldVariant = Color(0xFFE1C877);
  
  // Dark Base (for bottom nav, dark elements) - Charcoal per design rules
  static const Color darkBase = Color(0xFF212529);
  static const Color darkBaseVariant = Color(0xFF2D3139);
  
  // Background & Surface
  static const Color background = Color(0xFFF9F7F2);
  static const Color surface = Color(0xFFFFFFFF);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1E1E1E);
  static const Color textSecondary = Color(0xFF6E6E6E);
  
  // Inactive icon color for bottom nav
  static const Color inactiveIcon = Color(0xFFC9C9C9);
  
  // Semantic colors
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  
  /// Light Theme Color Scheme (Material 3)
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    
    // Primary (Gold)
    primary: primaryGold,
    onPrimary: textPrimary,
    primaryContainer: primaryGoldVariant,
    onPrimaryContainer: textPrimary,
    
    // Secondary (Dark purple variant)
    secondary: darkBaseVariant,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE1C877),
    onSecondaryContainer: textPrimary,
    
    // Tertiary
    tertiary: primaryGoldVariant,
    onTertiary: textPrimary,
    tertiaryContainer: Color(0xFFE8DFC0),
    onTertiaryContainer: textPrimary,
    
    // Error
    error: error,
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFCDD2),
    onErrorContainer: Color(0xFF5F0000),
    
    // Background & Surface
    surface: surface,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    outline: Color(0xFFD0D0D0),
    outlineVariant: Color(0xFFE5E5E5),
    
    // System
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: darkBase,
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: primaryGoldVariant,
    
    // Surface containers
    surfaceTint: primaryGold,
    surfaceContainerHighest: background,
    surfaceContainerHigh: Color(0xFFFBF9F4),
    surfaceContainer: Color(0xFFFDFBF6),
    surfaceContainerLow: surface,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceBright: surface,
    surfaceDim: Color(0xFFF5F3EE),
  );

  /// Dark Theme Color Scheme (Material 3)
  /// Dark gray/charcoal theme with gold accents
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    
    // Primary (Gold) - main accent color
    primary: primaryGold,
    onPrimary: Color(0xFF1E1E1E),
    primaryContainer: Color(0xFF2D3139),
    onPrimaryContainer: primaryGoldVariant,
    
    // Secondary
    secondary: primaryGoldVariant,
    onSecondary: Color(0xFF1E1E1E),
    secondaryContainer: Color(0xFF2D3139),
    onSecondaryContainer: primaryGoldVariant,
    
    // Tertiary
    tertiary: Color(0xFFE1C877),
    onTertiary: Color(0xFF1E1E1E),
    tertiaryContainer: Color(0xFF2D3139),
    onTertiaryContainer: Color(0xFFE8DFC0),
    
    // Error
    error: Color(0xFFEF5350),
    onError: Color(0xFF000000),
    errorContainer: Color(0xFF5D1F1F),
    onErrorContainer: Color(0xFFFFCDD2),
    
    // Background & Surface - Dark gray base
    surface: Color(0xFF2D3139), // Dark gray for cards
    onSurface: Color(0xFFE5E5E5), // White text
    onSurfaceVariant: Color(0xFFBDBDBD), // Gray text
    outline: Color(0xFF3E4148),
    outlineVariant: Color(0xFF2A2D33),
    
    // System
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFF5F3EE),
    onInverseSurface: Color(0xFF212529),
    inversePrimary: primaryGold,
    
    // Surface containers - Various shades of dark gray
    surfaceTint: primaryGold,
    surfaceContainerHighest: Color(0xFF363A45), // Lighter gray for elevated cards
    surfaceContainerHigh: Color(0xFF2F3238),
    surfaceContainer: Color(0xFF282C32),
    surfaceContainerLow: Color(0xFF23262C),
    surfaceContainerLowest: Color(0xFF1A1D23),
    surfaceBright: Color(0xFF3E4148),
    surfaceDim: Color(0xFF212529), // Darkest gray
  );
}
