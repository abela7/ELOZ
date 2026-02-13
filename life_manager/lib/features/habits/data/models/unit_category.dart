import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'unit_category.g.dart';

/// Model for unit categories (both default and custom)
/// Allows users to create custom categories for organizing units
@HiveType(typeId: 16)
class UnitCategory extends HiveObject {
  @HiveField(0)
  String id;

  /// Category name (e.g., "Time", "Volume", "Custom Exercise")
  @HiveField(1)
  String name;

  /// Icon code point for display
  @HiveField(2)
  int iconCodePoint;

  @HiveField(3)
  String? iconFontFamily;

  @HiveField(4)
  String? iconFontPackage;

  /// Color value (ARGB format)
  @HiveField(5)
  int colorValue;

  /// Whether this is a default/system category
  @HiveField(6)
  bool isDefault;

  /// Display order (lower = first)
  @HiveField(7)
  int sortOrder;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime? updatedAt;

  UnitCategory({
    String? id,
    required this.name,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    this.iconFontPackage,
    required this.colorValue,
    this.isDefault = false,
    this.sortOrder = 999,
    DateTime? createdAt,
    this.updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Get IconData from stored values
  IconData get icon => IconData(
        iconCodePoint,
        fontFamily: iconFontFamily,
        fontPackage: iconFontPackage,
      );

  /// Get Color from stored value
  Color get color => Color(colorValue);

  UnitCategory copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    bool? isDefault,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UnitCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============ Default Categories Factory Methods ============

  static UnitCategory timeCategory() {
    return UnitCategory(
      name: 'Time',
      iconCodePoint: Icons.access_time.codePoint,
      colorValue: const Color(0xFF9C27B0).value, // Purple
      isDefault: true,
      sortOrder: 1,
    );
  }

  static UnitCategory volumeCategory() {
    return UnitCategory(
      name: 'Volume',
      iconCodePoint: Icons.local_drink.codePoint,
      colorValue: const Color(0xFF2196F3).value, // Blue
      isDefault: true,
      sortOrder: 2,
    );
  }

  static UnitCategory weightCategory() {
    return UnitCategory(
      name: 'Weight',
      iconCodePoint: Icons.fitness_center.codePoint,
      colorValue: const Color(0xFFFF5722).value, // Deep Orange
      isDefault: true,
      sortOrder: 3,
    );
  }

  static UnitCategory distanceCategory() {
    return UnitCategory(
      name: 'Distance',
      iconCodePoint: Icons.straighten.codePoint,
      colorValue: const Color(0xFF4CAF50).value, // Green
      isDefault: true,
      sortOrder: 4,
    );
  }

  static UnitCategory countCategory() {
    return UnitCategory(
      name: 'Count',
      iconCodePoint: Icons.tag.codePoint,
      colorValue: const Color(0xFFFF9800).value, // Orange
      isDefault: true,
      sortOrder: 5,
    );
  }

  static UnitCategory customCategory() {
    return UnitCategory(
      name: 'Custom',
      iconCodePoint: Icons.tune.codePoint,
      colorValue: const Color(0xFFCDAF56).value, // Gold
      isDefault: true,
      sortOrder: 999,
    );
  }

  /// Get all default categories
  static List<UnitCategory> getAllDefaultCategories() {
    return [
      timeCategory(),
      volumeCategory(),
      weightCategory(),
      distanceCategory(),
      countCategory(),
      customCategory(),
    ];
  }
}
