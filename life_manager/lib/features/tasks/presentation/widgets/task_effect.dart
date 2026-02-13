import 'package:flutter/material.dart';

/// Task effect types for different animations
enum TaskEffect {
  success,  // Green confetti + check - task completed
  failed,   // Red confetti + sad emoji - not done
  warning,  // Yellow/gold subtle confetti - undo/postpone
}

/// Task effect colors based on theme
class TaskEffectColors {
  // Success colors (golden/various - celebratory!)
  static const List<Color> successColors = [
    Color(0xFFFFD700), // Gold
    Color(0xFFFFC107), // Amber/Golden Yellow
    Color(0xFFCDAF56), // Warm Gold
    Color(0xFFFFB300), // Darker Gold
    Color(0xFFFFD54F), // Light Gold
    Color(0xFFFF9800), // Orange
    Color(0xFF4CAF50), // Green accent
    Color(0xFFE91E63), // Pink accent
    Color(0xFF9C27B0), // Purple accent
    Colors.white,
  ];

  // Failed colors (red)
  static const List<Color> failedColors = [
    Color(0xFFFF6B6B), // Coral Red
    Color(0xFFEF5350), // Red
    Color(0xFFE57373), // Light Red
    Color(0xFFC62828), // Dark Red
    Colors.white,
  ];

  // Warning/Undo colors (gold/yellow)
  static const List<Color> warningColors = [
    Color(0xFFCDAF56), // Gold
    Color(0xFFFFC107), // Amber
    Color(0xFFFFD54F), // Light Gold
    Color(0xFFFFB300), // Darker Gold
    Colors.white,
  ];

  /// Get confetti colors based on effect type
  static List<Color> getColors(TaskEffect effect) {
    switch (effect) {
      case TaskEffect.success:
        return successColors;
      case TaskEffect.failed:
        return failedColors;
      case TaskEffect.warning:
        return warningColors;
    }
  }

  /// Get primary color for effect
  static Color getPrimaryColor(TaskEffect effect) {
    switch (effect) {
      case TaskEffect.success:
        return const Color(0xFF4CAF50);
      case TaskEffect.failed:
        return const Color(0xFFFF6B6B);
      case TaskEffect.warning:
        return const Color(0xFFCDAF56);
    }
  }

  /// Get icon for effect
  static IconData getIcon(TaskEffect effect) {
    switch (effect) {
      case TaskEffect.success:
        return Icons.check_rounded;
      case TaskEffect.failed:
        return Icons.sentiment_dissatisfied_rounded;
      case TaskEffect.warning:
        return Icons.undo_rounded;
    }
  }

  /// Get emoji for effect
  static String getEmoji(TaskEffect effect) {
    switch (effect) {
      case TaskEffect.success:
        return '🎉';
      case TaskEffect.failed:
        return '😔';
      case TaskEffect.warning:
        return '↩️';
    }
  }

  /// Get message for effect
  static String getMessage(TaskEffect effect) {
    switch (effect) {
      case TaskEffect.success:
        return 'Task Completed!';
      case TaskEffect.failed:
        return 'Task Not Done';
      case TaskEffect.warning:
        return 'Task Restored';
    }
  }
}

