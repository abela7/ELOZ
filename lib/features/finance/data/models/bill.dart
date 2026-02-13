import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/models/recurrence_rule.dart';
import 'bill_reminder.dart';

part 'bill.g.dart';

/// Bill/Subscription model with Hive persistence
/// Represents a recurring bill or subscription payment
@HiveType(typeId: 29)
class Bill extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String categoryId;

  @HiveField(4)
  String? accountId;

  /// 'bill' or 'subscription'
  @HiveField(5, defaultValue: 'bill')
  String type;

  /// 'fixed' = same amount every time, 'variable' = amount changes
  @HiveField(6, defaultValue: 'fixed')
  String amountType;

  /// Default/fixed amount (used when amountType is 'fixed')
  @HiveField(7, defaultValue: 0.0)
  double defaultAmount;

  @HiveField(8, defaultValue: 'ETB')
  String currency;

  /// Payment frequency: 'weekly', 'monthly', 'yearly', 'custom'
  @HiveField(9, defaultValue: 'monthly')
  String frequency;

  /// Recurrence rule JSON for custom schedules
  @HiveField(10)
  String? recurrenceRule;

  /// Day of month for monthly bills (1-31)
  @HiveField(11)
  int? dueDay;

  /// Next due date
  @HiveField(12)
  DateTime? nextDueDate;

  /// Last paid date
  @HiveField(13)
  DateTime? lastPaidDate;

  /// Last paid amount
  @HiveField(14)
  double? lastPaidAmount;

  @HiveField(15, defaultValue: true)
  bool isActive;

  @HiveField(16, defaultValue: false)
  bool autoPayEnabled;

  @HiveField(17, defaultValue: true)
  bool reminderEnabled;

  /// Reminder days before due (e.g., 3 = remind 3 days before)
  @HiveField(18, defaultValue: 3)
  int reminderDaysBefore;

  @HiveField(19)
  int? iconCodePoint;

  @HiveField(20)
  String? iconFontFamily;

  @HiveField(21)
  String? iconFontPackage;

  @HiveField(22, defaultValue: 0xFFCDAF56)
  int colorValue;

  @HiveField(23)
  DateTime createdAt;

  @HiveField(24)
  String? notes;

  /// Provider/Company name (e.g., "Netflix", "Water Company")
  @HiveField(25)
  String? providerName;

  /// Website or app link for payment
  @HiveField(26)
  String? paymentLink;

  /// Start date for recurrence calculations
  @HiveField(27)
  DateTime startDate;

  /// End condition: 'indefinite', 'after_occurrences', 'after_amount', 'on_date'
  @HiveField(28, defaultValue: 'indefinite')
  String endCondition;

  /// End after X occurrences (if endCondition == 'after_occurrences')
  @HiveField(29)
  int? endOccurrences;

  /// End after total paid amount reaches this value (if endCondition == 'after_amount')
  @HiveField(30)
  double? endAmount;

  /// End on specific date (if endCondition == 'on_date')
  @HiveField(31)
  DateTime? endDate;

  /// Count of paid occurrences
  @HiveField(32, defaultValue: 0)
  int occurrenceCount;

  /// Total paid amount across occurrences
  @HiveField(33, defaultValue: 0.0)
  double totalPaidAmount;

  /// Multi-reminder JSON (replaces single reminderDaysBefore)
  @HiveField(34)
  String? remindersJson;

  Bill({
    String? id,
    required this.name,
    this.description,
    required this.categoryId,
    this.accountId,
    this.type = 'bill',
    this.amountType = 'fixed',
    this.defaultAmount = 0.0,
    this.currency = 'ETB', // Default fallback, will be set from user settings
    this.frequency = 'monthly',
    this.recurrenceRule,
    this.dueDay,
    this.nextDueDate,
    this.lastPaidDate,
    this.lastPaidAmount,
    this.isActive = true,
    this.autoPayEnabled = false,
    this.reminderEnabled = true,
    this.reminderDaysBefore = 3,
    IconData? icon,
    Color? color,
    DateTime? createdAt,
    this.notes,
    this.providerName,
    this.paymentLink,
    DateTime? startDate,
    this.endCondition = 'indefinite',
    this.endOccurrences,
    this.endAmount,
    this.endDate,
    this.occurrenceCount = 0,
    this.totalPaidAmount = 0.0,
    this.remindersJson,
  }) : id = id ?? const Uuid().v4(),
       colorValue = color?.toARGB32() ?? const Color(0xFFCDAF56).toARGB32(),
       createdAt = createdAt ?? DateTime.now(),
       startDate = startDate ?? createdAt ?? DateTime.now() {
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
  set color(Color value) => colorValue = value.toARGB32();

  bool get isBill => type == 'bill';
  bool get isSubscription => type == 'subscription';
  bool get isFixed => amountType == 'fixed';
  bool get isVariable => amountType == 'variable';

  /// Get RecurrenceRule from stored JSON
  RecurrenceRule? get recurrence {
    if (recurrenceRule == null) return null;
    try {
      return RecurrenceRule.fromJson(recurrenceRule!);
    } catch (_) {
      return null;
    }
  }

  set recurrence(RecurrenceRule? value) {
    recurrenceRule = value?.toJson();
  }

  /// Get frequency display text
  String get frequencyText {
    switch (frequency) {
      case 'weekly':
        return '/week';
      case 'monthly':
        return '/month';
      case 'yearly':
        return '/year';
      case 'custom':
        return recurrence?.getDescription() ?? '/custom';
      default:
        return '';
    }
  }

  /// Check if bill is due soon (within reminder days)
  bool get isDueSoon {
    if (nextDueDate == null) return false;
    final now = DateTime.now();
    final daysUntilDue = nextDueDate!.difference(now).inDays;
    return daysUntilDue >= 0 && daysUntilDue <= reminderDaysBefore;
  }

  /// Check if bill is overdue
  bool get isOverdue {
    if (nextDueDate == null) return false;
    return DateTime.now().isAfter(nextDueDate!);
  }

  /// Get days until due (negative if overdue)
  int get daysUntilDue {
    if (nextDueDate == null) return 0;
    return nextDueDate!.difference(DateTime.now()).inDays;
  }

  /// Get reminders list with automatic migration from legacy reminderDaysBefore
  List<BillReminder> get reminders {
    // If we have remindersJson, decode it
    if (remindersJson != null && remindersJson!.isNotEmpty) {
      return BillReminder.decodeList(remindersJson);
    }
    
    // Migration: Convert legacy reminderDaysBefore to a single BillReminder
    if (reminderDaysBefore > 0) {
      // Auto-select type based on days before (matching old auto-type logic)
      String typeId;
      if (reminderDaysBefore >= 7) {
        typeId = 'finance_bill_upcoming';
      } else if (reminderDaysBefore >= 3) {
        typeId = 'finance_bill_tomorrow';
      } else if (reminderDaysBefore >= 1) {
        typeId = 'finance_payment_due';
      } else {
        typeId = 'finance_payment_due';
      }
      
      return [
        BillReminder(
          id: const Uuid().v4(),
          timing: 'before',
          value: reminderDaysBefore,
          unit: 'days',
          hour: 9,
          minute: 0,
          typeId: typeId,
          condition: 'always',
        ),
      ];
    }
    
    return [];
  }

  /// Set reminders list
  set reminders(List<BillReminder> value) {
    remindersJson = BillReminder.encodeList(value);
  }

  /// Check if bill is paid for current period.
  ///
  /// True only when [lastPaidDate] is on or after [nextDueDate], meaning we
  /// have recorded a payment that covers this due date. With normal payment
  /// flow we advance [nextDueDate] on pay, so we rarely have this—except when
  /// paying late or in edge cases. Using a simpler check avoids false positives
  /// (e.g. lastPaidDate from previous period incorrectly suppressing reminders).
  bool get isPaidForCurrentPeriod {
    if (nextDueDate == null || lastPaidDate == null) return false;
    return !lastPaidDate!.isBefore(nextDueDate!);
  }

  /// Create a copy with updated fields
  Bill copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    String? accountId,
    String? type,
    String? amountType,
    double? defaultAmount,
    String? currency,
    String? frequency,
    String? recurrenceRule,
    int? dueDay,
    DateTime? nextDueDate,
    DateTime? lastPaidDate,
    double? lastPaidAmount,
    bool? isActive,
    bool? autoPayEnabled,
    bool? reminderEnabled,
    int? reminderDaysBefore,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    DateTime? createdAt,
    String? notes,
    String? providerName,
    String? paymentLink,
    DateTime? startDate,
    String? endCondition,
    int? endOccurrences,
    double? endAmount,
    DateTime? endDate,
    int? occurrenceCount,
    double? totalPaidAmount,
    String? remindersJson,
  }) {
    final bill = Bill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      amountType: amountType ?? this.amountType,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      currency: currency ?? this.currency,
      frequency: frequency ?? this.frequency,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      dueDay: dueDay ?? this.dueDay,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      lastPaidDate: lastPaidDate ?? this.lastPaidDate,
      lastPaidAmount: lastPaidAmount ?? this.lastPaidAmount,
      isActive: isActive ?? this.isActive,
      autoPayEnabled: autoPayEnabled ?? this.autoPayEnabled,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      providerName: providerName ?? this.providerName,
      paymentLink: paymentLink ?? this.paymentLink,
      startDate: startDate ?? this.startDate,
      endCondition: endCondition ?? this.endCondition,
      endOccurrences: endOccurrences ?? this.endOccurrences,
      endAmount: endAmount ?? this.endAmount,
      endDate: endDate ?? this.endDate,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      totalPaidAmount: totalPaidAmount ?? this.totalPaidAmount,
      remindersJson: remindersJson ?? this.remindersJson,
    );
    bill.iconCodePoint = iconCodePoint ?? this.iconCodePoint;
    bill.iconFontFamily = iconFontFamily ?? this.iconFontFamily;
    bill.iconFontPackage = iconFontPackage ?? this.iconFontPackage;
    bill.colorValue = colorValue ?? this.colorValue;
    return bill;
  }
}
