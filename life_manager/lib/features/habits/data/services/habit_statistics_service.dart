import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_statistics.dart';
import '../repositories/habit_repository.dart';

/// Service for calculating detailed habit statistics
class HabitStatisticsService {
  final HabitRepository _repository;

  HabitStatisticsService(this._repository);

  /// Calculate comprehensive statistics for a habit
  Future<HabitStatistics> calculateStatistics(Habit habit) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDateOnly = DateTime(
      habit.startDate.year,
      habit.startDate.month,
      habit.startDate.day,
    );

    // Get all completions for this habit
    final allCompletions = await _repository.getCompletionsForHabit(habit.id);
    
    // Filter out skipped completions for most calculations
    // NOTE: For regular habits, skipped = break. For quit habits, skipped = slip.
    final validCompletions = allCompletions
        .where((c) => !c.isSkipped && !c.isPostponed)
        .toList();

    final skippedDates = allCompletions
        .where((c) => c.isSkipped)
        .map((c) => DateTime(c.completedDate.year, c.completedDate.month, c.completedDate.day))
        .toSet();

    // Time periods
    final weekStart = _getWeekStart(today);
    final monthStart = DateTime(today.year, today.month, 1);
    final yearStart = DateTime(today.year, 1, 1);

    // COMPLETION COUNTING LOGIC
    int completionsThisWeek;
    int completionsThisMonth;
    int completionsThisYear;
    int completionsAllTime;

    if (habit.isQuitHabit) {
      // FOR QUIT HABITS: 
      // After auto-backfill runs (on app load), past days have completion records.
      // We simply count valid completions (non-skipped) like regular habits.
      // This works because:
      //   - Past days without slips → auto-backfilled with "win" completion
      //   - Today → no completion until user logs OR next day backfill
      completionsThisWeek = _countSuccessfulCompletionsInPeriod(validCompletions, weekStart, today, habit);
      completionsThisMonth = _countSuccessfulCompletionsInPeriod(validCompletions, monthStart, today, habit);
      completionsThisYear = _countSuccessfulCompletionsInPeriod(validCompletions, yearStart, today, habit);
      completionsAllTime = _countSuccessfulCompletions(validCompletions, habit);
    } else {
      // FOR REGULAR HABITS: Success = Explicit logs
      completionsThisWeek = _countSuccessfulCompletionsInPeriod(validCompletions, weekStart, today, habit);
      completionsThisMonth = _countSuccessfulCompletionsInPeriod(validCompletions, monthStart, today, habit);
      completionsThisYear = _countSuccessfulCompletionsInPeriod(validCompletions, yearStart, today, habit);
      completionsAllTime = _countSuccessfulCompletions(validCompletions, habit);
    }

    // Expected completions
    final expectedThisWeek = _calculateExpectedCompletions(habit, weekStart, today);
    final expectedThisMonth = _calculateExpectedCompletions(habit, monthStart, today);
    final expectedThisYear = _calculateExpectedCompletions(habit, yearStart, today);

    // Duration statistics (for timer habits)
    int? minutesThisWeek;
    int? minutesThisMonth;
    int? minutesThisYear;
    int? minutesAllTime;
    double? averageMinutesPerCompletion;

    if (habit.completionType == 'timer') {
      minutesThisWeek = _sumDurationInPeriod(validCompletions, weekStart, today);
      minutesThisMonth = _sumDurationInPeriod(validCompletions, monthStart, today);
      minutesThisYear = _sumDurationInPeriod(validCompletions, yearStart, today);
      minutesAllTime = validCompletions
          .where((c) => c.actualDurationMinutes != null)
          .fold<int>(0, (sum, c) => sum + c.actualDurationMinutes!);
      
      final countWithDuration = validCompletions.where((c) => c.actualDurationMinutes != null).length;
      if (countWithDuration > 0) {
        averageMinutesPerCompletion = minutesAllTime / countWithDuration;
      }
    }

    // Numeric statistics
    double? totalValueThisWeek;
    double? totalValueThisMonth;
    double? totalValueThisYear;
    double? totalValueAllTime;
    double? averageValuePerCompletion;

    if (habit.completionType == 'numeric') {
      totalValueThisWeek = _sumValueInPeriod(validCompletions, weekStart, today);
      totalValueThisMonth = _sumValueInPeriod(validCompletions, monthStart, today);
      totalValueThisYear = _sumValueInPeriod(validCompletions, yearStart, today);
      totalValueAllTime = validCompletions
          .where((c) => c.actualValue != null)
          .fold<double>(0, (sum, c) => sum + c.actualValue!);
      
      final countWithValue = validCompletions.where((c) => c.actualValue != null).length;
      if (countWithValue > 0) {
        averageValuePerCompletion = totalValueAllTime / countWithValue;
      }
    }

    // Success/Fail breakdown
    int successCount = completionsAllTime;
    int skipCount = skippedDates.length;
    int postponeCount = allCompletions.where((c) => c.isPostponed).length;
    int failCount = allCompletions.length - successCount - skipCount - postponeCount;
    if (failCount < 0) failCount = 0;

    // Completion rates
    final weekCompletionRate = expectedThisWeek > 0 
        ? (completionsThisWeek / expectedThisWeek * 100).clamp(0, 100).toDouble()
        : 0.0;
    final monthCompletionRate = expectedThisMonth > 0 
        ? (completionsThisMonth / expectedThisMonth * 100).clamp(0, 100).toDouble()
        : 0.0;
    final yearCompletionRate = expectedThisYear > 0 
        ? (completionsThisYear / expectedThisYear * 100).clamp(0, 100).toDouble()
        : 0.0;
    
    final expectedAllTime = _calculateExpectedCompletions(habit, startDateOnly, today);
    final allTimeCompletionRate = expectedAllTime > 0 
        ? (completionsAllTime / expectedAllTime * 100).clamp(0, 100).toDouble()
        : 0.0;

    // Best periods
    final (bestWeekStart, bestWeekCompletions) = _findBestWeek(validCompletions, habit);
    final (bestMonthStart, bestMonthCompletions) = _findBestMonth(validCompletions, habit);

    // Weekday distribution
    final weekdayDistribution = _calculateWeekdayDistribution(validCompletions);

    // Consistency score (schedule adherence + regularity, type-aware)
    final consistencyScore = _calculateConsistencyScore(
      validCompletions,
      habit,
      expectedCompletions: expectedAllTime,
      actualCompletions: completionsAllTime,
    );

    // For Quit habits
    int? slipsCount;
    double? moneySaved;
    int? unitsAvoided;
    int? resistanceCount;

    if (habit.isQuitHabit) {
      // Count total slips (all unique dates with isSkipped=true)
      // NOT currentSlipCount which only tracks slips within streak protection window
      slipsCount = skipCount;
      moneySaved = habit.moneySaved ?? 0;
      unitsAvoided = habit.unitsAvoided ?? 0;
      resistanceCount = successCount;
    }

    // Monthly completions for chart
    final monthlyCompletions = _calculateMonthlyCompletions(validCompletions, habit);
    final weeklyCompletions = _calculateWeeklyCompletions(validCompletions, habit);
    final dailyCompletions = _calculateDailyCompletions(validCompletions, habit);

    // Skip reasons
    final skipReasons = <String, int>{};
    for (final completion in allCompletions) {
      if (completion.isSkipped && completion.skipReason != null) {
        final reason = completion.skipReason!;
        skipReasons[reason] = (skipReasons[reason] ?? 0) + 1;
      }
    }

    // Recent completions (sorted by date descending)
    final recentCompletions = List<HabitCompletion>.from(allCompletions)
      ..sort((a, b) => b.completedDate.compareTo(a.completedDate));

    // Completion dates for calendar heatmap
    // After auto-backfill, both quit and regular habits have completion records
    // for successful days, so we can use the same logic for both
    final completionDates = validCompletions
        .where((c) => _isSuccessfulCompletion(c, habit))
        .map((c) => DateTime(c.completedDate.year, c.completedDate.month, c.completedDate.day))
        .toSet()
        .toList()
      ..sort();

    return HabitStatistics(
      habitId: habit.id,
      completionsThisWeek: completionsThisWeek,
      completionsThisMonth: completionsThisMonth,
      completionsThisYear: completionsThisYear,
      completionsAllTime: completionsAllTime,
      expectedThisWeek: expectedThisWeek,
      expectedThisMonth: expectedThisMonth,
      expectedThisYear: expectedThisYear,
      currentStreak: habit.currentStreak,
      bestStreak: habit.bestStreak,
      totalStreakDays: completionDates.length,
      minutesThisWeek: minutesThisWeek,
      minutesThisMonth: minutesThisMonth,
      minutesThisYear: minutesThisYear,
      minutesAllTime: minutesAllTime,
      averageMinutesPerCompletion: averageMinutesPerCompletion,
      totalValueThisWeek: totalValueThisWeek,
      totalValueThisMonth: totalValueThisMonth,
      totalValueThisYear: totalValueThisYear,
      totalValueAllTime: totalValueAllTime,
      averageValuePerCompletion: averageValuePerCompletion,
      successCount: successCount,
      failCount: failCount,
      skipCount: skipCount,
      postponeCount: postponeCount,
      weekCompletionRate: weekCompletionRate,
      monthCompletionRate: monthCompletionRate,
      yearCompletionRate: yearCompletionRate,
      allTimeCompletionRate: allTimeCompletionRate,
      bestWeekStart: bestWeekStart,
      bestWeekCompletions: bestWeekCompletions,
      bestMonthStart: bestMonthStart,
      bestMonthCompletions: bestMonthCompletions,
      consistencyScore: consistencyScore,
      weekdayDistribution: weekdayDistribution,
      slipsCount: slipsCount,
      moneySaved: moneySaved,
      unitsAvoided: unitsAvoided,
      resistanceCount: resistanceCount,
      completionDates: completionDates,
      monthlyCompletions: monthlyCompletions,
      weeklyCompletions: weeklyCompletions,
      dailyCompletions: dailyCompletions,
      skipReasons: skipReasons,
      recentCompletions: recentCompletions,
    );
  }

  /// Check if a completion counts as successful based on habit type
  bool _isSuccessfulCompletion(HabitCompletion completion, Habit habit) {
    if (completion.isSkipped || completion.isPostponed) return false;

    switch (habit.completionType) {
      case 'yesNo':   // NOTE: Must match Habit.completionType (camelCase)
      case 'yes_no':  // Keep for backward compatibility
        // Success if answer is true OR count > 0
        return completion.answer == true || completion.count > 0;
      
      case 'numeric':
        // Success if value meets or exceeds target
        if (completion.actualValue == null) {
          // Fallback: check if count > 0 (basic completion)
          return completion.count > 0 || completion.answer == true;
        }
        final target = habit.targetValue ?? 1;
        return completion.actualValue! >= target;
      
      case 'timer':
        // Success if duration meets or exceeds target
        if (completion.actualDurationMinutes == null) {
          // Fallback: check if count > 0 (basic completion)
          return completion.count > 0 || completion.answer == true;
        }
        final targetMinutes = habit.targetDurationMinutes ?? 1;
        return completion.actualDurationMinutes! >= targetMinutes;
      
      case 'checklist':
        // Success if count equals or exceeds checklist items count
        final itemCount = habit.checklist?.length ?? 1;
        return completion.count >= itemCount || completion.answer == true;
      
      case 'quit':
        // For quit habits, success means resisting (answer == true means resisted)
        if (completion.answer != null) return completion.answer == true;
        return completion.count > 0;
      
      default:
        // Default: count > 0 or answer == true
        return completion.count > 0 || completion.answer == true;
    }
  }

  /// Count successful completions (type-aware)
  int _countSuccessfulCompletions(List<HabitCompletion> completions, Habit habit) {
    return completions.where((c) => _isSuccessfulCompletion(c, habit)).length;
  }

  /// Count successful completions in a period (type-aware)
  int _countSuccessfulCompletionsInPeriod(
    List<HabitCompletion> completions, 
    DateTime start, 
    DateTime end, 
    Habit habit
  ) {
    return completions.where((c) {
      final inPeriod = c.completedDate.isAfter(start.subtract(const Duration(days: 1))) &&
          c.completedDate.isBefore(end.add(const Duration(days: 1)));
      return inPeriod && _isSuccessfulCompletion(c, habit);
    }).length;
  }

  DateTime _getWeekStart(DateTime date) {
    final daysSinceSunday = date.weekday % 7;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysSinceSunday));
  }

  int _calculateExpectedCompletions(Habit habit, DateTime start, DateTime end) {
    final totalDays = end.difference(start).inDays + 1;

    switch (habit.frequencyType) {
      case 'daily':
        return totalDays;
      
      case 'weekly':
        // If specific weekdays are set, count those days
        if (habit.weekDays != null && habit.weekDays!.isNotEmpty) {
          int count = 0;
          for (int i = 0; i < totalDays; i++) {
            final date = start.add(Duration(days: i));
            final weekday = date.weekday % 7; // 0=Sun, 1=Mon, ..., 6=Sat
            if (habit.weekDays!.contains(weekday)) count++;
          }
          return count;
        }
        // Otherwise assume once per week
        return totalDays ~/ 7;
      
      case 'custom':
        if (habit.frequencyPeriod != null) {
          switch (habit.frequencyPeriod) {
            case 'day':
              return totalDays * habit.targetCount;
            case 'week':
              return (totalDays / 7 * habit.targetCount).ceil();
            case 'month':
              return (totalDays / 30 * habit.targetCount).ceil();
            case 'year':
              return (totalDays / 365 * habit.targetCount).ceil();
          }
        }
        if (habit.customIntervalDays != null && habit.customIntervalDays! > 0) {
          return totalDays ~/ habit.customIntervalDays!;
        }
        return totalDays;
      
      case 'xTimesPerWeek':
        return (totalDays / 7 * habit.targetCount).ceil();
      
      case 'xTimesPerMonth':
        return (totalDays / 30 * habit.targetCount).ceil();
      
      default:
        return totalDays;
    }
  }

  int _sumDurationInPeriod(List<HabitCompletion> completions, DateTime start, DateTime end) {
    return completions
        .where((c) =>
            c.actualDurationMinutes != null &&
            c.completedDate.isAfter(start.subtract(const Duration(days: 1))) &&
            c.completedDate.isBefore(end.add(const Duration(days: 1))))
        .fold<int>(0, (sum, c) => sum + c.actualDurationMinutes!);
  }

  double _sumValueInPeriod(List<HabitCompletion> completions, DateTime start, DateTime end) {
    return completions
        .where((c) =>
            c.actualValue != null &&
            c.completedDate.isAfter(start.subtract(const Duration(days: 1))) &&
            c.completedDate.isBefore(end.add(const Duration(days: 1))))
        .fold<double>(0, (sum, c) => sum + c.actualValue!);
  }

  (DateTime?, int?) _findBestWeek(List<HabitCompletion> completions, Habit habit) {
    if (completions.isEmpty) return (null, null);

    // Only count successful completions for best week
    final successfulCompletions = completions.where((c) => _isSuccessfulCompletion(c, habit)).toList();
    if (successfulCompletions.isEmpty) return (null, null);

    final weekCounts = <String, int>{};
    for (final completion in successfulCompletions) {
      final weekStart = _getWeekStart(completion.completedDate);
      final key = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
      weekCounts[key] = (weekCounts[key] ?? 0) + 1;
    }

    if (weekCounts.isEmpty) return (null, null);

    final bestEntry = weekCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final parts = bestEntry.key.split('-');
    final bestWeek = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));

    return (bestWeek, bestEntry.value);
  }

  (DateTime?, int?) _findBestMonth(List<HabitCompletion> completions, Habit habit) {
    if (completions.isEmpty) return (null, null);

    // Only count successful completions for best month
    final successfulCompletions = completions.where((c) => _isSuccessfulCompletion(c, habit)).toList();
    if (successfulCompletions.isEmpty) return (null, null);

    final monthCounts = <String, int>{};
    for (final completion in successfulCompletions) {
      final key = '${completion.completedDate.year}-${completion.completedDate.month}';
      monthCounts[key] = (monthCounts[key] ?? 0) + 1;
    }

    if (monthCounts.isEmpty) return (null, null);

    final bestEntry = monthCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final parts = bestEntry.key.split('-');
    final bestMonth = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);

    return (bestMonth, bestEntry.value);
  }

  List<int> _calculateWeekdayDistribution(List<HabitCompletion> completions) {
    // Distribution array: [Sun=0, Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6]
    final distribution = [0, 0, 0, 0, 0, 0, 0];
    for (final completion in completions) {
      // DateTime.weekday: 1=Mon, 2=Tue, ..., 7=Sun
      // We want: 0=Sun, 1=Mon, ..., 6=Sat
      final weekday = completion.completedDate.weekday % 7;
      distribution[weekday]++;
    }
    return distribution;
  }

  double _calculateConsistencyScore(
    List<HabitCompletion> completions,
    Habit habit, {
    required int expectedCompletions,
    required int actualCompletions,
  }) {
    if (expectedCompletions <= 0) return 0;

    final adherenceScore =
        (actualCompletions / expectedCompletions * 100).clamp(0.0, 100.0).toDouble();
    if (completions.isEmpty) return adherenceScore * 0.2;

    final dates = completions
        .where((c) => _isSuccessfulCompletion(c, habit))
        .map((c) => DateTime(c.completedDate.year, c.completedDate.month, c.completedDate.day))
        .toSet()
        .toList()
      ..sort();

    if (dates.isEmpty) return 0;
    if (dates.length < 2) return (adherenceScore * 0.9 + 10).clamp(0.0, 100.0);

    final gaps = <int>[];
    for (int i = 1; i < dates.length; i++) {
      gaps.add(dates[i].difference(dates[i - 1]).inDays);
    }
    if (gaps.isEmpty) return adherenceScore;

    final expectedGap = _expectedGapDays(habit);
    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    final variance = gaps
            .map((g) => math.pow(g - avgGap, 2))
            .reduce((a, b) => a + b) /
        gaps.length;
    final stdDev = math.sqrt(variance);

    final gapDeviationFromExpected = (avgGap - expectedGap).abs();
    final gapScore = (100 - (gapDeviationFromExpected / expectedGap * 100))
        .clamp(0.0, 100.0)
        .toDouble();
    final regularityScore = (100 - (stdDev / expectedGap * 100))
        .clamp(0.0, 100.0)
        .toDouble();

    double timingScore = gapScore * 0.5 + regularityScore * 0.5;

    if (habit.frequencyType == 'weekly' &&
        habit.weekDays != null &&
        habit.weekDays!.isNotEmpty) {
      final scheduledHits =
          dates.where((d) => habit.weekDays!.contains(d.weekday % 7)).length;
      final weekdayAlignment =
          (scheduledHits / dates.length * 100).clamp(0.0, 100.0).toDouble();
      timingScore = timingScore * 0.7 + weekdayAlignment * 0.3;
    }

    if (habit.completionType == 'quit') {
      return (adherenceScore * 0.8 + timingScore * 0.2).clamp(0.0, 100.0);
    }

    return (adherenceScore * 0.7 + timingScore * 0.3).clamp(0.0, 100.0);
  }

  double _expectedGapDays(Habit habit) {
    switch (habit.frequencyType) {
      case 'daily':
        return 1.0;
      case 'weekly':
        if (habit.weekDays != null && habit.weekDays!.isNotEmpty) {
          return (7 / habit.weekDays!.length).clamp(1.0, 7.0).toDouble();
        }
        return 7.0;
      case 'xTimesPerWeek':
        return habit.targetCount > 0
            ? (7 / habit.targetCount).clamp(1.0, 7.0).toDouble()
            : 7.0;
      case 'xTimesPerMonth':
        return habit.targetCount > 0
            ? (30 / habit.targetCount).clamp(1.0, 30.0).toDouble()
            : 30.0;
      case 'custom':
        if (habit.customIntervalDays != null && habit.customIntervalDays! > 0) {
          return habit.customIntervalDays!.toDouble();
        }
        if (habit.frequencyPeriod != null) {
          switch (habit.frequencyPeriod) {
            case 'day':
              return habit.targetCount > 0
                  ? (1 / habit.targetCount).clamp(0.25, 1.0).toDouble()
                  : 1.0;
            case 'week':
              return habit.targetCount > 0
                  ? (7 / habit.targetCount).clamp(1.0, 7.0).toDouble()
                  : 7.0;
            case 'month':
              return habit.targetCount > 0
                  ? (30 / habit.targetCount).clamp(1.0, 30.0).toDouble()
                  : 30.0;
            case 'year':
              return habit.targetCount > 0
                  ? (365 / habit.targetCount).clamp(1.0, 365.0).toDouble()
                  : 365.0;
          }
        }
        return 1.0;
      default:
        return 1.0;
    }
  }

  Map<String, int> _calculateMonthlyCompletions(List<HabitCompletion> completions, Habit habit) {
    final monthly = <String, int>{};
    // Only count successful completions for monthly trend
    for (final completion in completions) {
      if (_isSuccessfulCompletion(completion, habit)) {
        final key = '${completion.completedDate.year}-${completion.completedDate.month.toString().padLeft(2, '0')}';
        monthly[key] = (monthly[key] ?? 0) + 1;
      }
    }
    return monthly;
  }

  Map<String, int> _calculateWeeklyCompletions(List<HabitCompletion> completions, Habit habit) {
    final weekly = <String, int>{};
    for (final completion in completions) {
      if (_isSuccessfulCompletion(completion, habit)) {
        final weekStart = _getWeekStart(completion.completedDate);
        final key = '${weekStart.year}-W${_getWeekNumber(weekStart).toString().padLeft(2, '0')}';
        weekly[key] = (weekly[key] ?? 0) + 1;
      }
    }
    return weekly;
  }

  Map<String, int> _calculateDailyCompletions(List<HabitCompletion> completions, Habit habit) {
    final daily = <String, int>{};
    for (final completion in completions) {
      if (_isSuccessfulCompletion(completion, habit)) {
        final key = DateFormat('yyyy-MM-dd').format(completion.completedDate);
        daily[key] = (daily[key] ?? 0) + 1;
      }
    }
    return daily;
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return (daysSinceFirstDay / 7).floor() + 1;
  }
}
