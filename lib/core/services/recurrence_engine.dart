import '../models/recurrence_rule.dart';

/// Service for generating recurring task instances based on recurrence rules
class RecurrenceEngine {
  /// Generate the next occurrence date(s) based on the recurrence rule
  /// 
  /// Returns a list of DateTime instances representing the next occurrences
  /// up to the specified limit or end condition
  /// 
  /// FIXED: Uses rule.isDueOn() to properly validate each date against the
  /// recurrence rule (e.g., only Tuesday/Wednesday for weekly rules)
  static List<DateTime> generateNextOccurrences(
    RecurrenceRule rule,
    DateTime fromDate, {
    int maxOccurrences = 100,
  }) {
    final occurrences = <DateTime>[];
    int generatedCount = 0;
    
    // Start from the later of fromDate or rule's startDate
    DateTime checkDate = fromDate.isBefore(rule.startDate) ? rule.startDate : fromDate;
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day); // Normalize to start of day
    
    // Track dates we've already added to avoid duplicates
    final addedDates = <String>{};
    
    // Iterate through dates looking for valid occurrences
    // Use a reasonable limit to prevent infinite loops (1 year max scan)
    int daysChecked = 0;
    const maxDaysToCheck = 400; // About 1 year + buffer
    
    while (generatedCount < maxOccurrences && daysChecked < maxDaysToCheck) {
      // Check end conditions
      if (rule.hasEnded(checkDate)) {
        break;
      }

      if (rule.endCondition == 'after_occurrences' &&
          rule.occurrences != null &&
          generatedCount >= rule.occurrences!) {
        break;
      }
      
      // Use the rule's isDueOn method to check if this date is a valid occurrence
      // This properly handles:
      // - Weekly rules with specific days (Tue, Wed)
      // - Monthly rules with specific days (1st, 15th)
      // - Interval-based rules (every 2 weeks)
      if (rule.isDueOn(checkDate)) {
        // Skip weekends if enabled
        if (rule.skipWeekends && _isWeekend(checkDate)) {
          checkDate = checkDate.add(const Duration(days: 1));
          daysChecked++;
          continue;
        }
        
        // Create a unique key for this date
        final dateKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
        
        // Only add if not already added
        if (!addedDates.contains(dateKey)) {
          addedDates.add(dateKey);
          
          // Add occurrence (with frequency support)
          for (int f = 0; f < rule.frequency; f++) {
            occurrences.add(checkDate);
            generatedCount++;
            if (generatedCount >= maxOccurrences) break;
          }
        }
      }
      
      // Move to next day
      checkDate = checkDate.add(const Duration(days: 1));
      daysChecked++;
    }

    return occurrences;
  }

  /// Get the next daily occurrence
  static DateTime? _getNextDailyDate(RecurrenceRule rule, DateTime fromDate) {
    if (fromDate.isBefore(rule.startDate)) {
      return rule.startDate;
    }

    // Calculate days since start
    final daysSinceStart = fromDate.difference(rule.startDate).inDays;
    
    // Find next occurrence based on interval
    final nextOccurrenceDays = ((daysSinceStart ~/ rule.interval) + 1) * rule.interval;
    final nextDate = rule.startDate.add(Duration(days: nextOccurrenceDays));

    return nextDate;
  }

  /// Find next occurrence of a specific day of week
  static DateTime? _findNextDayOfWeek(
    DateTime fromDate,
    int dayOfWeek,
    int interval,
  ) {
    // dayOfWeek: 0=Sunday, 1=Monday, ..., 6=Saturday
    final currentDayOfWeek = fromDate.weekday % 7;
    
    int daysUntilNext;
    if (dayOfWeek >= currentDayOfWeek) {
      daysUntilNext = dayOfWeek - currentDayOfWeek;
    } else {
      daysUntilNext = 7 - currentDayOfWeek + dayOfWeek;
    }

    // If it's today and we're looking for the next occurrence, move to next week
    if (daysUntilNext == 0) {
      daysUntilNext = 7 * interval;
    } else if (interval > 1) {
      // For intervals > 1, we need to find the right week
      // This is simplified - for proper interval support, we'd need to track weeks
      daysUntilNext = daysUntilNext + (interval - 1) * 7;
    }

    return fromDate.add(Duration(days: daysUntilNext));
  }

  /// Find next occurrence of a specific day of month
  static DateTime? _findNextDayOfMonth(
    DateTime fromDate,
    int dayOfMonth,
    int interval,
  ) {
    DateTime candidate = DateTime(fromDate.year, fromDate.month, dayOfMonth);

    // If this month's date has passed, try next month
    if (candidate.isBefore(fromDate)) {
      candidate = DateTime(fromDate.year, fromDate.month + interval, dayOfMonth);
    }

    // Handle months with fewer days (e.g., Feb 30 -> Feb 28/29)
    while (candidate.day != dayOfMonth && candidate.month == fromDate.month + interval) {
      candidate = DateTime(candidate.year, candidate.month, candidate.day - 1);
    }

    // Handle leap years for Feb 29
    if (dayOfMonth == 29 && candidate.month == 2 && !_isLeapYear(candidate.year)) {
      candidate = DateTime(candidate.year, 2, 28);
    }

    return candidate;
  }

  /// Check if date is weekend
  static bool _isWeekend(DateTime date) {
    final dayOfWeek = date.weekday;
    return dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday;
  }

  /// Check if year is leap year
  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Generate a single next occurrence (most common use case)
  static DateTime? getNextOccurrence(RecurrenceRule rule, DateTime fromDate) {
    final occurrences = generateNextOccurrences(rule, fromDate, maxOccurrences: 1);
    return occurrences.isNotEmpty ? occurrences.first : null;
  }
}

