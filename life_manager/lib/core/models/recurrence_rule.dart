import 'dart:convert';

/// Professional recurrence rule model supporting all common patterns
/// 
/// Supports:
/// - Basic: Daily, Weekly, Monthly, Yearly
/// - Specific days of week (e.g., every Monday and Wednesday)
/// - Specific days of month (e.g., 1st and 15th of every month)
/// - Specific dates of year (e.g., January 1st every year)
/// - Interval-based (e.g., every 3 days, every 2 weeks)
class RecurrenceRule {
  /// Type of recurrence: 'daily', 'weekly', 'monthly', 'yearly', 'custom'
  final String type;

  /// Interval: repeat every X units (e.g., every 2 weeks = interval: 2)
  final int interval;

  /// For weekly: specific days of week (0=Sunday, 1=Monday, ..., 6=Saturday)
  /// Example: [1, 3, 5] = Monday, Wednesday, Friday
  final List<int>? daysOfWeek;

  /// For monthly: specific days of month (1-31)
  /// Example: [1, 15] = 1st and 15th of every month
  final List<int>? daysOfMonth;

  /// For yearly: specific month and day
  /// Example: {month: 1, day: 1} = January 1st every year
  final Map<String, int>? dayOfYear;

  /// Start date for recurrence
  final DateTime startDate;

  /// End condition: 'never', 'on_date', 'after_occurrences'
  final String endCondition;

  /// End date (if endCondition is 'on_date')
  final DateTime? endDate;

  /// Unit for custom recurrence: 'days', 'weeks', 'months', 'years'
  final String? unit;

  /// Number of occurrences (if endCondition is 'after_occurrences')
  final int? occurrences;

  /// Skip weekends (Saturday and Sunday)
  final bool skipWeekends;

  /// Frequency: how many times per interval (e.g., 2 times per day)
  final int frequency;

  RecurrenceRule({
    required this.type,
    this.interval = 1,
    this.daysOfWeek,
    this.daysOfMonth,
    this.dayOfYear,
    required this.startDate,
    this.endCondition = 'never',
    this.endDate,
    this.unit,
    this.occurrences,
    this.skipWeekends = false,
    this.frequency = 1,
  });

  /// Create a daily recurrence
  factory RecurrenceRule.daily({
    required DateTime startDate,
    int interval = 1,
    String endCondition = 'never',
    DateTime? endDate,
    int? occurrences,
    bool skipWeekends = false,
    int frequency = 1,
  }) {
    return RecurrenceRule(
      type: 'daily',
      interval: interval,
      startDate: startDate,
      endCondition: endCondition,
      endDate: endDate,
      occurrences: occurrences,
      skipWeekends: skipWeekends,
      frequency: frequency,
    );
  }

  /// Create a weekly recurrence
  factory RecurrenceRule.weekly({
    required DateTime startDate,
    List<int>? daysOfWeek,
    int interval = 1,
    String endCondition = 'never',
    DateTime? endDate,
    int? occurrences,
    int frequency = 1,
  }) {
    return RecurrenceRule(
      type: 'weekly',
      interval: interval,
      daysOfWeek: daysOfWeek ?? [startDate.weekday % 7], // Default to start date's day
      startDate: startDate,
      endCondition: endCondition,
      endDate: endDate,
      occurrences: occurrences,
      frequency: frequency,
    );
  }

  /// Create a monthly recurrence
  factory RecurrenceRule.monthly({
    required DateTime startDate,
    List<int>? daysOfMonth,
    int interval = 1,
    String endCondition = 'never',
    DateTime? endDate,
    int? occurrences,
    int frequency = 1,
  }) {
    return RecurrenceRule(
      type: 'monthly',
      interval: interval,
      daysOfMonth: daysOfMonth ?? [startDate.day], // Default to start date's day
      startDate: startDate,
      endCondition: endCondition,
      endDate: endDate,
      occurrences: occurrences,
      frequency: frequency,
    );
  }

  /// Create a yearly recurrence
  factory RecurrenceRule.yearly({
    required DateTime startDate,
    Map<String, int>? dayOfYear,
    int interval = 1,
    String endCondition = 'never',
    DateTime? endDate,
    int? occurrences,
    int frequency = 1,
  }) {
    return RecurrenceRule(
      type: 'yearly',
      interval: interval,
      dayOfYear: dayOfYear ?? {'month': startDate.month, 'day': startDate.day},
      startDate: startDate,
      endCondition: endCondition,
      endDate: endDate,
      occurrences: occurrences,
      frequency: frequency,
    );
  }

  /// Create a custom interval-based recurrence
  factory RecurrenceRule.custom({
    required DateTime startDate,
    required int interval,
    required String unit, // 'days', 'weeks', 'months'
    String endCondition = 'never',
    DateTime? endDate,
    int? occurrences,
    bool skipWeekends = false,
    int frequency = 1,
  }) {
    return RecurrenceRule(
      type: 'custom',
      interval: interval,
      unit: unit,
      startDate: startDate,
      endCondition: endCondition,
      endDate: endDate,
      occurrences: occurrences,
      skipWeekends: skipWeekends,
      frequency: frequency,
    );
  }

  /// Convert to JSON string for storage
  String toJson() {
    return jsonEncode({
      'type': type,
      'interval': interval,
      'daysOfWeek': daysOfWeek,
      'daysOfMonth': daysOfMonth,
      'dayOfYear': dayOfYear,
      'startDate': startDate.toIso8601String(),
      'endCondition': endCondition,
      'endDate': endDate?.toIso8601String(),
      'unit': unit,
      'occurrences': occurrences,
      'skipWeekends': skipWeekends,
      'frequency': frequency,
    });
  }

  /// Create from JSON string
  factory RecurrenceRule.fromJson(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return RecurrenceRule(
      type: map['type'] as String,
      interval: map['interval'] as int? ?? 1,
      daysOfWeek: map['daysOfWeek'] != null
          ? List<int>.from(map['daysOfWeek'] as List)
          : null,
      daysOfMonth: map['daysOfMonth'] != null
          ? List<int>.from(map['daysOfMonth'] as List)
          : null,
      dayOfYear: map['dayOfYear'] != null
          ? Map<String, int>.from(map['dayOfYear'] as Map)
          : null,
      startDate: DateTime.parse(map['startDate'] as String),
      endCondition: map['endCondition'] as String? ?? 'never',
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      unit: map['unit'] as String?,
      occurrences: map['occurrences'] as int?,
      skipWeekends: map['skipWeekends'] as bool? ?? false,
      frequency: map['frequency'] as int? ?? 1,
    );
  }

  /// Get human-readable description
  String getDescription() {
    String freqText = frequency > 1 ? '$frequency times ' : '';
    String perText = frequency > 1 ? 'per ' : '';

    switch (type) {
      case 'daily':
        if (interval == 1) {
          return frequency > 1 ? '$frequency times daily' : 'Daily';
        }
        return '${freqText}${perText}every $interval days';
      case 'weekly':
        if (daysOfWeek != null && daysOfWeek!.length == 1) {
          final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
          final dayName = dayNames[daysOfWeek!.first];
          if (interval == 1) {
            return frequency > 1 ? '$frequency times every $dayName' : 'Every $dayName';
          }
          return '${freqText}${perText}every $interval weeks on $dayName';
        } else if (daysOfWeek != null && daysOfWeek!.isNotEmpty) {
          final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
          final selectedDays = daysOfWeek!.map((d) => dayNames[d]).join(', ');
          if (interval == 1) {
            return frequency > 1 ? '$frequency times weekly on $selectedDays' : 'Weekly on $selectedDays';
          }
          return '${freqText}${perText}every $interval weeks on $selectedDays';
        }
        return frequency > 1 
            ? '$frequency times every ${interval == 1 ? '' : '$interval '}weeks'
            : (interval == 1 ? 'Weekly' : 'Every $interval weeks');
      case 'monthly':
        if (daysOfMonth != null && daysOfMonth!.length == 1) {
          final day = daysOfMonth!.first;
          final suffix = _getDaySuffix(day);
          if (interval == 1) {
            return frequency > 1 ? '$frequency times monthly on the ${day}$suffix' : 'Monthly on the ${day}$suffix';
          }
          return '${freqText}${perText}every $interval months on the ${day}$suffix';
        } else if (daysOfMonth != null && daysOfMonth!.isNotEmpty) {
          final days = daysOfMonth!.map((d) => '${d}${_getDaySuffix(d)}').join(', ');
          if (interval == 1) {
            return frequency > 1 ? '$frequency times monthly on the $days' : 'Monthly on the $days';
          }
          return '${freqText}${perText}every $interval months on the $days';
        }
        return frequency > 1 
            ? '$frequency times every ${interval == 1 ? '' : '$interval '}months'
            : (interval == 1 ? 'Monthly' : 'Every $interval months');
      case 'yearly':
        if (dayOfYear != null) {
          final month = dayOfYear!['month']!;
          final day = dayOfYear!['day']!;
          final monthNames = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
          ];
          if (interval == 1) {
            return frequency > 1 
                ? '$frequency times yearly on ${monthNames[month - 1]} ${day}${_getDaySuffix(day)}' 
                : 'Yearly on ${monthNames[month - 1]} ${day}${_getDaySuffix(day)}';
          }
          return '${freqText}${perText}every $interval years on ${monthNames[month - 1]} ${day}${_getDaySuffix(day)}';
        }
        return frequency > 1 
            ? '$frequency times every ${interval == 1 ? '' : '$interval '}years'
            : (interval == 1 ? 'Yearly' : 'Every $interval years');
      case 'custom':
        final displayUnit = unit ?? 'units';
        // Capitalize first letter and handle pluralization properly
        String unitName;
        if (displayUnit == 'days') {
          unitName = interval == 1 ? 'day' : 'days';
        } else if (displayUnit == 'weeks') {
          unitName = interval == 1 ? 'week' : 'weeks';
        } else if (displayUnit == 'months') {
          unitName = interval == 1 ? 'month' : 'months';
        } else if (displayUnit == 'years') {
          unitName = interval == 1 ? 'year' : 'years';
        } else {
          // Fallback for unknown units
          unitName = displayUnit;
        }
        return frequency > 1 
            ? '$frequency times every $interval $unitName'
            : 'Every $interval $unitName';
      default:
        return 'Unknown';
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  /// Check if recurrence has ended
  bool hasEnded(DateTime currentDate) {
    switch (endCondition) {
      case 'on_date':
        return endDate != null && currentDate.isAfter(endDate!);
      case 'after_occurrences':
        // This needs to be checked by the engine counting occurrences
        return false;
      case 'never':
      default:
        return false;
    }
  }

  /// Check if the recurrence is due on a specific date
  bool isDueOn(DateTime date) {
    // Check if date is before start
    if (date.isBefore(DateTime(startDate.year, startDate.month, startDate.day))) {
      return false;
    }

    // Check if ended
    if (hasEnded(date)) return false;

    switch (type) {
      case 'daily':
        final daysDiff = date.difference(DateTime(startDate.year, startDate.month, startDate.day)).inDays;
        if (daysDiff % interval != 0) return false;
        if (skipWeekends && (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)) {
          return false;
        }
        return true;

      case 'weekly':
        if (daysOfWeek == null || daysOfWeek!.isEmpty) return false;
        final weekday = date.weekday % 7; // 0 = Sunday
        if (!daysOfWeek!.contains(weekday)) return false;
        // Check interval (every N weeks)
        final weeksDiff = (date.difference(startDate).inDays / 7).floor();
        return weeksDiff % interval == 0;

      case 'monthly':
        if (daysOfMonth == null || daysOfMonth!.isEmpty) return false;
        if (!daysOfMonth!.contains(date.day)) return false;
        // Check interval (every N months)
        final monthsDiff = (date.year - startDate.year) * 12 + (date.month - startDate.month);
        return monthsDiff % interval == 0;

      case 'yearly':
        if (dayOfYear == null) return false;
        if (date.month != dayOfYear!['month'] || date.day != dayOfYear!['day']) return false;
        // Check interval (every N years)
        final yearsDiff = date.year - startDate.year;
        return yearsDiff % interval == 0;

      case 'custom':
        if (unit == null) return false;
        int diff;
        switch (unit) {
          case 'days':
            diff = date.difference(DateTime(startDate.year, startDate.month, startDate.day)).inDays;
            break;
          case 'weeks':
            diff = (date.difference(startDate).inDays / 7).floor();
            break;
          case 'months':
            diff = (date.year - startDate.year) * 12 + (date.month - startDate.month);
            break;
          default:
            return false;
        }
        if (diff % interval != 0) return false;
        if (skipWeekends && (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)) {
          return false;
        }
        return true;

      default:
        return false;
    }
  }

  /// Get the next occurrence after a given date
  DateTime? getNextOccurrence(DateTime after) {
    DateTime check = DateTime(after.year, after.month, after.day).add(const Duration(days: 1));
    int maxIterations = 400; // Prevent infinite loops (covers > 1 year)

    for (int i = 0; i < maxIterations; i++) {
      if (isDueOn(check)) return check;
      if (hasEnded(check)) return null;
      check = check.add(const Duration(days: 1));
    }
    return null;
  }

  /// Get the next N occurrences after a given date
  List<DateTime> getNextOccurrences(DateTime after, int count) {
    final results = <DateTime>[];
    DateTime? current = after;

    for (int i = 0; i < count && current != null; i++) {
      current = getNextOccurrence(current);
      if (current != null) {
        results.add(current);
      }
    }
    return results;
  }

  /// Get all occurrences within a date range
  List<DateTime> getOccurrencesInRange(DateTime start, DateTime end) {
    final results = <DateTime>[];
    DateTime check = DateTime(start.year, start.month, start.day);
    
    while (!check.isAfter(end)) {
      if (isDueOn(check)) {
        results.add(check);
      }
      check = check.add(const Duration(days: 1));
    }
    return results;
  }

  /// Count occurrences within a date range
  int countOccurrencesInRange(DateTime start, DateTime end) {
    return getOccurrencesInRange(start, end).length;
  }

  /// Get the current period boundaries (for quota tracking)
  /// Returns a map with 'start' and 'end' dates for the current period
  Map<String, DateTime> getCurrentPeriod(DateTime referenceDate) {
    DateTime periodStart;
    DateTime periodEnd;

    switch (type) {
      case 'daily':
        periodStart = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
        periodEnd = periodStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        break;
      case 'weekly':
        // Week starts on Sunday (weekday % 7 = 0)
        final daysSinceSunday = referenceDate.weekday % 7;
        periodStart = DateTime(referenceDate.year, referenceDate.month, referenceDate.day)
            .subtract(Duration(days: daysSinceSunday));
        periodEnd = periodStart.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
        break;
      case 'monthly':
        periodStart = DateTime(referenceDate.year, referenceDate.month, 1);
        periodEnd = DateTime(referenceDate.year, referenceDate.month + 1, 1)
            .subtract(const Duration(seconds: 1));
        break;
      case 'yearly':
        periodStart = DateTime(referenceDate.year, 1, 1);
        periodEnd = DateTime(referenceDate.year + 1, 1, 1).subtract(const Duration(seconds: 1));
        break;
      default:
        periodStart = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
        periodEnd = periodStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    }

    return {'start': periodStart, 'end': periodEnd};
  }

  @override
  String toString() => getDescription();
}

