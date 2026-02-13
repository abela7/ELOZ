import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';

part 'transaction.g.dart';

/// Transaction type enum
enum TransactionType {
  income, // Money received
  expense, // Money spent
  transfer, // Transfer between accounts
}

/// Transaction model with Hive persistence
/// Represents a financial transaction (income, expense, or transfer)
@HiveType(typeId: 20)
class Transaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3, defaultValue: 0.0)
  double amount;

  @HiveField(4, defaultValue: 'expense')
  String type; // 'income', 'expense', 'transfer'

  @HiveField(5)
  String? categoryId; // Reference to transaction category

  @HiveField(6)
  String? accountId; // Source account for expense/income, source for transfer

  @HiveField(7)
  String? toAccountId; // Destination account (only for transfers)

  @HiveField(8)
  DateTime transactionDate;

  @HiveField(9)
  int? transactionTimeHour; // Hour component of transaction time

  @HiveField(10)
  int? transactionTimeMinute; // Minute component of transaction time

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime? updatedAt;

  @HiveField(13)
  String? notes;

  @HiveField(14)
  List<String>? tags; // Tags for categorization and filtering

  @HiveField(15)
  String? receiptPath; // Path to receipt image/document

  @HiveField(16)
  String? paymentMethod; // 'cash', 'card', 'bank_transfer', 'mobile_money', etc.

  @HiveField(17)
  String? currency; // Currency code (e.g., 'ETB', 'USD', 'EUR')

  @HiveField(18, defaultValue: false)
  bool isRecurring; // Whether this is a recurring transaction

  @HiveField(19)
  String? recurrenceRule; // JSON string for recurrence pattern (reusing from tasks/habits)

  @HiveField(20)
  String? recurringGroupId; // ID to group recurring transaction instances

  @HiveField(21)
  String? location; // Where transaction occurred

  @HiveField(22)
  String? contactPerson; // Person involved in transaction (paid to/received from)

  @HiveField(23, defaultValue: false)
  bool isSplit; // Whether transaction is split among multiple categories

  @HiveField(24)
  String? splitData; // JSON string with split details [{categoryId, amount, percentage}]

  @HiveField(25)
  int? iconCodePoint; // Icon code point for transaction icon

  @HiveField(26)
  String? iconFontFamily; // Icon font family

  @HiveField(27)
  String? iconFontPackage; // Icon font package

  @HiveField(28, defaultValue: false)
  bool needsReview; // Flag for transactions that need verification

  @HiveField(29, defaultValue: false)
  bool isCleared; // Whether transaction is cleared/reconciled

  @HiveField(30)
  DateTime? clearedDate; // When transaction was cleared

  @HiveField(31, defaultValue: false)
  bool isBalanceAdjustment; // Whether this is a balance correction

  @HiveField(32)
  String? billId; // Reference to bill/subscription that generated this transaction

  @HiveField(33)
  String? debtId; // Reference to debt/lending that generated this transaction

  Transaction({
    String? id,
    required this.title,
    this.description,
    required this.amount,
    this.type = 'expense',
    this.categoryId,
    this.accountId,
    this.toAccountId,
    required this.transactionDate,
    TimeOfDay? transactionTime,
    DateTime? createdAt,
    this.updatedAt,
    this.notes,
    this.tags,
    this.receiptPath,
    this.paymentMethod,
    this.currency = FinanceSettingsService.fallbackCurrency,
    this.isRecurring = false,
    this.recurrenceRule,
    this.recurringGroupId,
    this.location,
    this.contactPerson,
    this.isSplit = false,
    this.splitData,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.needsReview = false,
    this.isCleared = false,
    this.clearedDate,
    this.isBalanceAdjustment = false,
    this.billId,
    this.debtId,
    IconData? icon,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       transactionTimeHour = transactionTime?.hour,
       transactionTimeMinute = transactionTime?.minute {
    // Set icon fields from IconData if provided
    if (icon != null) {
      this.iconCodePoint = icon.codePoint;
      this.iconFontFamily = icon.fontFamily;
      this.iconFontPackage = icon.fontPackage;
    }
  }

  /// Get TimeOfDay from stored hour/minute
  TimeOfDay? get transactionTime {
    if (transactionTimeHour == null || transactionTimeMinute == null)
      return null;
    return TimeOfDay(
      hour: transactionTimeHour!,
      minute: transactionTimeMinute!,
    );
  }

  /// Set TimeOfDay by storing hour/minute
  set transactionTime(TimeOfDay? value) {
    transactionTimeHour = value?.hour;
    transactionTimeMinute = value?.minute;
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

  /// Get transaction type enum
  TransactionType get transactionType {
    switch (type) {
      case 'income':
        return TransactionType.income;
      case 'transfer':
        return TransactionType.transfer;
      case 'expense':
      default:
        return TransactionType.expense;
    }
  }

  /// Set transaction type from enum
  set transactionType(TransactionType value) {
    type = value.name;
  }

  /// Check if transaction is an expense
  bool get isExpense => transactionType == TransactionType.expense;

  /// Check if transaction is an income
  bool get isIncome => transactionType == TransactionType.income;

  /// Check if transaction is a transfer
  bool get isTransfer => transactionType == TransactionType.transfer;

  /// Get formatted amount with currency
  String get formattedAmount {
    final currencySymbol = CurrencyUtils.getCurrencySymbol(
      currency ?? FinanceSettingsService.fallbackCurrency,
    );
    return '$currencySymbol${amount.toStringAsFixed(2)}';
  }

  /// Get formatted amount for display (colored based on type)
  String get displayAmount {
    final prefix = isIncome ? '+' : (isExpense ? '-' : '');
    return '$prefix${formattedAmount}';
  }

  /// Get color based on transaction type
  Color get typeColor {
    switch (transactionType) {
      case TransactionType.income:
        return Colors.green;
      case TransactionType.expense:
        return Colors.red;
      case TransactionType.transfer:
        return Colors.blue;
    }
  }

  /// Get icon based on transaction type
  IconData get typeIcon {
    switch (transactionType) {
      case TransactionType.income:
        return Icons.arrow_downward_rounded;
      case TransactionType.expense:
        return Icons.arrow_upward_rounded;
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
    }
  }

  /// Create a copy with updated fields
  Transaction copyWith({
    String? id,
    String? title,
    String? description,
    double? amount,
    String? type,
    String? categoryId,
    String? accountId,
    String? toAccountId,
    DateTime? transactionDate,
    TimeOfDay? transactionTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    List<String>? tags,
    String? receiptPath,
    String? paymentMethod,
    String? currency,
    bool? isRecurring,
    String? recurrenceRule,
    String? recurringGroupId,
    String? location,
    String? contactPerson,
    bool? isSplit,
    String? splitData,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    bool? needsReview,
    bool? isCleared,
    DateTime? clearedDate,
    bool? isBalanceAdjustment,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionTime: transactionTime ?? this.transactionTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      receiptPath: receiptPath ?? this.receiptPath,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      currency: currency ?? this.currency,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurringGroupId: recurringGroupId ?? this.recurringGroupId,
      location: location ?? this.location,
      contactPerson: contactPerson ?? this.contactPerson,
      isSplit: isSplit ?? this.isSplit,
      splitData: splitData ?? this.splitData,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      needsReview: needsReview ?? this.needsReview,
      isCleared: isCleared ?? this.isCleared,
      clearedDate: clearedDate ?? this.clearedDate,
      isBalanceAdjustment: isBalanceAdjustment ?? this.isBalanceAdjustment,
    );
  }
}
