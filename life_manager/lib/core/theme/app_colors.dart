import 'package:flutter/material.dart';

/// Professional, Modern Color Palette for Life Manager
/// Inspired by premium productivity apps
class AppColors {
  // ===== LIGHT THEME COLORS =====
  
  // Backgrounds & Surfaces
  static const Color lightBackground = Color(0xFFFAFAFA);     // Soft off-white
  static const Color lightSurface = Color(0xFFFFFFFF);        // Pure white cards
  static const Color lightSurfaceVariant = Color(0xFFF5F5F5); // Subtle gray
  
  // Primary Brand - Golden/Amber (Professional & Warm)
  static const Color primaryGold = Color(0xFFFFC107);         // Vibrant, confident gold
  static const Color primaryGoldDark = Color(0xFFFFB300);     // Richer gold for hover/press
  static const Color primaryGoldLight = Color(0xFFFFECB3);    // Soft gold backgrounds
  
  // Accent - Teal/Cyan (Modern & Fresh)
  static const Color accentTeal = Color(0xFF00BCD4);          // Fresh, professional teal
  static const Color accentTealLight = Color(0xFFB2EBF2);     // Light teal backgrounds
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);         // Almost black
  static const Color textSecondary = Color(0xFF757575);       // Medium gray
  static const Color textTertiary = Color(0xFF9E9E9E);        // Light gray
  
  // Borders & Dividers
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);
  
  // ===== DARK THEME COLORS =====
  
  // Backgrounds & Surfaces (Rich, Deep Navy/Charcoal)
  static const Color darkBackground = Color(0xFF0A0E27);      // Deep navy blue
  static const Color darkSurface = Color(0xFF1A1F3A);         // Card surface
  static const Color darkSurfaceVariant = Color(0xFF252B48);  // Elevated surfaces
  
  // Text Colors (Dark Mode)
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextTertiary = Color(0xFF808080);
  
  // Borders (Dark Mode)
  static const Color darkBorder = Color(0xFF2A3152);
  static const Color darkDivider = Color(0xFF1F2438);
  
  // ===== FUNCTIONAL COLORS =====
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // ===== FEATURE COLORS =====
  static const Color taskColor = primaryGold;
  static const Color habitColor = success;
  static const Color todoColor = accentTeal;
  static const Color moodColor = Color(0xFFE91E63);
  static const Color financeColor = Color(0xFF4CAF50);
  
  // ===== LIGHT THEME COLOR SCHEME =====
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    
    primary: primaryGold,
    onPrimary: Color(0xFF000000),
    primaryContainer: primaryGoldLight,
    onPrimaryContainer: Color(0xFF3E2723),
    
    secondary: accentTeal,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: accentTealLight,
    onSecondaryContainer: Color(0xFF004D40),
    
    tertiary: Color(0xFF673AB7),
    onTertiary: Color(0xFFFFFFFF),
    
    error: error,
    onError: Color(0xFFFFFFFF),
    
    surface: lightSurface,
    onSurface: textPrimary,
    
    surfaceContainerHighest: lightSurfaceVariant,
    onSurfaceVariant: textSecondary,
    
    outline: border,
    outlineVariant: divider,
    
    shadow: Color(0x1F000000),
    inverseSurface: Color(0xFF2E2E2E),
    onInverseSurface: Color(0xFFFFFFFF),
  );
  
  // ===== DARK THEME COLOR SCHEME =====
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    
    primary: primaryGold,
    onPrimary: Color(0xFF000000),
    primaryContainer: Color(0xFF6D4C00),
    onPrimaryContainer: primaryGoldLight,
    
    secondary: accentTeal,
    onSecondary: Color(0xFF000000),
    secondaryContainer: Color(0xFF004D5B),
    onSecondaryContainer: accentTealLight,
    
    tertiary: Color(0xFFB39DDB),
    onTertiary: Color(0xFF000000),
    
    error: Color(0xFFEF5350),
    onError: Color(0xFF000000),
    
    surface: darkSurface,
    onSurface: darkTextPrimary,
    
    surfaceContainerHighest: darkSurfaceVariant,
    onSurfaceVariant: darkTextSecondary,
    
    outline: darkBorder,
    outlineVariant: darkDivider,
    
    shadow: Color(0x3F000000),
    inverseSurface: Color(0xFFE0E0E0),
    onInverseSurface: Color(0xFF1C1C1C),
  );
}
