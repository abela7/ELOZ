import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'temptation_log.g.dart';

/// Intensity levels for temptation urges
enum TemptationIntensity {
  mild,     // 0: Easy to resist
  moderate, // 1: Took some effort
  strong,   // 2: Very hard to resist
  extreme,  // 3: Almost gave in
}

/// TemptationLog model for tracking temptation events on quit habits
/// Each log captures when, why, and how intense the temptation was
@HiveType(typeId: 17)
class TemptationLog extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String habitId; // The quit habit this temptation belongs to

  @HiveField(2)
  DateTime occurredAt; // When the temptation happened

  @HiveField(3)
  int count; // How many times felt tempted (can log multiple at once)

  @HiveField(4)
  String? reasonId; // Reference to HabitReason (temptation type)

  @HiveField(5)
  String? reasonText; // The actual reason text (stored for history)

  @HiveField(6)
  String? customNote; // Additional notes about the temptation

  @HiveField(7)
  int intensityIndex; // 0=mild, 1=moderate, 2=strong, 3=extreme

  @HiveField(8)
  bool didResist; // true = resisted, false = slipped

  @HiveField(9)
  String? location; // Where it happened (optional)

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  int? iconCodePoint; // Icon from the reason

  @HiveField(12)
  int? colorValue; // Color from the reason

  TemptationLog({
    String? id,
    required this.habitId,
    required this.occurredAt,
    this.count = 1,
    this.reasonId,
    this.reasonText,
    this.customNote,
    this.intensityIndex = 1,
    this.didResist = true,
    this.location,
    DateTime? createdAt,
    this.iconCodePoint,
    this.colorValue,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Get the intensity level
  TemptationIntensity get intensity {
    switch (intensityIndex) {
      case 0:
        return TemptationIntensity.mild;
      case 1:
        return TemptationIntensity.moderate;
      case 2:
        return TemptationIntensity.strong;
      case 3:
        return TemptationIntensity.extreme;
      default:
        return TemptationIntensity.moderate;
    }
  }

  /// Get intensity display name
  String get intensityName {
    switch (intensity) {
      case TemptationIntensity.mild:
        return 'Mild';
      case TemptationIntensity.moderate:
        return 'Moderate';
      case TemptationIntensity.strong:
        return 'Strong';
      case TemptationIntensity.extreme:
        return 'Extreme';
    }
  }

  /// Get intensity color
  Color get intensityColor {
    switch (intensity) {
      case TemptationIntensity.mild:
        return const Color(0xFF4CAF50); // Green
      case TemptationIntensity.moderate:
        return const Color(0xFFFFB347); // Orange
      case TemptationIntensity.strong:
        return const Color(0xFFFF6B6B); // Red
      case TemptationIntensity.extreme:
        return const Color(0xFFE53935); // Dark Red
    }
  }

  /// Get intensity icon
  IconData get intensityIcon {
    switch (intensity) {
      case TemptationIntensity.mild:
        return Icons.sentiment_satisfied_rounded;
      case TemptationIntensity.moderate:
        return Icons.sentiment_neutral_rounded;
      case TemptationIntensity.strong:
        return Icons.sentiment_dissatisfied_rounded;
      case TemptationIntensity.extreme:
        return Icons.sentiment_very_dissatisfied_rounded;
    }
  }

  /// Get the stored icon
  IconData? get icon {
    if (iconCodePoint == null) return null;
    return IconData(iconCodePoint!, fontFamily: 'MaterialIcons');
  }

  /// Get the stored color
  Color get color {
    if (colorValue == null) return const Color(0xFF9C27B0);
    return Color(colorValue!);
  }

  /// Get formatted time
  String get formattedTime {
    final hour = occurredAt.hour;
    final minute = occurredAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Get formatted date
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDate = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
    
    if (logDate == today) {
      return 'Today';
    } else if (logDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[occurredAt.month - 1]} ${occurredAt.day}';
    }
  }

  /// Copy with updated fields
  TemptationLog copyWith({
    String? id,
    String? habitId,
    DateTime? occurredAt,
    int? count,
    String? reasonId,
    String? reasonText,
    String? customNote,
    int? intensityIndex,
    bool? didResist,
    String? location,
    DateTime? createdAt,
    int? iconCodePoint,
    int? colorValue,
  }) {
    return TemptationLog(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      occurredAt: occurredAt ?? this.occurredAt,
      count: count ?? this.count,
      reasonId: reasonId ?? this.reasonId,
      reasonText: reasonText ?? this.reasonText,
      customNote: customNote ?? this.customNote,
      intensityIndex: intensityIndex ?? this.intensityIndex,
      didResist: didResist ?? this.didResist,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
