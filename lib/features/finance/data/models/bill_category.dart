import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'bill_category.g.dart';

/// Bill Category model with Hive persistence
/// Categories for bills and subscriptions (e.g., Utilities, Entertainment, Insurance)
@HiveType(typeId: 28)
class BillCategory extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int? iconCodePoint;

  @HiveField(3)
  String? iconFontFamily;

  @HiveField(4)
  String? iconFontPackage;

  @HiveField(5, defaultValue: 0xFFCDAF56)
  int colorValue;

  @HiveField(6, defaultValue: true)
  bool isActive;

  @HiveField(7, defaultValue: 0)
  int sortOrder;

  @HiveField(8)
  DateTime createdAt;

  BillCategory({
    String? id,
    required this.name,
    IconData? icon,
    Color? color,
    this.isActive = true,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       colorValue = color?.value ?? const Color(0xFFCDAF56).value,
       createdAt = createdAt ?? DateTime.now() {
    if (icon != null) {
      iconCodePoint = icon.codePoint;
      iconFontFamily = icon.fontFamily;
      iconFontPackage = icon.fontPackage;
    }
  }

  IconData? get icon {
    if (iconCodePoint == null) return null;
    return IconData(
      iconCodePoint!,
      fontFamily: iconFontFamily ?? 'MaterialIcons',
      fontPackage: iconFontPackage,
    );
  }

  set icon(IconData? value) {
    iconCodePoint = value?.codePoint;
    iconFontFamily = value?.fontFamily;
    iconFontPackage = value?.fontPackage;
  }

  Color get color => Color(colorValue);
  set color(Color value) => colorValue = value.value;
}
