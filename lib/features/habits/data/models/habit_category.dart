import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'habit_category.g.dart';

/// Habit-specific category model with Hive persistence
/// Separate from Tasks categories to keep mini apps isolated
@HiveType(typeId: 18)
class HabitCategory extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int iconCodePoint;

  @HiveField(3)
  String? iconFontFamily;

  @HiveField(4)
  String? iconFontPackage;

  @HiveField(5)
  int colorValue;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? updatedAt;

  HabitCategory({
    String? id,
    required this.name,
    required this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    required this.colorValue,
    DateTime? createdAt,
    this.updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory HabitCategory.fromIcon({
    String? id,
    required String name,
    required IconData icon,
    required Color color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitCategory(
      id: id,
      name: name,
      iconCodePoint: icon.codePoint,
      iconFontFamily: icon.fontFamily ?? 'MaterialIcons',
      iconFontPackage: icon.fontPackage,
      colorValue: color.value,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  IconData get icon {
    return IconData(
      iconCodePoint,
      fontFamily: iconFontFamily ?? 'MaterialIcons',
      fontPackage: iconFontPackage,
    );
  }

  Color get color => Color(colorValue);

  HabitCategory copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
    IconData? icon,
    Color? color,
  }) {
    return HabitCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? (icon?.codePoint ?? this.iconCodePoint),
      iconFontFamily: iconFontFamily ?? (icon?.fontFamily ?? this.iconFontFamily),
      iconFontPackage: iconFontPackage ?? (icon?.fontPackage ?? this.iconFontPackage),
      colorValue: colorValue ?? (color?.value ?? this.colorValue),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
