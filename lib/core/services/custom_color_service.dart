import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing custom saved colors
class CustomColorService {
  static const String _keyPrefix = 'custom_color_';
  static const String _countKey = 'custom_colors_count';

  /// Save a custom color
  static Future<void> saveColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_countKey) ?? 0;
    
    // Check if color already exists
    final existingColors = await getSavedColors();
    if (existingColors.contains(color)) {
      return; // Don't save duplicates
    }
    
    // Save the color
    await prefs.setInt('$_keyPrefix$count', color.value);
    await prefs.setInt(_countKey, count + 1);
  }

  /// Get all saved custom colors
  static Future<List<Color>> getSavedColors() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_countKey) ?? 0;
    
    final colors = <Color>[];
    for (int i = 0; i < count; i++) {
      final colorValue = prefs.getInt('$_keyPrefix$i');
      if (colorValue != null) {
        colors.add(Color(colorValue));
      }
    }
    
    return colors;
  }

  /// Delete a custom color
  static Future<void> deleteColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_countKey) ?? 0;
    
    // Find and remove the color
    for (int i = 0; i < count; i++) {
      final colorValue = prefs.getInt('$_keyPrefix$i');
      if (colorValue == color.value) {
        // Remove this color and shift others
        for (int j = i; j < count - 1; j++) {
          final nextValue = prefs.getInt('$_keyPrefix${j + 1}');
          if (nextValue != null) {
            await prefs.setInt('$_keyPrefix$j', nextValue);
          } else {
            await prefs.remove('$_keyPrefix$j');
          }
        }
        await prefs.remove('$_keyPrefix${count - 1}');
        await prefs.setInt(_countKey, count - 1);
        break;
      }
    }
  }

  /// Clear all saved colors
  static Future<void> clearAllColors() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_countKey) ?? 0;
    
    for (int i = 0; i < count; i++) {
      await prefs.remove('$_keyPrefix$i');
    }
    await prefs.remove(_countKey);
  }
}
