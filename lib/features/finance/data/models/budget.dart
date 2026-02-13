import 'dart:math' as math;

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../services/finance_settings_service.dart';

part 'budget.g.dart';

/// Budget period type
enum BudgetPeriod { daily, weekly, monthly, yearly, custom }

/// Budget model with Hive persistence
/// Represents a budget limit for a specific category or overall spending
@HiveType(typeId: 22)
class Budget extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3, defaultValue: 0.0)
  double amount; // Budget limit amount

  @HiveField(4, defaultValue: 'monthly')
  String period; // 'daily', 'weekly', 'monthly', 'yearly', 'custom'

  @HiveField(5)
  String? categoryId; // Null for overall budget, specific for category budget

  @HiveField(6)
  DateTime startDate;

  @HiveField(7)
  DateTime? endDate; // For custom period budgets or on_date end condition

  @HiveField(8, defaultValue: true)
  bool isActive; // Whether budget is currently active

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10, defaultValue: 0.0)
  double currentSpent; // Current spending against this budget

  @HiveField(11, defaultValue: true)
  bool alertEnabled; // Whether to alert when approaching/exceeding limit

  @HiveField(12, defaultValue: 80.0)
  double alertThreshold; // Percentage at which to alert (e.g., 80 = alert at 80%)

  @HiveField(13, defaultValue: false)
  bool carryOver; // Whether to carry over unspent amount to next period

  @HiveField(14)
  List<String>? excludedCategoryIds; // Categories to exclude from overall budget

  @HiveField(15, defaultValue: 'ETB')
  String currency; // Currency for this budget

  @HiveField(16)
  String? accountId; // Null means all accounts, otherwise account-specific budget

  @HiveField(17, defaultValue: 1)
  int periodSpan; // Every N periods (e.g., every 2 weeks)

  @HiveField(18, defaultValue: 'indefinite')
  String endCondition; // 'indefinite', 'on_date', 'after_transactions', 'after_spent'

  @HiveField(19)
  int? endTransactionCount; // End after this many matching transactions

  @HiveField(20)
  double? endSpentAmount; // End after this much matched spending

  @HiveField(21, defaultValue: 0)
  int matchedTransactionCount; // Lifetime matched transaction count

  @HiveField(22, defaultValue: 0.0)
  double lifetimeSpent; // Lifetime matched spending

  @HiveField(23, defaultValue: false)
  bool isPaused;

  @HiveField(24, defaultValue: false)
  bool isStopped;

  @HiveField(25)
  DateTime? stoppedAt;

  @HiveField(26)
  DateTime? endedAt;

  Budget({
    String? id,
    required this.name,
    this.description,
    required this.amount,
    this.period = 'monthly',
    this.categoryId,
    DateTime? startDate,
    this.endDate,
    this.isActive = true,
    DateTime? createdAt,
    this.currentSpent = 0.0,
    this.alertEnabled = true,
    this.alertThreshold = 80.0,
    this.carryOver = false,
    this.excludedCategoryIds,
    this.currency = FinanceSettingsService.fallbackCurrency,
    this.accountId,
    this.periodSpan = 1,
    this.endCondition = 'indefinite',
    this.endTransactionCount,
    this.endSpentAmount,
    this.matchedTransactionCount = 0,
    this.lifetimeSpent = 0.0,
    this.isPaused = false,
    this.isStopped = false,
    this.stoppedAt,
    this.endedAt,
  }) : id = id ?? const Uuid().v4(),
       startDate = startDate ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now() {
    if (periodSpan < 1) {
      periodSpan = 1;
    }
  }

  /// Get budget period enum
  BudgetPeriod get budgetPeriod {
    switch (period) {
      case 'daily':
        return BudgetPeriod.daily;
      case 'weekly':
        return BudgetPeriod.weekly;
      case 'yearly':
        return BudgetPeriod.yearly;
      case 'custom':
        return BudgetPeriod.custom;
      case 'monthly':
      default:
        return BudgetPeriod.monthly;
    }
  }

  /// Set budget period from enum
  set budgetPeriod(BudgetPeriod value) {
    period = value.name;
  }

  int get normalizedPeriodSpan => periodSpan < 1 ? 1 : periodSpan;

  /// Check if this is an overall budget (not category-specific)
  bool get isOverallBudget => categoryId == null;

  /// Check if this is a category-specific budget
  bool get isCategoryBudget => categoryId != null;

  /// Check if this budget is scoped to a single account
  bool get isAccountScoped => accountId != null;

  bool get isEnded => endedAt != null;

  bool get isPausedState => isPaused || (!isActive && !isStopped && !isEnded);

  bool get canTrack => isActive && !isPaused && !isStopped && !isEnded;

  bool get usesDateEnd => endCondition == 'on_date' && endDate != null;

  bool get usesTransactionEnd =>
      endCondition == 'after_transactions' && endTransactionCount != null;

  bool get usesSpentEnd =>
      endCondition == 'after_spent' && endSpentAmount != null;

  /// Get remaining amount
  double get remaining => amount - currentSpent;

  /// Get spending percentage
  double get spendingPercentage {
    if (amount <= 0) return 0;
    return ((currentSpent / amount) * 100)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  /// Check if budget is exceeded
  bool get isExceeded => currentSpent > amount;

  /// Check if approaching limit (based on alert threshold)
  bool get isApproachingLimit {
    return spendingPercentage >= alertThreshold && !isExceeded;
  }

  /// Check if budget alert should be triggered
  bool get shouldAlert {
    return alertEnabled && (isApproachingLimit || isExceeded);
  }

  DateTime _normalizeDate(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  DateTime _anchoredMonthStart(DateTime anchor, int monthOffset) {
    final totalMonths = (anchor.month - 1) + monthOffset;
    final year = anchor.year + (totalMonths ~/ 12);
    final month = (totalMonths % 12) + 1;
    final day = math.min(anchor.day, _daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  DateTime _anchoredYearStart(DateTime anchor, int yearOffset) {
    final year = anchor.year + yearOffset;
    final day = math.min(anchor.day, _daysInMonth(year, anchor.month));
    return DateTime(year, anchor.month, day);
  }

  /// Inclusive current period start for a given date.
  DateTime getCurrentPeriodStart({DateTime? asOf}) {
    final reference = _normalizeDate(asOf ?? DateTime.now());
    final anchor = _normalizeDate(startDate);
    final span = normalizedPeriodSpan;

    if (reference.isBefore(anchor)) {
      return anchor;
    }

    switch (budgetPeriod) {
      case BudgetPeriod.daily:
        final diffDays = reference.difference(anchor).inDays;
        final periodsElapsed = diffDays ~/ span;
        return anchor.add(Duration(days: periodsElapsed * span));
      case BudgetPeriod.weekly:
        final diffDays = reference.difference(anchor).inDays;
        final daysPerPeriod = span * 7;
        final periodsElapsed = diffDays ~/ daysPerPeriod;
        return anchor.add(Duration(days: periodsElapsed * daysPerPeriod));
      case BudgetPeriod.monthly:
        final monthOffset =
            (reference.year - anchor.year) * 12 +
            (reference.month - anchor.month);
        var periodsElapsed = monthOffset ~/ span;
        var candidate = _anchoredMonthStart(anchor, periodsElapsed * span);
        if (candidate.isAfter(reference)) {
          periodsElapsed -= 1;
          candidate = _anchoredMonthStart(anchor, periodsElapsed * span);
        }
        return candidate;
      case BudgetPeriod.yearly:
        final yearOffset = reference.year - anchor.year;
        var periodsElapsed = yearOffset ~/ span;
        var candidate = _anchoredYearStart(anchor, periodsElapsed * span);
        if (candidate.isAfter(reference)) {
          periodsElapsed -= 1;
          candidate = _anchoredYearStart(anchor, periodsElapsed * span);
        }
        return candidate;
      case BudgetPeriod.custom:
        return anchor;
    }
  }

  /// Inclusive current period end for a given date.
  DateTime getCurrentPeriodEnd({DateTime? asOf}) {
    final periodStart = getCurrentPeriodStart(asOf: asOf);
    final span = normalizedPeriodSpan;

    switch (budgetPeriod) {
      case BudgetPeriod.daily:
        return periodStart.add(Duration(days: span - 1));
      case BudgetPeriod.weekly:
        return periodStart.add(Duration(days: (span * 7) - 1));
      case BudgetPeriod.monthly:
        final anchor = _normalizeDate(startDate);
        final monthOffset =
            (periodStart.year - anchor.year) * 12 +
            (periodStart.month - anchor.month);
        final nextStart = _anchoredMonthStart(anchor, monthOffset + span);
        return nextStart.subtract(const Duration(days: 1));
      case BudgetPeriod.yearly:
        final anchor = _normalizeDate(startDate);
        final yearOffset = periodStart.year - anchor.year;
        final nextStart = _anchoredYearStart(anchor, yearOffset + span);
        return nextStart.subtract(const Duration(days: 1));
      case BudgetPeriod.custom:
        final configuredEnd = endDate != null
            ? _normalizeDate(endDate!)
            : _normalizeDate(startDate.add(const Duration(days: 30)));
        return configuredEnd;
    }
  }

  /// Backward-compatible getter using current date.
  DateTime get currentPeriodEnd => getCurrentPeriodEnd();

  /// Check if budget is currently in active period
  bool get isInActivePeriod {
    if (!canTrack) return false;
    return isInActivePeriodAt(DateTime.now());
  }

  /// Check if budget is active for a specific date.
  bool isInActivePeriodAt(DateTime date) {
    if (!canTrack) return false;
    final reference = _normalizeDate(date);
    final anchor = _normalizeDate(startDate);

    if (reference.isBefore(anchor)) return false;

    if (budgetPeriod == BudgetPeriod.custom) {
      final periodEnd = getCurrentPeriodEnd(asOf: reference);
      return !reference.isAfter(periodEnd);
    }

    return true;
  }

  /// Get days remaining in current period
  int get daysRemaining {
    final now = _normalizeDate(DateTime.now());
    final periodEnd = getCurrentPeriodEnd(asOf: now);
    if (now.isAfter(periodEnd)) return 0;
    return periodEnd.difference(now).inDays + 1;
  }

  /// Get formatted budget period description
  String get periodDescription {
    final span = normalizedPeriodSpan;
    switch (budgetPeriod) {
      case BudgetPeriod.daily:
        return span == 1 ? 'Daily' : 'Every $span days';
      case BudgetPeriod.weekly:
        return span == 1 ? 'Weekly' : 'Every $span weeks';
      case BudgetPeriod.monthly:
        return span == 1 ? 'Monthly' : 'Every $span months';
      case BudgetPeriod.yearly:
        return span == 1 ? 'Yearly' : 'Every $span years';
      case BudgetPeriod.custom:
        if (endDate != null) {
          return '${startDate.day}/${startDate.month} - ${endDate!.day}/${endDate!.month}';
        }
        return 'Custom Period';
    }
  }

  String get endConditionDescription {
    switch (endCondition) {
      case 'on_date':
        if (endDate == null) return 'Ends on date';
        return 'Ends ${endDate!.day}/${endDate!.month}/${endDate!.year}';
      case 'after_transactions':
        if (endTransactionCount == null) return 'Ends by transactions';
        return 'Ends after $endTransactionCount transactions';
      case 'after_spent':
        if (endSpentAmount == null) return 'Ends by spending';
        return 'Ends after ${endSpentAmount!.toStringAsFixed(2)} spent';
      case 'indefinite':
      default:
        return 'No end';
    }
  }

  /// Reset current spent for new period
  void resetForNewPeriod() {
    if (carryOver && remaining > 0) {
      // Carry over logic would adjust the amount for next period.
      // This could be implemented in the service layer.
    }
    currentSpent = 0.0;
  }

  void pause({DateTime? at}) {
    if (isStopped || isEnded) return;
    isActive = false;
    isPaused = true;
    isStopped = false;
    stoppedAt = null;
  }

  void resume() {
    if (isStopped || isEnded) return;
    isPaused = false;
    isActive = true;
  }

  void stop({DateTime? at}) {
    isActive = false;
    isPaused = false;
    isStopped = true;
    stoppedAt = _normalizeDate(at ?? DateTime.now());
    endedAt = null;
  }

  void end({DateTime? at}) {
    isActive = false;
    isPaused = false;
    isStopped = false;
    stoppedAt = null;
    endedAt = _normalizeDate(at ?? DateTime.now());
  }

  /// Create a copy with updated fields
  Budget copyWith({
    String? id,
    String? name,
    String? description,
    double? amount,
    String? period,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    double? currentSpent,
    bool? alertEnabled,
    double? alertThreshold,
    bool? carryOver,
    List<String>? excludedCategoryIds,
    String? currency,
    String? accountId,
    int? periodSpan,
    String? endCondition,
    int? endTransactionCount,
    double? endSpentAmount,
    int? matchedTransactionCount,
    double? lifetimeSpent,
    bool? isPaused,
    bool? isStopped,
    DateTime? stoppedAt,
    DateTime? endedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      categoryId: categoryId ?? this.categoryId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      currentSpent: currentSpent ?? this.currentSpent,
      alertEnabled: alertEnabled ?? this.alertEnabled,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      carryOver: carryOver ?? this.carryOver,
      excludedCategoryIds: excludedCategoryIds ?? this.excludedCategoryIds,
      currency: currency ?? this.currency,
      accountId: accountId ?? this.accountId,
      periodSpan: periodSpan ?? this.periodSpan,
      endCondition: endCondition ?? this.endCondition,
      endTransactionCount: endTransactionCount ?? this.endTransactionCount,
      endSpentAmount: endSpentAmount ?? this.endSpentAmount,
      matchedTransactionCount:
          matchedTransactionCount ?? this.matchedTransactionCount,
      lifetimeSpent: lifetimeSpent ?? this.lifetimeSpent,
      isPaused: isPaused ?? this.isPaused,
      isStopped: isStopped ?? this.isStopped,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
