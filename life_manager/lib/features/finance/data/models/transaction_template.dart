import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'transaction_template.g.dart';

/// Transaction Template model with Hive persistence
/// Allows users to save frequently used transaction configurations
@HiveType(typeId: 27)
class TransactionTemplate extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // Name of the template (e.g., "Grocery Template")

  @HiveField(2)
  String transactionTitle; // Default title for the transaction

  @HiveField(3, defaultValue: 0.0)
  double amount;

  @HiveField(4, defaultValue: 'expense')
  String type; // 'income', 'expense', 'transfer'

  @HiveField(5)
  String? categoryId;

  @HiveField(6)
  String? accountId;

  @HiveField(7)
  String? toAccountId;

  @HiveField(8)
  String? description;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  int? iconCodePoint;

  @HiveField(11)
  String? iconFontFamily;

  @HiveField(12)
  String? iconFontPackage;

  @HiveField(13)
  bool isRecurring;

  @HiveField(14)
  String? recurrenceRule;

  TransactionTemplate({
    String? id,
    required this.name,
    required this.transactionTitle,
    required this.amount,
    this.type = 'expense',
    this.categoryId,
    this.accountId,
    this.toAccountId,
    this.description,
    DateTime? createdAt,
    IconData? icon,
    this.isRecurring = false,
    this.recurrenceRule,
  }) : id = id ?? const Uuid().v4(),
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
}
