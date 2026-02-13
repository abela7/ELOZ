import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'debt_category.g.dart';

/// Debt category model with Hive persistence
/// Represents a category for organizing debts (e.g., Credit Card, Loan, Mortgage)
@HiveType(typeId: 25)
class DebtCategory extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  int? iconCodePoint;

  @HiveField(4)
  String? iconFontFamily;

  @HiveField(5)
  String? iconFontPackage;

  @HiveField(6, defaultValue: 0xFFFF0000)
  int colorValue;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8, defaultValue: true)
  bool isActive;

  @HiveField(9, defaultValue: 0)
  int sortOrder;

  DebtCategory({
    String? id,
    required this.name,
    this.description,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    int? colorValue,
    DateTime? createdAt,
    this.isActive = true,
    this.sortOrder = 0,
    IconData? icon,
  }) : id = id ?? const Uuid().v4(),
       colorValue = colorValue ?? Colors.red.value,
       createdAt = createdAt ?? DateTime.now() {
    if (icon != null) {
      this.iconCodePoint = icon.codePoint;
      this.iconFontFamily = icon.fontFamily;
      this.iconFontPackage = icon.fontPackage;
    }
  }

  /// Get IconData from stored code point
  IconData? get icon {
    if (iconCodePoint == null) return null;
    return IconData(
      iconCodePoint!,
      fontFamily: iconFontFamily ?? 'MaterialIcons',
      fontPackage: iconFontPackage,
    );
  }

  /// Set IconData by storing code point
  set icon(IconData? value) {
    iconCodePoint = value?.codePoint;
    iconFontFamily = value?.fontFamily;
    iconFontPackage = value?.fontPackage;
  }

  /// Get Color from stored value
  Color get color => Color(colorValue);

  /// Set Color by storing value
  set color(Color value) {
    colorValue = value.value;
  }

  /// Create a copy with updated fields
  DebtCategory copyWith({
    String? id,
    String? name,
    String? description,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    DateTime? createdAt,
    bool? isActive,
    int? sortOrder,
  }) {
    return DebtCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
