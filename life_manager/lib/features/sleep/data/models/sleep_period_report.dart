import 'sleep_weekly_report.dart';

class SleepGoalPerformance {
  final String? goalId;
  final String goalName;
  final int applicableDays;
  final int loggedDays;
  final int metDays;
  final double hitRate;

  const SleepGoalPerformance({
    required this.goalId,
    required this.goalName,
    required this.applicableDays,
    required this.loggedDays,
    required this.metDays,
    required this.hitRate,
  });
}

class SleepPeriodReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<DailySleepGoalReport> days;
  final int totalDays;
  final int loggedDays;
  final int daysWithGoals;
  final int manualOverrideDays;
  final double dataCoverageRate;
  final double averageTargetHours;
  final double averageActualHours;
  final double totalSleepDebtHours;
  final double goalHitRate;
  final int averageScore;
  final Map<int, double> averageHoursByWeekday;
  final List<SleepGoalPerformance> goalPerformance;
  final List<String> observations;

  const SleepPeriodReport({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.totalDays,
    required this.loggedDays,
    required this.daysWithGoals,
    required this.manualOverrideDays,
    required this.dataCoverageRate,
    required this.averageTargetHours,
    required this.averageActualHours,
    required this.totalSleepDebtHours,
    required this.goalHitRate,
    required this.averageScore,
    required this.averageHoursByWeekday,
    required this.goalPerformance,
    required this.observations,
  });
}
