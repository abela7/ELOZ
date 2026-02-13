import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import '../../notifications/finance_notification_contract.dart';
import 'bill_reminder.dart';

part 'debt.g.dart';

/// Debt status enum
enum DebtStatus {
  active, // Currently owing
  paidOff, // Fully paid
  defaulted, // Defaulted on payment
  settled, // Settled for less than owed
}

/// Debt direction enum
enum DebtDirection {
  owed, // Money user owes to others
  lent, // Money others owe to user
}

class DebtPaymentEntry {
  final String id;
  final double amount;
  final DateTime paidAt;
  final double balanceAfter;

  const DebtPaymentEntry({
    required this.id,
    required this.amount,
    required this.paidAt,
    required this.balanceAfter,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'paidAt': paidAt.toIso8601String(),
    'balanceAfter': balanceAfter,
  };

  factory DebtPaymentEntry.fromJson(Map<String, dynamic> json) {
    final parsedAmount = (json['amount'] as num?)?.toDouble() ?? 0;
    final paidAtRaw = json['paidAt'] as String? ?? '';
    final parsedPaidAt = DateTime.tryParse(paidAtRaw) ?? DateTime.now();
    final parsedBalanceAfter = (json['balanceAfter'] as num?)?.toDouble() ?? 0;
    final encodedId = (json['id'] as String?)?.trim();
    final fallbackId =
        '${paidAtRaw}_'
        '${parsedAmount.toStringAsFixed(4)}_'
        '${parsedBalanceAfter.toStringAsFixed(4)}';

    return DebtPaymentEntry(
      id: (encodedId == null || encodedId.isEmpty) ? fallbackId : encodedId,
      amount: parsedAmount,
      paidAt: parsedPaidAt,
      balanceAfter: parsedBalanceAfter,
    );
  }

  static DebtPaymentEntry? tryParseEncoded(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return DebtPaymentEntry.fromJson(decoded);
      }
      if (decoded is Map) {
        return DebtPaymentEntry.fromJson(decoded.cast<String, dynamic>());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());

  DebtPaymentEntry copyWith({
    String? id,
    double? amount,
    DateTime? paidAt,
    double? balanceAfter,
  }) {
    return DebtPaymentEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      paidAt: paidAt ?? this.paidAt,
      balanceAfter: balanceAfter ?? this.balanceAfter,
    );
  }
}

/// Debt model with Hive persistence
/// Represents an individual debt record (loan, credit card balance, etc.)
@HiveType(typeId: 26)
class Debt extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // e.g., "Chase Credit Card", "Car Loan"

  @HiveField(2)
  String? description;

  @HiveField(3)
  String categoryId; // Reference to DebtCategory

  @HiveField(4, defaultValue: 0.0)
  double originalAmount; // The initial/principal amount borrowed

  @HiveField(5, defaultValue: 0.0)
  double currentBalance; // Current amount owed (decreases as you pay)

  @HiveField(6)
  double? interestRate; // Annual interest rate percentage (optional)

  @HiveField(7)
  String? creditorName; // Who you owe money to

  @HiveField(8)
  DateTime? dueDate; // Next payment due date or final due date

  @HiveField(9)
  double? minimumPayment; // Minimum monthly payment

  @HiveField(10, defaultValue: 'ETB')
  String currency;

  @HiveField(11, defaultValue: 'active')
  String status; // 'active', 'paidOff', 'defaulted', 'settled'

  @HiveField(12)
  DateTime createdAt;

  @HiveField(13)
  DateTime? updatedAt;

  @HiveField(14)
  DateTime? paidOffDate; // When debt was fully paid

  @HiveField(15)
  String? notes;

  @HiveField(16)
  String? accountId; // Optional: link to an account (for credit cards)

  @HiveField(17)
  int? iconCodePoint;

  @HiveField(18)
  String? iconFontFamily;

  @HiveField(19)
  String? iconFontPackage;

  @HiveField(20)
  int? colorValue;

  @HiveField(21, defaultValue: false)
  bool reminderEnabled; // Master toggle for all reminders

  @HiveField(22, defaultValue: 3)
  int reminderDaysBefore; // Legacy; migrated to remindersJson

  @HiveField(23)
  List<String> paymentLogJson;

  @HiveField(26)
  String? remindersJson; // JSON list of BillReminder (same as bills)

  @HiveField(24, defaultValue: 'owed')
  String direction; // 'owed' or 'lent'

  @HiveField(25)
  String? transactionId; // Link to the expense transaction when lending money

  Debt({
    String? id,
    required this.name,
    this.description,
    required this.categoryId,
    required this.originalAmount,
    double? currentBalance,
    this.interestRate,
    this.creditorName,
    this.dueDate,
    this.minimumPayment,
    this.currency = FinanceSettingsService.fallbackCurrency,
    this.status = 'active',
    DateTime? createdAt,
    this.updatedAt,
    this.paidOffDate,
    this.notes,
    this.accountId,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    int? colorValue,
    this.reminderEnabled = false,
    this.reminderDaysBefore = 3,
    List<String>? paymentLogJson,
    this.direction = 'owed',
    this.transactionId,
    this.remindersJson,
    IconData? icon,
  }) : id = id ?? const Uuid().v4(),
       currentBalance = currentBalance ?? originalAmount,
       colorValue = colorValue ?? Colors.red.value,
       paymentLogJson = paymentLogJson ?? <String>[],
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
  Color get color => Color(colorValue ?? Colors.red.value);

  /// Set Color by storing value
  set color(Color value) {
    colorValue = value.value;
  }

  /// Get debt status enum
  DebtStatus get debtStatus {
    switch (status) {
      case 'paidOff':
        return DebtStatus.paidOff;
      case 'defaulted':
        return DebtStatus.defaulted;
      case 'settled':
        return DebtStatus.settled;
      case 'active':
      default:
        return DebtStatus.active;
    }
  }

  /// Set debt status from enum
  set debtStatus(DebtStatus value) {
    status = value.name;
  }

  /// Check if debt is active
  bool get isActive => debtStatus == DebtStatus.active;

  /// Check if debt is paid off
  bool get isPaidOff => debtStatus == DebtStatus.paidOff || currentBalance <= 0;

  /// Get debt direction enum
  DebtDirection get debtDirection {
    switch (direction) {
      case 'lent':
        return DebtDirection.lent;
      case 'owed':
      default:
        return DebtDirection.owed;
    }
  }

  /// Set debt direction from enum
  set debtDirection(DebtDirection value) {
    direction = value.name;
  }

  /// Check if this record is money the user owes.
  bool get isOwed => debtDirection == DebtDirection.owed;

  /// Check if this record is money the user lent out.
  bool get isLent => debtDirection == DebtDirection.lent;

  /// Get amount paid so far
  double get amountPaid => originalAmount - currentBalance;

  /// Get payment progress percentage (0-100)
  double get paymentProgress {
    if (originalAmount <= 0) return 100;
    return ((amountPaid / originalAmount) * 100).clamp(0, 100);
  }

  /// Get formatted current balance with currency
  String get formattedBalance {
    final symbol = CurrencyUtils.getCurrencySymbol(currency);
    return '$symbol${currentBalance.toStringAsFixed(2)}';
  }

  /// Get formatted original amount with currency
  String get formattedOriginalAmount {
    final symbol = CurrencyUtils.getCurrencySymbol(currency);
    return '$symbol${originalAmount.toStringAsFixed(2)}';
  }

  /// Check if payment is overdue
  bool get isOverdue {
    if (dueDate == null || !isActive) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Get days until due date (negative if overdue)
  int? get daysUntilDue {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  /// Get reminders list with migration from legacy reminderDaysBefore
  List<BillReminder> get reminders {
    if (remindersJson != null && remindersJson!.isNotEmpty) {
      return BillReminder.decodeList(remindersJson);
    }
    if (reminderDaysBefore > 0) {
      return [
        BillReminder(
          id: const Uuid().v4(),
          timing: 'before',
          value: reminderDaysBefore,
          unit: 'days',
          hour: 9,
          minute: 0,
          typeId: FinanceNotificationContract.typePaymentDue,
          condition: FinanceNotificationContract.conditionAlways,
        ),
      ];
    }
    return [];
  }

  /// Set reminders list
  set reminders(List<BillReminder> value) {
    remindersJson = BillReminder.encodeList(value);
  }

  /// Parsed payment history, newest first.
  List<DebtPaymentEntry> get paymentHistory {
    final entries = _paymentEntriesAscending();
    entries.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return entries;
  }

  DateTime _asEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);
  }

  /// Whether this debt existed by the provided day (inclusive).
  bool existsAsOfDate(DateTime date) {
    final cutoff = _asEndOfDay(date);
    return !createdAt.isAfter(cutoff);
  }

  /// Historical debt balance at end-of-day.
  double balanceAsOfDate(DateTime date) {
    if (!existsAsOfDate(date)) return 0;

    final cutoff = _asEndOfDay(date);
    var balance = originalAmount.clamp(0.0, double.infinity).toDouble();

    for (final entry in _paymentEntriesAscending()) {
      if (entry.paidAt.isAfter(cutoff)) continue;
      final applied = entry.amount.clamp(0.0, balance).toDouble();
      balance = (balance - applied).clamp(0.0, double.infinity).toDouble();
      if (balance <= 0) break;
    }

    return balance;
  }

  List<DebtPaymentEntry> _paymentEntriesAscending() {
    final entries = paymentLogJson
        .map(DebtPaymentEntry.tryParseEncoded)
        .whereType<DebtPaymentEntry>()
        .toList();
    entries.sort((a, b) {
      final byDate = a.paidAt.compareTo(b.paidAt);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
    return entries;
  }

  void _applyPaymentEntries(List<DebtPaymentEntry> rawEntries) {
    final sorted = [...rawEntries]
      ..sort((a, b) {
        final byDate = a.paidAt.compareTo(b.paidAt);
        if (byDate != 0) return byDate;
        return a.id.compareTo(b.id);
      });

    var remaining = originalAmount.clamp(0.0, double.infinity).toDouble();
    final normalized = <DebtPaymentEntry>[];
    DateTime? payoffAt;

    for (final entry in sorted) {
      final applied = entry.amount.clamp(0.0, remaining).toDouble();
      remaining = (remaining - applied).clamp(0.0, double.infinity).toDouble();
      if (remaining <= 0 && payoffAt == null) {
        payoffAt = entry.paidAt;
      }
      normalized.add(entry.copyWith(amount: applied, balanceAfter: remaining));
    }

    paymentLogJson = normalized.map((entry) => entry.encode()).toList();
    currentBalance = remaining;
    updatedAt = DateTime.now();

    if (currentBalance <= 0) {
      status = 'paidOff';
      paidOffDate = payoffAt ?? DateTime.now();
    } else {
      status = 'active';
      paidOffDate = null;
    }
  }

  /// Record a payment on this debt
  void recordPayment(double amount) {
    if (amount <= 0) return;

    final entries = _paymentEntriesAscending();
    entries.add(
      DebtPaymentEntry(
        id: const Uuid().v4(),
        amount: amount,
        paidAt: DateTime.now(),
        balanceAfter: currentBalance,
      ),
    );
    _applyPaymentEntries(entries);
  }

  /// Remove a payment entry and recompute balances.
  bool undoPayment(String paymentId) {
    final entries = _paymentEntriesAscending();
    final index = entries.indexWhere((entry) => entry.id == paymentId);
    if (index == -1) return false;
    entries.removeAt(index);
    _applyPaymentEntries(entries);
    return true;
  }

  /// Update a payment amount and recompute balances.
  bool updatePayment(String paymentId, double amount) {
    if (amount <= 0) return false;

    final entries = _paymentEntriesAscending();
    final index = entries.indexWhere((entry) => entry.id == paymentId);
    if (index == -1) return false;

    entries[index] = entries[index].copyWith(amount: amount);
    _applyPaymentEntries(entries);
    return true;
  }

  /// Create a copy with updated fields
  Debt copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    double? originalAmount,
    double? currentBalance,
    double? interestRate,
    String? creditorName,
    DateTime? dueDate,
    double? minimumPayment,
    String? currency,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidOffDate,
    String? notes,
    String? accountId,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    bool? reminderEnabled,
    int? reminderDaysBefore,
    List<String>? paymentLogJson,
    String? direction,
    String? transactionId,
    String? remindersJson,
  }) {
    return Debt(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      originalAmount: originalAmount ?? this.originalAmount,
      currentBalance: currentBalance ?? this.currentBalance,
      interestRate: interestRate ?? this.interestRate,
      creditorName: creditorName ?? this.creditorName,
      dueDate: dueDate ?? this.dueDate,
      minimumPayment: minimumPayment ?? this.minimumPayment,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidOffDate: paidOffDate ?? this.paidOffDate,
      notes: notes ?? this.notes,
      accountId: accountId ?? this.accountId,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      colorValue: colorValue ?? this.colorValue,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      paymentLogJson: paymentLogJson ?? List<String>.from(this.paymentLogJson),
      direction: direction ?? this.direction,
      transactionId: transactionId ?? this.transactionId,
      remindersJson: remindersJson ?? this.remindersJson,
    );
  }
}
