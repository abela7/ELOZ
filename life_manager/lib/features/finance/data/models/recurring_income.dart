import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../notifications/finance_notification_contract.dart';
import 'bill_reminder.dart';

part 'recurring_income.g.dart';

/// Recurring income frequency
enum IncomeFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  quarterly,
  yearly,
}

/// Recurring Income model - for fixed income sources like salary, benefits, etc.
@HiveType(typeId: 35)
class RecurringIncome extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3, defaultValue: 0.0)
  double amount;

  @HiveField(4, defaultValue: 'ETB')
  String currency;

  @HiveField(5)
  String categoryId;

  @HiveField(6)
  String? accountId; // Target account for income

  @HiveField(7)
  DateTime startDate;

  @HiveField(8)
  DateTime? endDate; // null = indefinite

  @HiveField(9, defaultValue: 'monthly')
  String frequency; // 'daily', 'weekly', 'biweekly', 'monthly', 'quarterly', 'yearly'

  @HiveField(10, defaultValue: 1)
  int dayOfMonth; // For monthly: 1-31, -1 = last day

  @HiveField(11, defaultValue: 1)
  int dayOfWeek; // For weekly: 1=Monday, 7=Sunday

  @HiveField(12, defaultValue: true)
  bool isActive;

  @HiveField(13)
  DateTime createdAt;

  @HiveField(14)
  DateTime? updatedAt;

  @HiveField(15)
  String? notes;

  @HiveField(16)
  int? iconCodePoint;

  @HiveField(17)
  String? iconFontFamily;

  @HiveField(18)
  String? iconFontPackage;

  @HiveField(19)
  int? colorValue;

  @HiveField(20)
  bool autoCreateTransaction; // Auto-create transaction on due date

  @HiveField(21)
  bool notifyOnDue; // Legacy; use reminderEnabled

  @HiveField(22)
  int notifyDaysBefore; // Legacy; migrated to remindersJson

  @HiveField(23)
  DateTime? lastGeneratedDate;

  @HiveField(27)
  bool reminderEnabled; // Master toggle (same as bills/debts)

  @HiveField(28)
  String? remindersJson; // JSON list of BillReminder (same as bills/debts) // Last date a transaction was auto-generated

  @HiveField(24)
  String? payerName; // Who pays this income (employer, client, etc.)

  @HiveField(25)
  String? taxCategory; // For tax reporting (optional)

  @HiveField(26)
  bool isGuaranteed; // Whether this income is guaranteed (salary) vs variable (bonus)

  RecurringIncome({
    String? id,
    required this.title,
    this.description,
    required this.amount,
    required this.currency,
    required this.categoryId,
    this.accountId,
    required this.startDate,
    this.endDate,
    this.frequency = 'monthly',
    this.dayOfMonth = 1,
    this.dayOfWeek = 1,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
    this.notes,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.colorValue,
    this.autoCreateTransaction = false,
    this.notifyOnDue = true,
    this.notifyDaysBefore = 1,
    bool? reminderEnabled,
    this.remindersJson,
    this.lastGeneratedDate,
    this.payerName,
    this.taxCategory,
    this.isGuaranteed = true,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        reminderEnabled = reminderEnabled ?? true;

  /// Reminders list with migration from legacy notifyOnDue/notifyDaysBefore.
  List<BillReminder> get reminders {
    if (remindersJson != null && remindersJson!.isNotEmpty) {
      return BillReminder.decodeList(remindersJson);
    }
    if (notifyOnDue && notifyDaysBefore >= 0) {
      return [
        BillReminder(
          id: const Uuid().v4(),
          timing: 'before',
          value: notifyDaysBefore == 0 ? 0 : notifyDaysBefore,
          unit: 'days',
          hour: 9,
          minute: 0,
          typeId: FinanceNotificationContract.typeIncomeReminder,
          condition: FinanceNotificationContract.conditionAlways,
        ),
      ];
    }
    return [];
  }

  set reminders(List<BillReminder> value) {
    remindersJson = BillReminder.encodeList(value);
  }

  /// Returns the next occurrence date after [from].
  DateTime? nextOccurrenceAfter(DateTime from) {
    if (!isActive) return null;
    if (from.isBefore(startDate)) return startDate;
    if (endDate != null && from.isAfter(endDate!)) return null;

    DateTime candidate;
    switch (frequency) {
      case 'daily':
        candidate = from.add(const Duration(days: 1));
        break;
      case 'weekly':
        candidate = _nextWeeklyOccurrence(from);
        break;
      case 'biweekly':
        candidate = _nextBiweeklyOccurrence(from);
        break;
      case 'monthly':
        candidate = _nextMonthlyOccurrence(from);
        break;
      case 'quarterly':
        candidate = _nextQuarterlyOccurrence(from);
        break;
      case 'yearly':
        candidate = _nextYearlyOccurrence(from);
        break;
      default:
        return null;
    }

    if (endDate != null && candidate.isAfter(endDate!)) return null;
    return candidate;
  }

  DateTime _nextWeeklyOccurrence(DateTime from) {
    final daysUntilTarget = (dayOfWeek - from.weekday) % 7;
    final next = from.add(Duration(days: daysUntilTarget == 0 ? 7 : daysUntilTarget));
    return DateTime(next.year, next.month, next.day);
  }

  DateTime _nextBiweeklyOccurrence(DateTime from) {
    final weeksSinceStart = from.difference(startDate).inDays ~/ 7;
    final nextWeekNumber = ((weeksSinceStart ~/ 2) + 1) * 2;
    final nextDate = startDate.add(Duration(days: nextWeekNumber * 7));
    return DateTime(nextDate.year, nextDate.month, nextDate.day);
  }

  DateTime _nextMonthlyOccurrence(DateTime from) {
    var candidate = DateTime(from.year, from.month, dayOfMonth);
    if (candidate.isBefore(from) || candidate.isAtSameMomentAs(from)) {
      candidate = DateTime(from.year, from.month + 1, dayOfMonth);
    }
    // Handle last day of month
    if (dayOfMonth == -1 || dayOfMonth > 28) {
      final lastDay = DateTime(candidate.year, candidate.month + 1, 0).day;
      candidate = DateTime(candidate.year, candidate.month, lastDay);
    }
    return candidate;
  }

  DateTime _nextQuarterlyOccurrence(DateTime from) {
    var candidate = DateTime(from.year, from.month, dayOfMonth);
    if (candidate.isBefore(from) || candidate.isAtSameMomentAs(from)) {
      final nextQuarterMonth = ((from.month - 1) ~/ 3 + 1) * 3 + 1;
      candidate = DateTime(from.year, nextQuarterMonth, dayOfMonth);
      if (nextQuarterMonth > 12) {
        candidate = DateTime(from.year + 1, nextQuarterMonth - 12, dayOfMonth);
      }
    }
    return candidate;
  }

  DateTime _nextYearlyOccurrence(DateTime from) {
    var candidate = DateTime(from.year, startDate.month, startDate.day);
    if (candidate.isBefore(from) || candidate.isAtSameMomentAs(from)) {
      candidate = DateTime(from.year + 1, startDate.month, startDate.day);
    }
    return candidate;
  }

  /// Returns all occurrences between [start] and [end].
  List<DateTime> occurrencesBetween(DateTime start, DateTime end) {
    final occurrences = <DateTime>[];
    var current = startDate;
    
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      if ((current.isAfter(start) || current.isAtSameMomentAs(start)) &&
          (endDate == null || current.isBefore(endDate!) || current.isAtSameMomentAs(endDate!))) {
        occurrences.add(current);
      }
      final next = nextOccurrenceAfter(current);
      if (next == null || next == current) break;
      current = next;
    }
    
    return occurrences;
  }

  /// Whether this income is currently active (within date range).
  bool get isCurrentlyActive {
    final now = DateTime.now();
    if (!isActive) return false;
    if (now.isBefore(startDate)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  /// Display label for frequency.
  String get frequencyLabel {
    switch (frequency) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'biweekly':
        return 'Bi-weekly';
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'yearly':
        return 'Yearly';
      default:
        return frequency;
    }
  }

  RecurringIncome copyWith({
    String? title,
    String? description,
    double? amount,
    String? currency,
    String? categoryId,
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    String? frequency,
    int? dayOfMonth,
    int? dayOfWeek,
    bool? isActive,
    DateTime? updatedAt,
    String? notes,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    bool? autoCreateTransaction,
    bool? notifyOnDue,
    int? notifyDaysBefore,
    bool? reminderEnabled,
    String? remindersJson,
    DateTime? lastGeneratedDate,
    String? payerName,
    String? taxCategory,
    bool? isGuaranteed,
  }) {
    return RecurringIncome(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      notes: notes ?? this.notes,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      colorValue: colorValue ?? this.colorValue,
      autoCreateTransaction: autoCreateTransaction ?? this.autoCreateTransaction,
      notifyOnDue: notifyOnDue ?? this.notifyOnDue,
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      remindersJson: remindersJson ?? this.remindersJson,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      payerName: payerName ?? this.payerName,
      taxCategory: taxCategory ?? this.taxCategory,
      isGuaranteed: isGuaranteed ?? this.isGuaranteed,
    );
  }
}
