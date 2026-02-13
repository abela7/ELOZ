import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'sleep_factor.g.dart';

enum SleepFactorType { good, bad }

/// Pre-Sleep Factor model with Hive persistence
/// Represents factors that can affect sleep quality (caffeine, alcohol, exercise, etc.)
/// 
/// Schema Version: 2
/// - v1: Initial schema with 8 fields (HiveField 0-7)
/// - v2: Added factor type with 9 fields (HiveField 8)
@HiveType(typeId: 52)
class SleepFactor extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  int iconCodePoint; // IconData.codePoint

  @HiveField(4)
  int colorValue; // Color.value

  @HiveField(5)
  bool isDefault; // Whether this is a default/system factor

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  int schemaVersion; // Schema version for migrations (current: 1)

  @HiveField(8)
  String factorTypeValue; // 'good' or 'bad'

  SleepFactor({
    String? id,
    required this.name,
    this.description,
    required this.iconCodePoint,
    required this.colorValue,
    this.isDefault = false,
    DateTime? createdAt,
    this.schemaVersion = 2,
    this.factorTypeValue = 'bad',
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Current schema version constant
  static const int currentSchemaVersion = 2;

  /// Get icon from codePoint
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  /// Get color from value
  Color get color => Color(colorValue);

  SleepFactorType get factorType {
    switch (factorTypeValue) {
      case 'good':
        return SleepFactorType.good;
      case 'bad':
      default:
        return SleepFactorType.bad;
    }
  }

  bool get isGood => factorType == SleepFactorType.good;
  bool get isBad => factorType == SleepFactorType.bad;

  /// Create a copy with updated fields
  SleepFactor copyWith({
    String? id,
    String? name,
    String? description,
    int? iconCodePoint,
    int? colorValue,
    bool? isDefault,
    DateTime? createdAt,
    int? schemaVersion,
    String? factorTypeValue,
  }) {
    return SleepFactor(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      factorTypeValue: factorTypeValue ?? this.factorTypeValue,
    );
  }

  /// Default pre-sleep factors
  static List<SleepFactor> getDefaultFactors() {
    return [
      SleepFactor(
        name: 'Caffeine',
        description: 'Had coffee, tea, or energy drinks',
        iconCodePoint: Icons.coffee_rounded.codePoint,
        colorValue: const Color(0xFF8D6E63).value, // Brown
        isDefault: true,
        factorTypeValue: 'bad',
      ),
      SleepFactor(
        name: 'Alcohol',
        description: 'Consumed alcoholic beverages',
        iconCodePoint: Icons.local_bar_rounded.codePoint,
        colorValue: const Color(0xFFE57373).value, // Red
        isDefault: true,
        factorTypeValue: 'bad',
      ),
      SleepFactor(
        name: 'Exercise',
        description: 'Exercise during the day',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
        colorValue: const Color(0xFF4CAF50).value, // Green
        isDefault: true,
        factorTypeValue: 'good',
      ),
      SleepFactor(
        name: 'Screen Time',
        description: 'Phone, TV, or computer before bed',
        iconCodePoint: Icons.phone_android_rounded.codePoint,
        colorValue: const Color(0xFF42A5F5).value, // Blue
        isDefault: true,
        factorTypeValue: 'bad',
      ),
      SleepFactor(
        name: 'Heavy Meal',
        description: 'Large or heavy meal before bed',
        iconCodePoint: Icons.restaurant_rounded.codePoint,
        colorValue: const Color(0xFFFF9800).value, // Orange
        isDefault: true,
        factorTypeValue: 'bad',
      ),
      SleepFactor(
        name: 'Stress',
        description: 'Feeling stressed or anxious',
        iconCodePoint: Icons.psychology_rounded.codePoint,
        colorValue: const Color(0xFFEF5350).value, // Red
        isDefault: true,
        factorTypeValue: 'bad',
      ),
      SleepFactor(
        name: 'Nap',
        description: 'Took a nap during the day',
        iconCodePoint: Icons.bedtime_rounded.codePoint,
        colorValue: const Color(0xFF9C27B0).value, // Purple
        isDefault: true,
        factorTypeValue: 'bad',
      ),
      SleepFactor(
        name: 'Medication',
        description: 'Took medication that may affect sleep',
        iconCodePoint: Icons.medication_rounded.codePoint,
        colorValue: const Color(0xFF26A69A).value, // Teal
        isDefault: true,
        factorTypeValue: 'good',
      ),
      SleepFactor(
        name: 'Meditation',
        description: 'Meditation or breathing before bed',
        iconCodePoint: Icons.self_improvement_rounded.codePoint,
        colorValue: const Color(0xFF26A69A).value, // Teal
        isDefault: true,
        factorTypeValue: 'good',
      ),
      SleepFactor(
        name: 'No Screen Time',
        description: 'Avoided screens 1 hour before bed',
        iconCodePoint: Icons.visibility_off_rounded.codePoint,
        colorValue: const Color(0xFF5C6BC0).value, // Indigo
        isDefault: true,
        factorTypeValue: 'good',
      ),
      SleepFactor(
        name: 'Consistent Bedtime',
        description: 'Went to bed at your regular time',
        iconCodePoint: Icons.access_time_filled_rounded.codePoint,
        colorValue: const Color(0xFF66BB6A).value, // Green
        isDefault: true,
        factorTypeValue: 'good',
      ),
    ];
  }
}
