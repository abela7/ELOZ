import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'transaction_category.g.dart';

/// Transaction Category model with Hive persistence
/// Represents a category for organizing transactions (e.g., Food, Transport, Salary)
@HiveType(typeId: 21)
class TransactionCategory extends HiveObject {
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

  @HiveField(6, defaultValue: 0xFFCDAF56)
  int colorValue;

  @HiveField(7, defaultValue: 'expense')
  String type; // 'income', 'expense', 'both'

  @HiveField(8, defaultValue: false)
  bool isSystemCategory; // System categories cannot be deleted

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10, defaultValue: 0)
  int sortOrder; // For custom ordering

  @HiveField(11)
  String? parentCategoryId; // For subcategories

  @HiveField(12)
  double? monthlyBudget; // Optional budget limit for this category

  @HiveField(13, defaultValue: true)
  bool isActive; // Whether the category is active (visible in lists)

  TransactionCategory({
    String? id,
    required this.name,
    this.description,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    int? colorValue,
    this.type = 'expense',
    this.isSystemCategory = false,
    DateTime? createdAt,
    this.sortOrder = 0,
    this.parentCategoryId,
    this.monthlyBudget,
    this.isActive = true,
    IconData? icon,
  }) : id = id ?? const Uuid().v4(),
       colorValue = colorValue ?? Colors.blue.value,
       createdAt = createdAt ?? DateTime.now() {
    // Set icon fields from IconData if provided
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

  /// Check if category is for income
  bool get isIncomeCategory => type == 'income' || type == 'both';

  /// Check if category is for expense
  bool get isExpenseCategory => type == 'expense' || type == 'both';

  /// Check if category has a budget set
  bool get hasBudget => monthlyBudget != null && monthlyBudget! > 0;

  /// Check if category is a subcategory
  bool get isSubcategory => parentCategoryId != null;

  /// Create a copy with updated fields
  TransactionCategory copyWith({
    String? id,
    String? name,
    String? description,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    String? type,
    bool? isSystemCategory,
    DateTime? createdAt,
    int? sortOrder,
    String? parentCategoryId,
    double? monthlyBudget,
  }) {
    return TransactionCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      isSystemCategory: isSystemCategory ?? this.isSystemCategory,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      parentCategoryId: parentCategoryId ?? this.parentCategoryId,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
    );
  }
}
