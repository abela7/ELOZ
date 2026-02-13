import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/models/recurrence_rule.dart';
import '../../../../data/models/subtask.dart';

part 'habit.g.dart';

/// Habit frequency types
enum HabitFrequency {
  daily, // Every day
  weekly, // Specific days of the week
  xTimesPerWeek, // X times per week (flexible)
  xTimesPerMonth, // X times per month
  custom, // Custom interval
}

/// Habit completion types
enum HabitCompletionType {
  yesNo, // Simple Yes/No (default)
  numeric, // Value with unit (e.g., 8 hours, 2 liters)
  timer, // Duration tracking (e.g., Study 4 hours)
  checklist, // Multiple items to complete
  quit, // Avoid bad habit (inverted logic)
}

/// Habit model with Hive persistence
/// Represents a habit that users want to build or break
@HiveType(typeId: 10)
class Habit extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  int? iconCodePoint;

  @HiveField(4)
  String? iconFontFamily;

  @HiveField(5)
  String? iconFontPackage;

  @HiveField(6)
  int colorValue;

  @HiveField(7)
  String? categoryId;

  /// Frequency type: 'daily', 'weekly', 'xTimesPerWeek', 'xTimesPerMonth', 'custom'
  @HiveField(8)
  String frequencyType;

  /// For weekly: specific days (0=Sunday, 1=Monday, ..., 6=Saturday)
  /// e.g., [1, 3, 5] = Monday, Wednesday, Friday
  @HiveField(9)
  List<int>? weekDays;

  /// Target count per period (e.g., 3 times per week)
  @HiveField(10)
  int targetCount;

  /// Custom interval in days (for custom frequency)
  @HiveField(11)
  int? customIntervalDays;

  /// Current streak count
  @HiveField(12)
  int currentStreak;

  /// Best streak ever achieved
  @HiveField(13)
  int bestStreak;

  /// Total completions count
  @HiveField(14)
  int totalCompletions;

  /// Reminder time (stored as minutes from midnight)
  @HiveField(15)
  int? reminderMinutes;

  /// Whether reminders are enabled
  @HiveField(16)
  bool reminderEnabled;

  /// Notes or motivation for this habit
  @HiveField(17)
  String? notes;

  /// Whether this is a "good" habit to build or "bad" habit to break
  @HiveField(18)
  bool isGoodHabit;

  /// Whether the habit is archived (not deleted, just hidden)
  @HiveField(19)
  bool isArchived;

  /// Special habit - pinned for priority focus
  @HiveField(76)
  bool isSpecial;

  @HiveField(20)
  DateTime createdAt;

  @HiveField(21)
  DateTime? archivedAt;

  /// Last completion date (for streak calculation)
  @HiveField(22)
  DateTime? lastCompletedAt;

  /// Start date for the habit (when user started tracking)
  @HiveField(23)
  DateTime startDate;

  /// Optional end date (for temporary habits or challenges)
  @HiveField(24)
  DateTime? endDate;

  /// Order index for custom sorting
  @HiveField(25)
  int sortOrder;

  /// List of tag strings
  @HiveField(26)
  List<String>? tags;

  /// Reason for not completing (can be reason ID or custom text)
  @HiveField(27)
  String? notDoneReason;

  /// Reason for postponing (can be reason ID or custom text)
  @HiveField(28)
  String? postponeReason;

  /// Reference to habit type for points system
  @HiveField(29)
  String? habitTypeId;

  /// Points earned/lost for this habit
  @HiveField(30)
  int pointsEarned;

  /// Completion type: 'yesNo', 'numeric', 'timer', 'checklist', 'quit'
  @HiveField(31)
  String completionType;

  /// For Yes/No type: Custom points for YES answer (overrides habitType if set)
  @HiveField(32)
  int? customYesPoints;

  /// For Yes/No type: Custom points for NO answer (overrides habitType if set)
  @HiveField(33)
  int? customNoPoints;

  /// For Yes/No type: Custom points for POSTPONE (overrides habitType if set)
  @HiveField(34)
  int? customPostponePoints;

  /// For Numeric type: Target value to achieve
  @HiveField(35)
  double? targetValue;

  /// For Numeric type: Unit of measurement
  @HiveField(36)
  String? unit;

  /// For Numeric type: Custom unit name if unit is 'custom'
  @HiveField(37)
  String? customUnitName;

  /// For Timer type: Target duration in minutes
  @HiveField(38)
  int? targetDurationMinutes;

  /// Point calculation method: 'allOrNothing', 'proportional', 'perUnit', 'threshold'
  @HiveField(39)
  String? pointCalculation;

  /// For threshold calculation: percentage needed for full points (e.g., 80)
  @HiveField(40)
  double? thresholdPercent;

  /// For perUnit calculation: points earned per unit
  @HiveField(41)
  int? pointsPerUnit;

  /// For Timer type: 'target' (must reach) or 'minimum' (can exceed for bonus)
  @HiveField(42)
  String? timerType;

  /// For Timer type with minimum: bonus points per minute beyond minimum
  @HiveField(43)
  double? bonusPerMinute;

  /// For Timer type: whether to allow overtime bonus (for target type)
  @HiveField(44)
  bool? allowOvertimeBonus;

  /// For Timer type: Unit of time - 'hour', 'minute', 'second'
  @HiveField(45)
  String? timeUnit;

  // ============ Quit Bad Habit Fields ============

  /// For Quit type: Daily reward points for NOT doing the habit
  @HiveField(46)
  int? dailyReward;

  /// For Quit type: Penalty for slipping (fixed amount)
  @HiveField(47)
  int? slipPenalty;

  /// For Quit type: Slip calculation - 'fixed' or 'perUnit'
  @HiveField(48)
  String? slipCalculation;

  /// For Quit type: Penalty per unit consumed (if perUnit calculation)
  @HiveField(49)
  int? penaltyPerUnit;

  /// For Quit type: Number of allowed slips before breaking streak
  @HiveField(50)
  int? streakProtection;

  /// For Quit type: Current slip count within streak protection window
  @HiveField(51)
  int? currentSlipCount;

  /// For Quit type: Cost per unit for money tracking ($)
  @HiveField(52)
  double? costPerUnit;

  /// For Quit type: Enable/disable cost tracking
  @HiveField(80)
  bool? costTrackingEnabled;

  /// For Quit type: Currency symbol/abbr (e.g., $, £, USD)
  @HiveField(81)
  String? currencySymbol;

  /// For Quit type: Whether temptation tracking is enabled
  @HiveField(53)
  bool? enableTemptationTracking;

  /// For Quit type: Total money saved so far
  @HiveField(54)
  double? moneySaved;

  /// For Quit type: Total units avoided
  @HiveField(55)
  int? unitsAvoided;

  /// Whether habit is currently active (being worked on)
  @HiveField(56)
  bool? quitHabitActive;

  /// Date when habit was marked inactive (successfully quit)
  @HiveField(57)
  DateTime? quitCompletedDate;

  /// Period for frequency: 'day', 'week', 'month', 'year'
  @HiveField(58)
  String? frequencyPeriod;

  /// End condition: 'never', 'on_date', 'after_occurrences'
  @HiveField(59)
  String? endCondition;

  /// End after X occurrences
  @HiveField(60)
  int? endOccurrences;

  /// Checklist items for 'checklist' completion type
  @HiveField(61)
  List<Subtask>? checklist;

  /// For Quit type: Action name (what you're quitting - e.g., 'Drink', 'Smoke', 'Eat')
  @HiveField(62)
  String? quitActionName;

  /// For Quit type: The substance/thing being quit (e.g., 'Alcohol', 'Cigarettes', 'Junk Food')
  @HiveField(63)
  String? quitSubstance;

  /// For Quit type: Hide from dashboard and main lists
  @HiveField(79)
  bool? hideQuitHabit;

  /// Recurrence rule JSON string (standardized scheduling)
  /// This is the primary scheduling engine for cross-app integration
  @HiveField(64)
  String? recurrenceRuleJson;

  // In-memory cache to avoid reparsing recurrence JSON on every due-check.
  String? _cachedRecurrenceRuleJson;
  RecurrenceRule? _cachedRecurrenceRule;
  bool _hasTriedRecurrenceParse = false;

  /// Reminder duration (e.g., '5 min before', 'At task time')
  /// This matches the task reminder system
  @HiveField(65)
  String? reminderDuration;

  /// The 'Why' factor - a short motivational sentence
  @HiveField(66)
  String? motivation;

  /// Whether this habit has a specific time (true) or is anytime/all-day (false)
  @HiveField(67)
  bool hasSpecificTime;

  /// The specific time minutes for time-based habits (used instead of reminderMinutes for habit time)
  @HiveField(68)
  int? habitTimeMinutes;

  /// Goal/Milestone tracking - Type of goal (null if no goal set)
  @HiveField(69)
  String? goalType; // 'streak', 'count', 'duration'

  /// Goal target value (e.g., 30 for "30-day streak", 100 for "100 completions")
  @HiveField(70)
  int? goalTarget;

  /// When the goal was set (for duration-based goals)
  @HiveField(71)
  DateTime? goalStartDate;

  /// When the goal was achieved (null if not yet achieved)
  @HiveField(72)
  DateTime? goalCompletedDate;

  /// Habit lifecycle status (tracks maturity/state of the habit)
  @HiveField(73)
  String habitStatus; // 'active', 'built', 'paused', 'failed', 'completed'

  /// When the status was last changed (for analytics)
  @HiveField(74)
  DateTime? statusChangedDate;

  /// For paused habits - when to auto-resume (null = indefinite pause)
  @HiveField(75)
  DateTime? pausedUntil;

  /// Snooze tracking - when the habit is snoozed until
  @HiveField(77)
  DateTime? snoozedUntil;

  /// Snooze history (JSON string):
  /// [{at, minutes, until, occurrenceDate, source, notificationId, alarmId}]
  @HiveField(78)
  String? snoozeHistory;

  Habit({
    String? id,
    required this.title,
    this.description,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    int? colorValue,
    this.categoryId,
    this.frequencyType = 'daily',
    this.weekDays,
    this.targetCount = 1,
    this.customIntervalDays,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalCompletions = 0,
    this.reminderMinutes,
    this.reminderEnabled = false,
    this.notes,
    this.isGoodHabit = true,
    this.isArchived = false,
    this.isSpecial = false,
    DateTime? createdAt,
    this.archivedAt,
    this.lastCompletedAt,
    DateTime? startDate,
    this.endDate,
    this.sortOrder = 0,
    this.tags,
    this.notDoneReason,
    this.postponeReason,
    this.habitTypeId,
    this.pointsEarned = 0,
    this.completionType = 'yesNo',
    this.customYesPoints,
    this.customNoPoints,
    this.customPostponePoints,
    this.targetValue,
    this.unit,
    this.customUnitName,
    this.targetDurationMinutes,
    this.pointCalculation,
    this.thresholdPercent,
    this.pointsPerUnit,
    this.timerType,
    this.bonusPerMinute,
    this.allowOvertimeBonus,
    this.timeUnit,
    this.dailyReward,
    this.slipPenalty,
    this.slipCalculation,
    this.penaltyPerUnit,
    this.streakProtection,
    this.currentSlipCount,
    this.costPerUnit,
    this.costTrackingEnabled,
    this.currencySymbol,
    this.enableTemptationTracking,
    this.moneySaved,
    this.unitsAvoided,
    this.quitHabitActive,
    this.quitCompletedDate,
    this.frequencyPeriod,
    this.endCondition,
    this.endOccurrences,
    this.checklist,
    this.quitActionName,
    this.quitSubstance,
    this.hideQuitHabit = true,
    this.recurrenceRuleJson,
    this.reminderDuration,
    this.motivation,
    this.hasSpecificTime = false,
    this.habitTimeMinutes,
    this.goalType,
    this.goalTarget,
    this.goalStartDate,
    this.goalCompletedDate,
    this.habitStatus = 'active',
    this.statusChangedDate,
    this.pausedUntil,
    this.snoozedUntil,
    this.snoozeHistory,
    RecurrenceRule? recurrence,
  }) : id = id ?? const Uuid().v4(),
       colorValue = colorValue ?? Colors.blue.value,
       createdAt = createdAt ?? DateTime.now(),
       startDate = startDate ?? DateTime.now() {
    // Set recurrenceRuleJson from RecurrenceRule if provided
    if (recurrence != null && recurrenceRuleJson == null) {
      this.recurrenceRuleJson = recurrence.toJson();
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

  /// Get reminder TimeOfDay from stored minutes
  TimeOfDay? get reminderTime {
    if (reminderMinutes == null) return null;
    return TimeOfDay(
      hour: reminderMinutes! ~/ 60,
      minute: reminderMinutes! % 60,
    );
  }

  /// Set reminder TimeOfDay by storing minutes
  set reminderTime(TimeOfDay? value) {
    reminderMinutes = value != null ? value.hour * 60 + value.minute : null;
  }

  /// Get habit time (when the habit should be done) from stored minutes
  TimeOfDay? get habitTime {
    if (habitTimeMinutes == null) return null;
    return TimeOfDay(
      hour: habitTimeMinutes! ~/ 60,
      minute: habitTimeMinutes! % 60,
    );
  }

  /// Set habit time by storing minutes
  set habitTime(TimeOfDay? value) {
    habitTimeMinutes = value != null ? value.hour * 60 + value.minute : null;
  }

  /// Get RecurrenceRule from stored JSON string
  RecurrenceRule? get recurrence {
    final json = recurrenceRuleJson;
    if (json == null || json.isEmpty) {
      _cachedRecurrenceRuleJson = json;
      _cachedRecurrenceRule = null;
      _hasTriedRecurrenceParse = true;
      return null;
    }

    if (_hasTriedRecurrenceParse && _cachedRecurrenceRuleJson == json) {
      return _cachedRecurrenceRule;
    }

    try {
      _cachedRecurrenceRule = RecurrenceRule.fromJson(json);
    } catch (_) {
      _cachedRecurrenceRule = null;
    }
    _cachedRecurrenceRuleJson = json;
    _hasTriedRecurrenceParse = true;
    return _cachedRecurrenceRule;
  }

  /// Set RecurrenceRule by storing JSON string
  set recurrence(RecurrenceRule? value) {
    recurrenceRuleJson = value?.toJson();
    _cachedRecurrenceRuleJson = recurrenceRuleJson;
    _cachedRecurrenceRule = value;
    _hasTriedRecurrenceParse = true;
  }

  /// Check if habit uses RecurrenceRule for scheduling
  bool get hasRecurrence => recurrence != null;

  /// Get frequency enum from stored string
  HabitFrequency get frequency {
    switch (frequencyType) {
      case 'daily':
        return HabitFrequency.daily;
      case 'weekly':
        return HabitFrequency.weekly;
      case 'xTimesPerWeek':
        return HabitFrequency.xTimesPerWeek;
      case 'xTimesPerMonth':
        return HabitFrequency.xTimesPerMonth;
      case 'custom':
        return HabitFrequency.custom;
      default:
        return HabitFrequency.daily;
    }
  }

  /// Get human-readable frequency description
  String get frequencyDescription {
    if (frequencyType == 'custom') {
      final period = frequencyPeriod ?? 'day';
      if (targetCount > 1) {
        return '$targetCount times per ${period[0].toUpperCase()}${period.substring(1)}';
      } else {
        return 'Once per ${period[0].toUpperCase()}${period.substring(1)}';
      }
    }

    switch (frequency) {
      case HabitFrequency.daily:
        return 'Every day';
      case HabitFrequency.weekly:
        if (weekDays != null && weekDays!.isNotEmpty) {
          final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
          final days = weekDays!.map((d) => dayNames[d]).join(', ');
          return 'Every $days';
        }
        return 'Weekly';
      case HabitFrequency.xTimesPerWeek:
        return '$targetCount times per week';
      case HabitFrequency.xTimesPerMonth:
        return '$targetCount times per month';
      case HabitFrequency.custom:
        if (customIntervalDays != null) {
          if (customIntervalDays == 1) return 'Every day';
          return 'Every $customIntervalDays days';
        }
        return 'Custom';
    }
  }

  /// Get estimation of next due date or period description
  String get nextDuePreview {
    final now = DateTime.now();

    if (frequencyType == 'daily') {
      return 'Tomorrow, ${DateFormat('MMM d').format(now.add(const Duration(days: 1)))}';
    }

    if (frequencyType == 'weekly' && weekDays != null && weekDays!.isNotEmpty) {
      final todayWeekday = now.weekday % 7;
      int daysUntil = 1;
      while (daysUntil <= 7) {
        final nextDay = (todayWeekday + daysUntil) % 7;
        if (weekDays!.contains(nextDay)) {
          return DateFormat(
            'EEEE, MMM d',
          ).format(now.add(Duration(days: daysUntil)));
        }
        daysUntil++;
      }
    }

    if (frequencyType == 'custom') {
      final period = frequencyPeriod ?? 'day';
      switch (period) {
        case 'day':
          return 'Due today';
        case 'week':
          return 'Sometime this week';
        case 'month':
          return 'Sometime this month';
        case 'year':
          return 'Sometime this year';
      }
    }

    return 'Pending';
  }

  /// Check if habit has reached its end condition by occurrences
  bool get hasReachedEndOccurrences {
    if (endCondition != 'after_occurrences' || endOccurrences == null) {
      return false;
    }
    return totalCompletions >= endOccurrences!;
  }

  /// Check if habit is active on a specific date (start/end conditions)
  bool isActiveOn(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startDateOnly = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    if (dateOnly.isBefore(startDateOnly)) {
      return false;
    }
    if (endCondition == 'on_date' && endDate != null) {
      final endDateOnly = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (dateOnly.isAfter(endDateOnly)) {
        return false;
      }
    }
    if (hasReachedEndOccurrences) {
      return false;
    }
    return true;
  }

  /// Check if habit should be done today based on frequency
  bool get isDueToday => isDueOn(DateTime.now());

  /// Check if habit is due on a specific date
  bool isDueOn(DateTime date) {
    if (!isActiveOn(date)) return false;
    final recurrenceRule = recurrence;
    if (recurrenceRule != null) {
      return recurrenceRule.isDueOn(date);
    }
    return _isDueByLegacyFrequency(date);
  }

  bool _isDueByLegacyFrequency(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final weekday = dateOnly.weekday % 7; // 0=Sunday in our system

    switch (frequency) {
      case HabitFrequency.daily:
        return true;
      case HabitFrequency.weekly:
        return weekDays?.contains(weekday) ?? false;
      case HabitFrequency.xTimesPerWeek:
      case HabitFrequency.xTimesPerMonth:
        // Always show, user decides when to complete
        return true;
      case HabitFrequency.custom:
        if (customIntervalDays == null || lastCompletedAt == null) return true;
        final lastDateOnly = DateTime(
          lastCompletedAt!.year,
          lastCompletedAt!.month,
          lastCompletedAt!.day,
        );
        if (dateOnly.isBefore(lastDateOnly)) return false;
        final daysSinceLastCompletion = dateOnly
            .difference(lastDateOnly)
            .inDays;
        return daysSinceLastCompletion >= customIntervalDays!;
    }
  }

  /// Get the next occurrence date for this habit
  DateTime? get nextDueDate {
    final recurrenceRule = recurrence;
    if (recurrenceRule != null) {
      return recurrenceRule.getNextOccurrence(DateTime.now());
    }
    // Fallback: return tomorrow for daily, calculate for others
    if (frequencyType == 'daily') {
      return DateTime.now().add(const Duration(days: 1));
    }
    return null;
  }

  /// Get all due dates within a date range (for reports/calendar)
  List<DateTime> getDueDatesInRange(DateTime start, DateTime end) {
    final recurrenceRule = recurrence;
    if (recurrenceRule != null) {
      return recurrenceRule
          .getOccurrencesInRange(start, end)
          .where(isActiveOn)
          .toList();
    }
    return [];
  }

  /// Get the current period boundaries for quota tracking
  /// Returns {'start': DateTime, 'end': DateTime}
  Map<String, DateTime> getCurrentPeriod() {
    final recurrenceRule = recurrence;
    if (recurrenceRule != null) {
      return recurrenceRule.getCurrentPeriod(DateTime.now());
    }
    // Fallback based on frequencyPeriod
    final now = DateTime.now();
    final period = frequencyPeriod ?? 'day';

    switch (period) {
      case 'week':
        final daysSinceSunday = now.weekday % 7;
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysSinceSunday));
        return {'start': start, 'end': start.add(const Duration(days: 7))};
      case 'month':
        return {
          'start': DateTime(now.year, now.month, 1),
          'end': DateTime(now.year, now.month + 1, 1),
        };
      case 'year':
        return {
          'start': DateTime(now.year, 1, 1),
          'end': DateTime(now.year + 1, 1, 1),
        };
      default:
        return {
          'start': DateTime(now.year, now.month, now.day),
          'end': DateTime(now.year, now.month, now.day + 1),
        };
    }
  }

  /// Create a copy with updated fields
  Habit copyWith({
    String? id,
    String? title,
    String? description,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    String? categoryId,
    String? frequencyType,
    List<int>? weekDays,
    int? targetCount,
    int? customIntervalDays,
    int? currentStreak,
    int? bestStreak,
    int? totalCompletions,
    int? reminderMinutes,
    bool? reminderEnabled,
    String? notes,
    bool? isGoodHabit,
    bool? isArchived,
    bool? isSpecial,
    DateTime? createdAt,
    DateTime? archivedAt,
    DateTime? lastCompletedAt,
    DateTime? startDate,
    DateTime? endDate,
    int? sortOrder,
    List<String>? tags,
    String? notDoneReason,
    String? postponeReason,
    String? habitTypeId,
    int? pointsEarned,
    String? completionType,
    int? customYesPoints,
    int? customNoPoints,
    int? customPostponePoints,
    double? targetValue,
    String? unit,
    String? customUnitName,
    int? targetDurationMinutes,
    String? pointCalculation,
    double? thresholdPercent,
    int? pointsPerUnit,
    String? timerType,
    double? bonusPerMinute,
    bool? allowOvertimeBonus,
    String? timeUnit,
    int? dailyReward,
    int? slipPenalty,
    String? slipCalculation,
    int? penaltyPerUnit,
    int? streakProtection,
    int? currentSlipCount,
    double? costPerUnit,
    bool? costTrackingEnabled,
    String? currencySymbol,
    bool? enableTemptationTracking,
    double? moneySaved,
    int? unitsAvoided,
    bool? quitHabitActive,
    DateTime? quitCompletedDate,
    String? frequencyPeriod,
    String? endCondition,
    int? endOccurrences,
    List<Subtask>? checklist,
    String? quitActionName,
    String? quitSubstance,
    bool? hideQuitHabit,
    String? recurrenceRuleJson,
    String? reminderDuration,
    String? motivation,
    bool? hasSpecificTime,
    int? habitTimeMinutes,
    String? goalType,
    int? goalTarget,
    DateTime? goalStartDate,
    DateTime? goalCompletedDate,
    String? habitStatus,
    DateTime? statusChangedDate,
    DateTime? pausedUntil,
    DateTime? snoozedUntil,
    String? snoozeHistory,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      colorValue: colorValue ?? this.colorValue,
      categoryId: categoryId ?? this.categoryId,
      frequencyType: frequencyType ?? this.frequencyType,
      weekDays: weekDays ?? this.weekDays,
      targetCount: targetCount ?? this.targetCount,
      customIntervalDays: customIntervalDays ?? this.customIntervalDays,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      notes: notes ?? this.notes,
      isGoodHabit: isGoodHabit ?? this.isGoodHabit,
      isArchived: isArchived ?? this.isArchived,
      isSpecial: isSpecial ?? this.isSpecial,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      sortOrder: sortOrder ?? this.sortOrder,
      tags: tags ?? this.tags,
      notDoneReason: notDoneReason ?? this.notDoneReason,
      postponeReason: postponeReason ?? this.postponeReason,
      habitTypeId: habitTypeId ?? this.habitTypeId,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      completionType: completionType ?? this.completionType,
      customYesPoints: customYesPoints ?? this.customYesPoints,
      customNoPoints: customNoPoints ?? this.customNoPoints,
      customPostponePoints: customPostponePoints ?? this.customPostponePoints,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      customUnitName: customUnitName ?? this.customUnitName,
      targetDurationMinutes:
          targetDurationMinutes ?? this.targetDurationMinutes,
      pointCalculation: pointCalculation ?? this.pointCalculation,
      thresholdPercent: thresholdPercent ?? this.thresholdPercent,
      pointsPerUnit: pointsPerUnit ?? this.pointsPerUnit,
      timerType: timerType ?? this.timerType,
      bonusPerMinute: bonusPerMinute ?? this.bonusPerMinute,
      allowOvertimeBonus: allowOvertimeBonus ?? this.allowOvertimeBonus,
      timeUnit: timeUnit ?? this.timeUnit,
      dailyReward: dailyReward ?? this.dailyReward,
      slipPenalty: slipPenalty ?? this.slipPenalty,
      slipCalculation: slipCalculation ?? this.slipCalculation,
      penaltyPerUnit: penaltyPerUnit ?? this.penaltyPerUnit,
      streakProtection: streakProtection ?? this.streakProtection,
      currentSlipCount: currentSlipCount ?? this.currentSlipCount,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      costTrackingEnabled: costTrackingEnabled ?? this.costTrackingEnabled,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      enableTemptationTracking:
          enableTemptationTracking ?? this.enableTemptationTracking,
      moneySaved: moneySaved ?? this.moneySaved,
      unitsAvoided: unitsAvoided ?? this.unitsAvoided,
      quitHabitActive: quitHabitActive ?? this.quitHabitActive,
      quitCompletedDate: quitCompletedDate ?? this.quitCompletedDate,
      frequencyPeriod: frequencyPeriod ?? this.frequencyPeriod,
      endCondition: endCondition ?? this.endCondition,
      endOccurrences: endOccurrences ?? this.endOccurrences,
      checklist: checklist ?? this.checklist,
      quitActionName: quitActionName ?? this.quitActionName,
      quitSubstance: quitSubstance ?? this.quitSubstance,
      hideQuitHabit: hideQuitHabit ?? this.hideQuitHabit,
      recurrenceRuleJson: recurrenceRuleJson ?? this.recurrenceRuleJson,
      reminderDuration: reminderDuration ?? this.reminderDuration,
      motivation: motivation ?? this.motivation,
      hasSpecificTime: hasSpecificTime ?? this.hasSpecificTime,
      habitTimeMinutes: habitTimeMinutes ?? this.habitTimeMinutes,
      goalType: goalType ?? this.goalType,
      goalTarget: goalTarget ?? this.goalTarget,
      goalStartDate: goalStartDate ?? this.goalStartDate,
      goalCompletedDate: goalCompletedDate ?? this.goalCompletedDate,
      habitStatus: habitStatus ?? this.habitStatus,
      statusChangedDate: statusChangedDate ?? this.statusChangedDate,
      pausedUntil: pausedUntil ?? this.pausedUntil,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      snoozeHistory: snoozeHistory ?? this.snoozeHistory,
    );
  }

  // ============ Goal/Milestone Helpers ============

  /// Check if habit has a goal set
  bool get hasGoal => goalType != null && goalTarget != null;

  /// Check if goal is achieved
  bool get isGoalAchieved => goalCompletedDate != null;

  /// Goal target sanitized to a positive value when available.
  int? get goalTargetSafe {
    if (!hasGoal) return null;
    final raw = goalTarget ?? 0;
    return raw <= 0 ? null : raw;
  }

  /// Human readable goal type name.
  String get goalTypeDisplayName {
    switch (goalType) {
      case 'streak':
        return 'Streak Goal';
      case 'count':
        return 'Completion Goal';
      case 'duration':
        return 'Duration Goal';
      default:
        return 'Goal';
    }
  }

  /// Count elapsed days for duration goals using date-only math.
  /// Includes the start date as day 1 when active.
  int get goalElapsedDays {
    if (goalStartDate == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      goalStartDate!.year,
      goalStartDate!.month,
      goalStartDate!.day,
    );
    if (today.isBefore(start)) return 0;
    return today.difference(start).inDays + 1;
  }

  /// Current value used for goal tracking.
  int get goalCurrentValue {
    if (!hasGoal) return 0;
    switch (goalType) {
      case 'streak':
        return currentStreak.clamp(0, 999999);
      case 'count':
        return totalCompletions.clamp(0, 999999);
      case 'duration':
        return goalElapsedDays.clamp(0, 999999);
      default:
        return 0;
    }
  }

  /// Unit label used in UI for goal progress.
  String get goalUnitLabel {
    switch (goalType) {
      case 'streak':
        return 'days';
      case 'duration':
        return 'days';
      case 'count':
        if (isQuitHabit) return 'resisted days';
        if (isTimer) return 'sessions';
        if (isNumeric) return 'logs';
        if (completionType == 'checklist') return 'completed days';
        return 'completions';
      default:
        return 'units';
    }
  }

  /// Short explanation of how this goal is measured.
  String get goalMeasurementHint {
    switch (goalType) {
      case 'streak':
        return 'Measured by your current consecutive successful days.';
      case 'count':
        if (isQuitHabit) {
          return 'Measured by total successful no-slip days logged.';
        }
        return 'Measured by total successful completion records.';
      case 'duration':
        return 'Measured by elapsed calendar days since goal start.';
      default:
        return 'Goal progress updates from your habit records.';
    }
  }

  /// Progress ratio (0..1).
  double get goalProgressRatio {
    final target = goalTargetSafe;
    if (target == null) return 0.0;
    return (goalCurrentValue / target).clamp(0.0, 1.0);
  }

  /// Remaining value until target.
  int get goalRemainingValue {
    final target = goalTargetSafe;
    if (target == null) return 0;
    return math.max(0, target - goalCurrentValue);
  }

  /// Progress milestones in percentages.
  List<int> get goalMilestones => const [25, 50, 75, 100];

  /// Next milestone to reach (or null if already complete).
  int? get nextGoalMilestone {
    final pct = goalProgress;
    for (final m in goalMilestones) {
      if (pct < m) return m;
    }
    return null;
  }

  // ============ Habit Status Helpers ============

  /// Check if habit is actively being worked on
  bool get isStatusActive => habitStatus == 'active';

  /// Check if habit is fully built/established
  bool get isStatusBuilt => habitStatus == 'built';

  /// Check if habit is paused
  bool get isStatusPaused => habitStatus == 'paused';

  /// Check if habit failed/abandoned
  bool get isStatusFailed => habitStatus == 'failed';

  /// Check if habit is completed (goal reached)
  bool get isStatusCompleted => habitStatus == 'completed';

  /// Check if pause has expired and should auto-resume
  bool get shouldAutoResume {
    if (!isStatusPaused || pausedUntil == null) return false;
    return DateTime.now().isAfter(pausedUntil!);
  }

  /// Check if habit is currently snoozed (regardless of which day).
  bool get isSnoozed {
    if (snoozedUntil == null) return false;
    return snoozedUntil!.isAfter(DateTime.now());
  }

  /// Check if habit is currently snoozed for a specific occurrence date.
  bool isSnoozedOn(DateTime date) {
    return activeSnoozedUntilForDate(date) != null;
  }

  /// Check if habit is currently snoozed **for today's occurrence**.
  bool get isSnoozedToday {
    return isSnoozedOn(DateTime.now());
  }

  /// Parsed snooze history entries (most-recent last)
  List<Map<String, dynamic>> get snoozeHistoryEntries {
    final raw = (snoozeHistory ?? '').trim();
    if (raw.isEmpty) return const [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
  }

  /// Snooze history entries for a specific date (per-instance view).
  List<Map<String, dynamic>> snoozeHistoryEntriesForDate(DateTime date) {
    final history = snoozeHistoryEntries;
    if (history.isEmpty) return const [];

    final dateKey = _formatDateKey(date);

    return history
        .where((entry) {
          final occurrenceDate = entry['occurrenceDate'] as String?;
          if (occurrenceDate != null && occurrenceDate.isNotEmpty) {
            return occurrenceDate == dateKey;
          }

          final at = entry['at'] as String?;
          if (at == null || at.isEmpty) return false;
          final parsed = DateTime.tryParse(at);
          if (parsed == null) return false;
          return parsed.year == date.year &&
              parsed.month == date.month &&
              parsed.day == date.day;
        })
        .toList(growable: false);
  }

  /// Latest snoozed-until timestamp for a specific date.
  DateTime? latestSnoozedUntilForDate(DateTime date) {
    final entries = snoozeHistoryEntriesForDate(date);
    if (entries.isEmpty) return null;

    DateTime? latest;
    for (final entry in entries) {
      final untilStr = entry['until'] as String?;
      if (untilStr == null || untilStr.isEmpty) continue;
      final until = DateTime.tryParse(untilStr);
      if (until == null) continue;
      if (latest == null || until.isAfter(latest)) {
        latest = until;
      }
    }

    return latest;
  }

  /// Active snooze-until timestamp for a specific date (if still in the future).
  DateTime? activeSnoozedUntilForDate(DateTime date) {
    final latest = latestSnoozedUntilForDate(date);
    if (latest == null) return null;
    return latest.isAfter(DateTime.now()) ? latest : null;
  }

  /// Snooze history entries for the current day only (per-instance view).
  List<Map<String, dynamic>> get todaySnoozeHistoryEntries {
    return snoozeHistoryEntriesForDate(DateTime.now());
  }

  /// Get status display name
  String get statusDisplayName {
    switch (habitStatus) {
      case 'active':
        return 'Active';
      case 'built':
        return 'Built';
      case 'paused':
        return 'Paused';
      case 'failed':
        return 'Failed';
      case 'completed':
        return 'Completed';
      default:
        return 'Active';
    }
  }

  /// Get status icon
  IconData get statusIcon {
    switch (habitStatus) {
      case 'active':
        return Icons.play_circle_filled_rounded;
      case 'built':
        return Icons.verified_rounded;
      case 'paused':
        return Icons.pause_circle_filled_rounded;
      case 'failed':
        return Icons.cancel_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.play_circle_filled_rounded;
    }
  }

  /// Get status color
  Color get statusColor {
    switch (habitStatus) {
      case 'active':
        return const Color(0xFFCDAF56); // Gold
      case 'built':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return const Color(0xFFCDAF56);
    }
  }

  /// Get goal progress percentage (0-100)
  double get goalProgress {
    return goalProgressRatio * 100;
  }

  /// Get human-readable goal description
  String? get goalDescription {
    if (!hasGoal) return null;

    final target = goalTargetSafe;
    if (target == null) return null;

    switch (goalType) {
      case 'streak':
        return 'Reach a $target-day streak';
      case 'count':
        return 'Complete $target $goalUnitLabel';
      case 'duration':
        return 'Maintain for $target days';
      default:
        return null;
    }
  }

  /// Get goal progress summary for UI (e.g., "15/30 days")
  String? get goalProgressSummary {
    if (!hasGoal) return null;

    final target = goalTargetSafe;
    if (target == null) return null;

    return '$goalCurrentValue/$target $goalUnitLabel';
  }

  /// Check if user should be congratulated (goal just achieved)
  bool shouldCelebrateGoal() {
    if (!hasGoal || isGoalAchieved) return false;

    final target = goalTargetSafe;
    if (target == null) return false;
    return goalCurrentValue >= target;
  }

  // ============ Quit Bad Habit Helpers ============

  /// Check if this is a quit bad habit type
  bool get isQuitHabit => completionType == 'quit';

  /// Should this quit habit be hidden from main dashboards/lists
  bool get shouldHideQuitHabit => isQuitHabit && (hideQuitHabit ?? true);

  /// Check if quit habit is currently active (being worked on)
  bool get isQuitHabitActive => isQuitHabit && (quitHabitActive ?? true);

  /// Check if quit habit was successfully completed
  bool get isQuitHabitCompleted =>
      isQuitHabit && quitCompletedDate != null && !(quitHabitActive ?? true);

  /// Check if slip uses fixed penalty or per-unit
  bool get isFixedSlipPenalty =>
      slipCalculation == 'fixed' || slipCalculation == null;

  /// Check if streak is protected (has slip buffer)
  bool get hasStreakProtection => (streakProtection ?? 0) > 0;

  /// Check if streak is at risk (close to breaking)
  bool get streakAtRisk {
    if (!hasStreakProtection) return false;
    return (currentSlipCount ?? 0) >= (streakProtection ?? 0);
  }

  /// Check if streak should break on this slip
  bool shouldBreakStreakOnSlip() {
    if (!hasStreakProtection) return true;
    return (currentSlipCount ?? 0) > (streakProtection ?? 0);
  }

  /// Reset slip count (called when streak breaks or is manually reset)
  void resetSlipCount() {
    currentSlipCount = 0;
  }

  /// Calculate slip penalty based on quantity
  /// [quantity] - how many units consumed (e.g., 3 cigarettes)
  int calculateSlipPenalty(int quantity) {
    if (isFixedSlipPenalty) {
      return slipPenalty ?? -20;
    } else {
      // Per unit calculation
      return (penaltyPerUnit ?? -5) * quantity;
    }
  }

  /// Calculate money spent on a slip
  double calculateSlipCost(int quantity) {
    if (costTrackingEnabled != true) return 0;
    return (costPerUnit ?? 0) * quantity;
  }

  /// Format any currency amount using the habit's currency
  String formatCurrency(double amount) {
    final symbol = (currencySymbol ?? '\$').trim();
    if (symbol.isEmpty) return amount.toStringAsFixed(2);
    final needsSpace =
        symbol.length > 1 && RegExp(r'[A-Za-z0-9]$').hasMatch(symbol);
    return needsSpace
        ? '$symbol ${amount.toStringAsFixed(2)}'
        : '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Get daily reward points for resisting
  int get effectiveDailyReward => dailyReward ?? 10;

  /// Get formatted money saved
  String get moneySavedFormatted {
    final saved = moneySaved ?? 0;
    if (saved == 0) return formatCurrency(0);
    return formatCurrency(saved);
  }

  /// Get a descriptive string for the quit habit (e.g., "Drink Alcohol" or just "Drink")
  String get quitHabitDescription {
    if (!isQuitHabit) return '';
    final action = quitActionName ?? 'Quit';
    final substance = quitSubstance;
    if (substance != null && substance.isNotEmpty) {
      return '$action $substance';
    }
    return action;
  }

  /// Get a string for reporting avoided units (e.g., "15 glasses of Alcohol")
  String getAvoidedUnitsDescription(int avoidedCount, String unitName) {
    final substance = quitSubstance;
    if (substance != null && substance.isNotEmpty) {
      return '$avoidedCount $unitName of $substance';
    }
    return '$avoidedCount $unitName';
  }

  /// Get completion type enum from stored string
  HabitCompletionType get completionTypeEnum {
    switch (completionType) {
      case 'numeric':
        return HabitCompletionType.numeric;
      case 'timer':
        return HabitCompletionType.timer;
      case 'checklist':
        return HabitCompletionType.checklist;
      case 'quit':
        return HabitCompletionType.quit;
      case 'yesNo':
      default:
        return HabitCompletionType.yesNo;
    }
  }

  /// Get human-readable completion type description
  String get completionTypeDescription {
    switch (completionTypeEnum) {
      case HabitCompletionType.yesNo:
        return 'Yes or No';
      case HabitCompletionType.numeric:
        return 'Numeric Value';
      case HabitCompletionType.timer:
        return 'Timer';
      case HabitCompletionType.checklist:
        return 'Checklist';
      case HabitCompletionType.quit:
        return 'Quit Bad Habit';
    }
  }

  // ============ Numeric Helpers ============

  /// Check if this is a numeric habit type
  bool get isNumeric => completionTypeEnum == HabitCompletionType.numeric;

  /// Check if this is a timer habit type
  bool get isTimer => completionTypeEnum == HabitCompletionType.timer;

  /// Get the display unit for numeric habits
  String get numericUnit => (customUnitName ?? unit ?? '').trim();

  /// Format a numeric value with the habit unit
  String formatNumericValue(double value) {
    final unitLabel = numericUnit;
    final hasFraction = value.truncateToDouble() != value;
    final formatted = value.toStringAsFixed(hasFraction ? 1 : 0);
    return unitLabel.isEmpty ? formatted : '$formatted $unitLabel';
  }

  /// Calculate completion ratio (0.0 to 1.0+)
  double calculateNumericCompletionRatio(double actualValue) {
    final target = targetValue ?? 0.0;
    if (target <= 0) {
      return actualValue > 0 ? 1.0 : 0.0;
    }
    return actualValue / target;
  }

  /// Calculate completion percentage as display string
  String calculateNumericCompletionPercent(double actualValue) {
    final ratio = calculateNumericCompletionRatio(actualValue);
    return '${(ratio * 100).toStringAsFixed(1)}%';
  }

  /// Calculate points for numeric completion based on pointCalculation
  int calculateNumericPoints(double actualValue) {
    final target = targetValue ?? 0.0;
    final basePoints = customYesPoints ?? 0;
    final safeActual = actualValue < 0 ? 0.0 : actualValue;

    if (target <= 0) {
      return safeActual > 0 ? basePoints : 0;
    }

    switch (pointCalculation) {
      case 'allOrNothing':
        return safeActual >= target ? basePoints : 0;
      case 'proportional':
        final ratio = (safeActual / target).clamp(0.0, 1.0);
        return (ratio * basePoints).round();
      case 'perUnit':
        return (safeActual * (pointsPerUnit ?? 0)).round();
      case 'threshold':
        final thresholdValue = target * ((thresholdPercent ?? 100) / 100);
        return safeActual >= thresholdValue ? basePoints : 0;
      default:
        return safeActual >= target ? basePoints : 0;
    }
  }

  // ============ Timer Helpers ============

  /// Check if this is a target-based timer (must reach goal)
  bool get isTargetTimer => timerType == 'target' || timerType == null;

  /// Check if this is a minimum-based timer (can exceed for bonus)
  bool get isMinimumTimer => timerType == 'minimum';

  /// Get the effective time unit (defaults to 'minute')
  String get effectiveTimeUnit => timeUnit ?? 'minute';

  /// Get target duration in the specified time unit for display
  /// e.g., if target is 60 minutes and unit is 'hour', returns 1.0
  double get targetDurationInUnit {
    if (targetDurationMinutes == null) return 0;
    return TimeUtils.fromMinutes(
      targetDurationMinutes!.toDouble(),
      effectiveTimeUnit,
    );
  }

  /// Set target duration from a value in the current time unit
  /// e.g., setTargetFromUnit(1.5, 'hour') sets targetDurationMinutes to 90
  void setTargetFromUnit(double value, String unit) {
    targetDurationMinutes = TimeUtils.toMinutes(value, unit).round();
    timeUnit = unit;
  }

  /// Format any minutes value for display (e.g., "2h 30m" or "1hr 45min")
  String formatDuration(int minutes, {bool compact = true}) {
    return TimeUtils.formatMinutes(minutes, compact: compact);
  }

  /// Get formatted target duration in user-friendly format
  String get targetDurationFormatted {
    if (targetDurationMinutes == null) return 'No target';
    // Show in the user's preferred unit
    final valueInUnit = targetDurationInUnit;
    return TimeUtils.formatTarget(valueInUnit, effectiveTimeUnit);
  }

  /// Get target as compact string (e.g., "1h" or "30m")
  String get targetDurationCompact {
    if (targetDurationMinutes == null) return '-';
    return TimeUtils.formatMinutes(targetDurationMinutes!, compact: true);
  }

  // Checklist Helpers

  /// Check if this habit has subtasks
  bool get hasSubtasks => checklist != null && checklist!.isNotEmpty;

  /// Get completion percentage of checklist items
  double get checklistProgress {
    if (!hasSubtasks) return 0.0;
    final completed = checklist!.where((s) => s.isCompleted).length;
    return completed / checklist!.length;
  }

  /// Check if all checklist items are completed
  bool get isChecklistFullyCompleted {
    if (!hasSubtasks) return true;
    return checklist!.every((s) => s.isCompleted);
  }

  /// Get checklist progress as display string
  String get checklistProgressPercent {
    final progress = checklistProgress;
    return '${(progress * 100).toStringAsFixed(0)}%';
  }

  /// Get checklist items count string (e.g. "2/5")
  String get checklistCountString {
    if (!hasSubtasks) return '0/0';
    final completed = checklist!.where((s) => s.isCompleted).length;
    return '$completed/${checklist!.length}';
  }

  /// Check if habit can be marked as done (all checklist items must be done)
  bool get canMarkAsDone {
    return isChecklistFullyCompleted;
  }

  /// Calculate points for checklist completion (bonus points if checklist exists)
  double calculateChecklistPoints() {
    if (!hasSubtasks) return 0;

    final basePoints = (customYesPoints ?? 10).toDouble();
    final progress = checklistProgress;

    // Proportional reward based on checklist progress
    return basePoints * progress;
  }

  /// Calculate completion percentage from actual minutes
  /// Returns 0.0 to 1.0+ (can exceed 1.0 if overtime)
  double calculateCompletionRatio(int actualMinutes) {
    if (targetDurationMinutes == null || targetDurationMinutes == 0) return 0;
    return actualMinutes / targetDurationMinutes!;
  }

  /// Calculate completion percentage as display string
  /// e.g., "62.5%" or "125%"
  String calculateCompletionPercent(int actualMinutes) {
    final ratio = calculateCompletionRatio(actualMinutes);
    return '${(ratio * 100).toStringAsFixed(1)}%';
  }

  /// Calculate points for timer completion
  ///
  /// [actualMinutes] - actual time spent IN MINUTES (always minutes internally)
  /// Returns calculated points based on timer type and settings
  ///
  /// Example: Goal = 1 hour, Actual = 10 min
  /// - targetDurationMinutes = 60
  /// - actualMinutes = 10
  /// - ratio = 10/60 = 16.67%
  /// - points = basePoints * 0.1667 = 1.67 (if base is 10)
  double calculateTimerPoints(int actualMinutes) {
    if (targetDurationMinutes == null || targetDurationMinutes == 0) return 0;

    final basePoints = (customYesPoints ?? 10).toDouble();
    final noPoints = (customNoPoints ?? -10).toDouble();
    final target = targetDurationMinutes!;

    if (actualMinutes == 0) {
      return noPoints;
    }

    if (isMinimumTimer) {
      // Minimum type: full points at minimum, bonus for extra
      if (actualMinutes >= target) {
        // Reached minimum - get base points
        double points = basePoints;
        // Add bonus for extra time
        final extraMinutes = actualMinutes - target;
        if (extraMinutes > 0 && bonusPerMinute != null && bonusPerMinute! > 0) {
          points += extraMinutes * bonusPerMinute!;
        }
        return points;
      } else {
        // Did not reach minimum - proportional points
        final ratio = actualMinutes / target;
        return basePoints * ratio;
      }
    } else {
      // Target type: proportional to completion
      final ratio = actualMinutes / target;
      if (ratio >= 1.0) {
        // Met or exceeded target
        double points = basePoints;
        // Add overtime bonus if enabled
        if (allowOvertimeBonus == true && actualMinutes > target) {
          final extraMinutes = actualMinutes - target;
          final bonus = bonusPerMinute ?? 0.1;
          points += extraMinutes * bonus;
        }
        return points;
      } else {
        // Partial completion
        return basePoints * ratio;
      }
    }
  }

  /// Calculate points from a value in the user's preferred unit
  /// This converts to minutes first, then calculates
  ///
  /// Example: Goal = 1 hour, User enters "10" with unit "minute"
  /// - Converts 10 minutes to actualMinutes = 10
  /// - Calculates: 10/60 = 16.67% of base points
  double calculateTimerPointsFromUnit(double actualValue, String unit) {
    final actualMinutes = TimeUtils.toMinutes(actualValue, unit).round();
    return calculateTimerPoints(actualMinutes);
  }

  /// Get a summary of expected points for different completion levels
  /// Useful for showing in UI what user will earn
  Map<String, double> getPointsPreview() {
    final target = targetDurationMinutes ?? 60;
    return {
      '0%': calculateTimerPoints(0),
      '25%': calculateTimerPoints((target * 0.25).round()),
      '50%': calculateTimerPoints((target * 0.5).round()),
      '75%': calculateTimerPoints((target * 0.75).round()),
      '100%': calculateTimerPoints(target),
      '150%': calculateTimerPoints((target * 1.5).round()),
    };
  }

  // ============ Cross-App Integration Helpers ============

  /// Export habit as a lightweight JSON map for Time Manager import
  /// Only includes scheduling and essential info, not tracking data
  Map<String, dynamic> toTimeManagerEvent({
    required DateTime eventDate,
    TimeOfDay? startTime,
    Duration? duration,
  }) {
    return {
      'sourceApp': 'habits',
      'sourceId': id,
      'title': title,
      'description': description,
      'category': categoryId,
      'date': eventDate.toIso8601String(),
      'startTime': startTime != null
          ? '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'
          : null,
      'duration': duration?.inMinutes ?? targetDurationMinutes,
      'color': colorValue,
      'icon': iconCodePoint,
      'isHabit': true,
      'habitType': completionType,
      'recurrenceRule': recurrenceRuleJson,
    };
  }

  /// Generate scheduled events for a date range (for week planner)
  /// Returns list of event maps that can be imported into Time Manager
  List<Map<String, dynamic>> generateScheduledEvents({
    required DateTime startDate,
    required DateTime endDate,
    TimeOfDay? defaultStartTime,
    Duration? defaultDuration,
  }) {
    final dueDates = getDueDatesInRange(startDate, endDate);
    return dueDates
        .map(
          (date) => toTimeManagerEvent(
            eventDate: date,
            startTime: defaultStartTime ?? reminderTime,
            duration:
                defaultDuration ??
                (targetDurationMinutes != null
                    ? Duration(minutes: targetDurationMinutes!)
                    : null),
          ),
        )
        .toList();
  }

  /// Export habit to JSON for backup/sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'iconFontPackage': iconFontPackage,
      'colorValue': colorValue,
      'categoryId': categoryId,
      'frequencyType': frequencyType,
      'weekDays': weekDays,
      'targetCount': targetCount,
      'customIntervalDays': customIntervalDays,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'totalCompletions': totalCompletions,
      'reminderMinutes': reminderMinutes,
      'reminderEnabled': reminderEnabled,
      'notes': notes,
      'isGoodHabit': isGoodHabit,
      'isArchived': isArchived,
      'isSpecial': isSpecial,
      'createdAt': createdAt.toIso8601String(),
      'archivedAt': archivedAt?.toIso8601String(),
      'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'tags': tags,
      'completionType': completionType,
      'targetValue': targetValue,
      'unit': unit,
      'targetDurationMinutes': targetDurationMinutes,
      'customYesPoints': customYesPoints,
      'customNoPoints': customNoPoints,
      'customPostponePoints': customPostponePoints,
      'recurrenceRuleJson': recurrenceRuleJson,
      'reminderDuration': reminderDuration,
      'motivation': motivation,
      'hasSpecificTime': hasSpecificTime,
      'habitTimeMinutes': habitTimeMinutes,
      'goalType': goalType,
      'goalTarget': goalTarget,
      'goalStartDate': goalStartDate?.toIso8601String(),
      'goalCompletedDate': goalCompletedDate?.toIso8601String(),
      'habitStatus': habitStatus,
      'statusChangedDate': statusChangedDate?.toIso8601String(),
      'pausedUntil': pausedUntil?.toIso8601String(),
      'frequencyPeriod': frequencyPeriod,
      'endCondition': endCondition,
      'endOccurrences': endOccurrences,
      // Quit habit fields
      'quitActionName': quitActionName,
      'quitSubstance': quitSubstance,
      'hideQuitHabit': hideQuitHabit,
      'dailyReward': dailyReward,
      'slipPenalty': slipPenalty,
      'slipCalculation': slipCalculation,
      'penaltyPerUnit': penaltyPerUnit,
      'streakProtection': streakProtection,
      'costPerUnit': costPerUnit,
      'costTrackingEnabled': costTrackingEnabled,
      'currencySymbol': currencySymbol,
      'enableTemptationTracking': enableTemptationTracking,
      'moneySaved': moneySaved,
      'unitsAvoided': unitsAvoided,
      'quitHabitActive': quitHabitActive,
      'quitCompletedDate': quitCompletedDate?.toIso8601String(),
    };
  }

  /// Create habit from JSON (for restore/sync)
  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      iconCodePoint: json['iconCodePoint'] as int?,
      iconFontFamily: json['iconFontFamily'] as String?,
      iconFontPackage: json['iconFontPackage'] as String?,
      colorValue: json['colorValue'] as int?,
      categoryId: json['categoryId'] as String?,
      frequencyType: json['frequencyType'] as String? ?? 'daily',
      weekDays: (json['weekDays'] as List?)?.cast<int>(),
      targetCount: json['targetCount'] as int? ?? 1,
      customIntervalDays: json['customIntervalDays'] as int?,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      totalCompletions: json['totalCompletions'] as int? ?? 0,
      reminderMinutes: json['reminderMinutes'] as int?,
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      notes: json['notes'] as String?,
      isGoodHabit: json['isGoodHabit'] as bool? ?? true,
      isArchived: json['isArchived'] as bool? ?? false,
      isSpecial: json['isSpecial'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      archivedAt: json['archivedAt'] != null
          ? DateTime.parse(json['archivedAt'] as String)
          : null,
      lastCompletedAt: json['lastCompletedAt'] != null
          ? DateTime.parse(json['lastCompletedAt'] as String)
          : null,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      tags: (json['tags'] as List?)?.cast<String>(),
      completionType: (json['completionType'] as String?) ?? 'yesNo',
      targetValue: (json['targetValue'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      targetDurationMinutes: json['targetDurationMinutes'] as int?,
      customYesPoints: json['customYesPoints'] as int?,
      customNoPoints: json['customNoPoints'] as int?,
      customPostponePoints: json['customPostponePoints'] as int?,
      recurrenceRuleJson: json['recurrenceRuleJson'] as String?,
      reminderDuration: json['reminderDuration'] as String?,
      motivation: json['motivation'] as String?,
      hasSpecificTime: json['hasSpecificTime'] as bool? ?? false,
      habitTimeMinutes: json['habitTimeMinutes'] as int?,
      goalType: json['goalType'] as String?,
      goalTarget: json['goalTarget'] as int?,
      goalStartDate: json['goalStartDate'] != null
          ? DateTime.parse(json['goalStartDate'] as String)
          : null,
      goalCompletedDate: json['goalCompletedDate'] != null
          ? DateTime.parse(json['goalCompletedDate'] as String)
          : null,
      habitStatus: json['habitStatus'] as String? ?? 'active',
      statusChangedDate: json['statusChangedDate'] != null
          ? DateTime.parse(json['statusChangedDate'] as String)
          : null,
      pausedUntil: json['pausedUntil'] != null
          ? DateTime.parse(json['pausedUntil'] as String)
          : null,
      frequencyPeriod: json['frequencyPeriod'] as String?,
      endCondition: json['endCondition'] as String?,
      endOccurrences: json['endOccurrences'] as int?,
      quitActionName: json['quitActionName'] as String?,
      quitSubstance: json['quitSubstance'] as String?,
      hideQuitHabit: json['hideQuitHabit'] as bool? ?? true,
      dailyReward: json['dailyReward'] as int?,
      slipPenalty: json['slipPenalty'] as int?,
      slipCalculation: json['slipCalculation'] as String?,
      penaltyPerUnit: json['penaltyPerUnit'] as int?,
      streakProtection: json['streakProtection'] as int?,
      costPerUnit: (json['costPerUnit'] as num?)?.toDouble(),
      costTrackingEnabled: json['costTrackingEnabled'] as bool?,
      currencySymbol: json['currencySymbol'] as String?,
      enableTemptationTracking: json['enableTemptationTracking'] as bool?,
      moneySaved: (json['moneySaved'] as num?)?.toDouble(),
      unitsAvoided: json['unitsAvoided'] as int?,
      quitHabitActive: json['quitHabitActive'] as bool?,
      quitCompletedDate: json['quitCompletedDate'] != null
          ? DateTime.parse(json['quitCompletedDate'] as String)
          : null,
    );
  }

  /// Get compact summary for reports
  Map<String, dynamic> getReportSummary() {
    return {
      'id': id,
      'title': title,
      'type': completionType ?? 'yesNo',
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'totalCompletions': totalCompletions,
      'completionRate': _calculateCompletionRate(),
      'isActive':
          !isArchived && (completionType != 'quit' || isQuitHabitActive),
      'frequency': frequencyDescription,
      'nextDue': nextDueDate?.toIso8601String(),
      'isSpecial': isSpecial,
    };
  }

  double _calculateCompletionRate() {
    if (recurrence == null) return 0.0;
    final period = getCurrentPeriod();
    final expectedInPeriod = recurrence!.countOccurrencesInRange(
      period['start']!,
      period['end']!,
    );
    if (expectedInPeriod == 0) return 0.0;
    // This would need completion data; simplified for now
    return totalCompletions > 0 ? 1.0 : 0.0;
  }
}
