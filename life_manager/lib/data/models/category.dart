import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'category.g.dart';

/// Category model with Hive persistence
/// Represents a task category with icon and color
@HiveType(typeId: 2)
class Category extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String iconCodePoint; // IconData codePoint as string

  @HiveField(3)
  String iconFontFamily; // IconData fontFamily

  @HiveField(4)
  String iconFontPackage; // IconData fontPackage (nullable, stored as empty string if null)

  @HiveField(5)
  int colorValue; // Color value as int

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? updatedAt;

  /// Constructor for Hive - accepts raw fields
  Category({
    String? id,
    required this.name,
    required this.iconCodePoint,
    required this.iconFontFamily,
    required this.iconFontPackage,
    required this.colorValue,
    DateTime? createdAt,
    this.updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Factory constructor - convenience constructor with IconData and Color
  factory Category.fromIcon({
    String? id,
    required String name,
    required IconData icon,
    required Color color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id,
      name: name,
      iconCodePoint: icon.codePoint.toString(),
      iconFontFamily: icon.fontFamily ?? '',
      iconFontPackage: icon.fontPackage ?? '',
      colorValue: color.value,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Get IconData from stored values
  IconData get icon {
    return IconData(
      int.parse(iconCodePoint),
      fontFamily: iconFontFamily.isEmpty ? null : iconFontFamily,
      fontPackage: iconFontPackage.isEmpty ? null : iconFontPackage,
    );
  }

  /// Get Color from stored value
  Color get color => Color(colorValue);

  /// Create a copy of this category with updated fields
  Category copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    String? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? (icon != null ? icon.codePoint.toString() : this.iconCodePoint),
      iconFontFamily: iconFontFamily ?? (icon != null ? (icon.fontFamily ?? '') : this.iconFontFamily),
      iconFontPackage: iconFontPackage ?? (icon != null ? (icon.fontPackage ?? '') : this.iconFontPackage),
      colorValue: colorValue ?? (color != null ? color.value : this.colorValue),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

