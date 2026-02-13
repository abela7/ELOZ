import 'habit_completion.dart';

/// Comprehensive statistics for a habit
class HabitStatistics {
  final String habitId;
  
  // Time period completions
  final int completionsThisWeek;
  final int completionsThisMonth;
  final int completionsThisYear;
  final int completionsAllTime;
  
  // Expected vs Actual
  final int expectedThisWeek;
  final int expectedThisMonth;
  final int expectedThisYear;
  
  // Streak data
  final int currentStreak;
  final int bestStreak;
  final int totalStreakDays;
  
  // Duration statistics (for timer habits)
  final int? minutesThisWeek;
  final int? minutesThisMonth;
  final int? minutesThisYear;
  final int? minutesAllTime;
  final double? averageMinutesPerCompletion;
  
  // Numeric statistics (for numeric habits)
  final double? totalValueThisWeek;
  final double? totalValueThisMonth;
  final double? totalValueThisYear;
  final double? totalValueAllTime;
  final double? averageValuePerCompletion;
  
  // Success/Fail breakdown
  final int successCount;
  final int failCount;
  final int skipCount;
  final int postponeCount;
  
  // Completion rate percentages
  final double weekCompletionRate;
  final double monthCompletionRate;
  final double yearCompletionRate;
  final double allTimeCompletionRate;
  
  // Best/Worst periods
  final DateTime? bestWeekStart;
  final int? bestWeekCompletions;
  final DateTime? bestMonthStart;
  final int? bestMonthCompletions;
  
  // Consistency metrics
  final double consistencyScore;
  final List<int> weekdayDistribution; // [Sun, Mon, Tue, Wed, Thu, Fri, Sat]
  
  // For Quit habits
  final int? slipsCount;
  final double? moneySaved;
  final int? unitsAvoided;
  final int? resistanceCount;
  
  // Time-based insights
  final List<DateTime> completionDates;
  final Map<String, int> monthlyCompletions; // 'YYYY-MM' -> count
  final Map<String, int> weeklyCompletions; // 'YYYY-WW' -> count
  final Map<String, int> dailyCompletions; // 'YYYY-MM-DD' -> count

  // Skip & Fail Insights
  final Map<String, int> skipReasons;
  final List<HabitCompletion> recentCompletions; // For detailed history

  const HabitStatistics({
    required this.habitId,
    required this.completionsThisWeek,
    required this.completionsThisMonth,
    required this.completionsThisYear,
    required this.completionsAllTime,
    required this.expectedThisWeek,
    required this.expectedThisMonth,
    required this.expectedThisYear,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalStreakDays,
    this.minutesThisWeek,
    this.minutesThisMonth,
    this.minutesThisYear,
    this.minutesAllTime,
    this.averageMinutesPerCompletion,
    this.totalValueThisWeek,
    this.totalValueThisMonth,
    this.totalValueThisYear,
    this.totalValueAllTime,
    this.averageValuePerCompletion,
    required this.successCount,
    required this.failCount,
    required this.skipCount,
    required this.postponeCount,
    required this.weekCompletionRate,
    required this.monthCompletionRate,
    required this.yearCompletionRate,
    required this.allTimeCompletionRate,
    this.bestWeekStart,
    this.bestWeekCompletions,
    this.bestMonthStart,
    this.bestMonthCompletions,
    required this.consistencyScore,
    required this.weekdayDistribution,
    this.slipsCount,
    this.moneySaved,
    this.unitsAvoided,
    this.resistanceCount,
    required this.completionDates,
    required this.monthlyCompletions,
    required this.weeklyCompletions,
    required this.dailyCompletions,
    required this.skipReasons,
    required this.recentCompletions,
  });

  factory HabitStatistics.empty(String habitId) {
    return HabitStatistics(
      habitId: habitId,
      completionsThisWeek: 0,
      completionsThisMonth: 0,
      completionsThisYear: 0,
      completionsAllTime: 0,
      expectedThisWeek: 0,
      expectedThisMonth: 0,
      expectedThisYear: 0,
      currentStreak: 0,
      bestStreak: 0,
      totalStreakDays: 0,
      successCount: 0,
      failCount: 0,
      skipCount: 0,
      postponeCount: 0,
      weekCompletionRate: 0,
      monthCompletionRate: 0,
      yearCompletionRate: 0,
      allTimeCompletionRate: 0,
      consistencyScore: 0,
      weekdayDistribution: [0, 0, 0, 0, 0, 0, 0],
      completionDates: [],
      monthlyCompletions: {},
      weeklyCompletions: {},
      dailyCompletions: {},
      skipReasons: {},
      recentCompletions: [],
    );
  }

  bool get hasData => completionsAllTime > 0;

  // Format duration for display
  String formatDuration(int? minutes) {
    if (minutes == null || minutes == 0) return '0h';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  // Get total pending
  int get pendingCount {
    final totalExpected = expectedThisWeek + expectedThisMonth + expectedThisYear;
    final totalCompleted = completionsThisWeek + completionsThisMonth + completionsThisYear;
    return (totalExpected - totalCompleted).clamp(0, double.infinity).toInt();
  }
}
