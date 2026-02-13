/// Pre-computed color constants for performance
/// Avoids runtime withOpacity() calculations
import 'package:flutter/material.dart';

class AppColors {
  // Primary Gold colors
  static const Color gold = Color(0xFFCDAF56);
  static const Color goldOpacity02 = Color(0x33CDAF56); // 20% opacity
  static const Color goldOpacity03 = Color(0x4DCDAF56); // 30% opacity
  static const Color goldOpacity05 = Color(0x80CDAF56); // 50% opacity

  // Dark theme colors
  static const Color cardDark = Color(0xFF2D3139);
  static const Color cardDarkOpacity07 = Color(0xB32D3139); // 70% opacity
  static const Color cardDarkOpacity095 = Color(0xF22D3139); // 95% opacity
  static const Color surfaceDark = Color(0xFF3E4148);
  static const Color surfaceDarkOpacity05 = Color(0x803E4148); // 50% opacity

  // Light theme colors
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF0EAE4);
  static const Color backgroundLight = Color(0xFFEDE9E0);

  // Text colors
  static const Color textDark = Color(0xFF1E1E1E);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF6E6E6E);
  static const Color textSecondaryLight = Color(0xFFBDBDBD);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF2196F3);

  // Priority colors
  static const Color priorityHigh = Color(0xFFEF5350);
  static const Color priorityMedium = Color(0xFFFFA726);
  static const Color priorityLow = Color(0xFF4CAF50);

  // Priority colors with opacity (for backgrounds)
  static const Color priorityHighBg = Color(0x1AEF5350); // 10% opacity
  static const Color priorityMediumBg = Color(0x1AFFA726); // 10% opacity
  static const Color priorityLowBg = Color(0x1A4CAF50); // 10% opacity

  // Common opacity colors
  static const Color blackOpacity004 = Color(0x0A000000); // 4% black (shadows)
  static const Color blackOpacity005 = Color(0x0D000000); // 5% black
  static const Color blackOpacity006 = Color(0x0F000000); // 6% black (dividers)
  static const Color blackOpacity02 = Color(0x33000000); // 20% black
  static const Color blackOpacity03 = Color(0x4D000000); // 30% black
  static const Color whiteOpacity004 = Color(0x0AFFFFFF); // 4% white (cards)
  static const Color whiteOpacity006 = Color(0x0FFFFFFF); // 6% white
  static const Color whiteOpacity01 = Color(0x1AFFFFFF); // 10% white
  static const Color whiteOpacity03 = Color(0x4DFFFFFF); // 30% white

  // Gradient colors (Dark theme)
  static const Color gradientTop = Color(0xFF2A2D3A);
  static const Color gradientMiddle = Color(0xFF212529);
  static const Color gradientBottom = Color(0xFF1A1D23);
}
