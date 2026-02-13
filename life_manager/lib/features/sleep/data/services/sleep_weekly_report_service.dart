import '../models/sleep_record.dart';
import '../models/sleep_weekly_report.dart';
import 'sleep_scoring_service.dart';

class SleepWeeklyReportService {
  final SleepScoringService scoringService;

  SleepWeeklyReportService({required this.scoringService});

  SleepWeeklyReport calculateWeeklyReport({
    required DateTime weekStart,
    required List<SleepRecord> records,
    required double targetHours,
  }) {
    final normalizedWeekStart =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final normalizedWeekEnd = normalizedWeekStart.add(const Duration(days: 6));

    final groupedMainRecords = <DateTime, List<SleepRecord>>{};
    for (final record in records.where((r) => !r.isNap)) {
      final key = DateTime(
        record.bedTime.year,
        record.bedTime.month,
        record.bedTime.day,
      );
      groupedMainRecords[key] = [...(groupedMainRecords[key] ?? []), record];
    }

    final dayReports = <DailySleepGoalReport>[];
    double totalTarget = 0;
    double totalActual = 0;
    int hitCount = 0;
    int totalScore = 0;

    for (int i = 0; i < 7; i++) {
      final date = normalizedWeekStart.add(Duration(days: i));
      final dateKey = DateTime(date.year, date.month, date.day);
      final dayRecords = groupedMainRecords[dateKey] ?? const <SleepRecord>[];

      final actualHours = dayRecords.isEmpty
          ? 0.0
          : dayRecords.fold<double>(0, (sum, r) => sum + r.actualSleepHours) /
              dayRecords.length;

      int dayScore = 0;
      String dayGrade = '-';
      bool goalMet = false;
      if (dayRecords.isNotEmpty) {
        final results = dayRecords
            .map((record) => scoringService.scoreRecord(
                  record: record,
                  targetHours: targetHours,
                ))
            .toList();
        dayScore =
            (results.fold<int>(0, (sum, s) => sum + s.overallScore) / results.length)
                .round();
        dayGrade = results.first.grade;
        goalMet = (actualHours - targetHours).abs() <= 0.5;
        if (goalMet) hitCount++;
      }

      totalTarget += targetHours;
      totalActual += actualHours;
      totalScore += dayScore;

      dayReports.add(
        DailySleepGoalReport(
          date: dateKey,
          goalId: null,
          goalName: 'Target',
          isManualOverride: false,
          targetHours: targetHours,
          actualHours: actualHours,
          score: dayScore,
          grade: dayGrade,
          goalMet: goalMet,
        ),
      );
    }

    final averageTarget = totalTarget / 7;
    final averageActual = totalActual / 7;
    final debt = dayReports.fold<double>(0, (sum, day) {
      final deficit = day.targetHours - day.actualHours;
      return sum + (deficit > 0 ? deficit : 0);
    });
    final hitRate = (hitCount / 7) * 100;
    final averageScore = (totalScore / 7).round();

    return SleepWeeklyReport(
      weekStart: normalizedWeekStart,
      weekEnd: normalizedWeekEnd,
      days: dayReports,
      averageTargetHours: averageTarget,
      averageActualHours: averageActual,
      totalSleepDebtHours: debt,
      goalHitRate: hitRate,
      averageScore: averageScore,
      recommendations: _buildRecommendations(
        dayReports: dayReports,
        hitRate: hitRate,
        debtHours: debt,
      ),
    );
  }

  List<String> _buildRecommendations({
    required List<DailySleepGoalReport> dayReports,
    required double hitRate,
    required double debtHours,
  }) {
    final recommendations = <String>[];
    if (hitRate < 60) {
      recommendations.add(
        'Your target hit rate is low this week. Try to get closer to your sleep target.',
      );
    }
    if (debtHours >= 5) {
      recommendations.add(
        'You built notable sleep debt this week. Recover gradually with 30-60 extra minutes on upcoming nights.',
      );
    }

    final weekday = dayReports
        .where((d) => d.date.weekday >= DateTime.monday && d.date.weekday <= DateTime.friday)
        .toList();
    final weekend = dayReports
        .where((d) => d.date.weekday == DateTime.saturday || d.date.weekday == DateTime.sunday)
        .toList();

    if (weekday.isNotEmpty && weekend.isNotEmpty) {
      final weekdayAvg = weekday.fold<double>(0, (sum, d) => sum + d.actualHours) /
          weekday.length;
      final weekendAvg = weekend.fold<double>(0, (sum, d) => sum + d.actualHours) /
          weekend.length;
      final delta = (weekendAvg - weekdayAvg).abs();
      if (delta >= 1.5) {
        recommendations.add(
          'Your weekday/weekend sleep gap is high. Reducing this gap can improve consistency.',
        );
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Strong week. Keep your current pattern and continue logging sleep consistently.',
      );
    }
    return recommendations;
  }
}
