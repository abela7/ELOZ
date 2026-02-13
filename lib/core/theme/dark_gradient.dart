import 'package:flutter/material.dart';

/// Dark theme gradient configuration
/// Used across all screens for consistent dark mode appearance
/// Optimized: Uses const wherever possible
class DarkGradient {
  /// Three-color gradient for dark mode backgrounds (Dark Gray/Charcoal)
  static const List<Color> colors = [
    Color(0xFF2A2D3A), // Top - Dark blue-gray
    Color(0xFF212529), // Middle - Charcoal
    Color(0xFF1A1D23), // Bottom - Almost black
  ];

  /// Pre-computed decoration (const for performance)
  static const BoxDecoration _decoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ),
  );

  /// Creates the standard dark gradient decoration
  static BoxDecoration decoration() => _decoration;

  /// Wraps content with gradient background
  /// Optimized: Single container instead of nested containers
  static Widget wrap({required Widget child}) {
    return DecoratedBox(
      decoration: _decoration,
      child: child,
    );
  }
}

