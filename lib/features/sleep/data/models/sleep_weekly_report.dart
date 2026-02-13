class DailySleepGoalReport {
  final DateTime date;
  final String? goalId;
  final String goalName;
  final bool isManualOverride;
  final double targetHours;
  final double actualHours;
  final int score;
  final String grade;
  final bool goalMet;

  const DailySleepGoalReport({
    required this.date,
    required this.goalId,
    required this.goalName,
    required this.isManualOverride,
    required this.targetHours,
    required this.actualHours,
    required this.score,
    required this.grade,
    required this.goalMet,
  });

  double get differenceHours => actualHours - targetHours;
}

class SleepWeeklyReport {
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<DailySleepGoalReport> days;
  final double averageTargetHours;
  final double averageActualHours;
  final double totalSleepDebtHours;
  final double goalHitRate;
  final int averageScore;
  final List<String> recommendations;

  const SleepWeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
    required this.averageTargetHours,
    required this.averageActualHours,
    required this.totalSleepDebtHours,
    required this.goalHitRate,
    required this.averageScore,
    required this.recommendations,
  });
}
