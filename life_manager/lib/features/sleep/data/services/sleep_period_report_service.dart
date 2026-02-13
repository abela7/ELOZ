import '../models/sleep_period_report.dart';
import '../models/sleep_record.dart';
import '../models/sleep_weekly_report.dart';
import 'sleep_scoring_service.dart';

class SleepPeriodReportService {
  final SleepScoringService scoringService;

  SleepPeriodReportService({required this.scoringService});

  SleepPeriodReport calculatePeriodReport({
    required DateTime startDate,
    required DateTime endDate,
    required List<SleepRecord> records,
    required double targetHours,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final totalDays = end.difference(start).inDays + 1;

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
    int loggedDays = 0;
    int totalGoalMetDays = 0;
    int totalScore = 0;
    double totalActualHours = 0;
    double totalSleepDebt = 0;

    final weekdayBuckets = <int, List<double>>{};

    for (int offset = 0; offset < totalDays; offset++) {
      final date = start.add(Duration(days: offset));
      final dayKey = DateTime(date.year, date.month, date.day);
      final dayRecords = groupedMainRecords[dayKey] ?? const <SleepRecord>[];

      final hasLog = dayRecords.isNotEmpty;
      final actualHours = hasLog
          ? dayRecords.fold<double>(0, (sum, r) => sum + r.actualSleepHours) /
              dayRecords.length
          : 0.0;

      int dayScore = 0;
      String dayGrade = '-';
      if (hasLog) {
        final scored = dayRecords
            .map((record) => scoringService.scoreRecord(
                  record: record,
                  targetHours: targetHours,
                ))
            .toList();
        dayScore =
            (scored.fold<int>(0, (sum, s) => sum + s.overallScore) / scored.length)
                .round();
        dayGrade = scored.first.grade;
      }

      final goalMet = hasLog && (actualHours - targetHours).abs() <= 0.5;

      if (hasLog) {
        loggedDays++;
        totalActualHours += actualHours;
        totalScore += dayScore;
        weekdayBuckets[date.weekday] = [
          ...(weekdayBuckets[date.weekday] ?? []),
          actualHours,
        ];
        final deficit = targetHours - actualHours;
        if (deficit > 0) totalSleepDebt += deficit;
        if (goalMet) totalGoalMetDays++;
      }

      dayReports.add(
        DailySleepGoalReport(
          date: dayKey,
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

    final avgTarget = targetHours;
    final avgActual = loggedDays == 0 ? 0.0 : totalActualHours / loggedDays;
    final avgScore = loggedDays == 0 ? 0 : (totalScore / loggedDays).round();
    final hitRate = loggedDays == 0
        ? 0.0
        : (totalGoalMetDays / loggedDays) * 100;
    final coverageRate = totalDays == 0 ? 0.0 : (loggedDays / totalDays) * 100;

    final averageByWeekday = <int, double>{};
    for (final entry in weekdayBuckets.entries) {
      final avg = entry.value.fold<double>(0, (sum, h) => sum + h) / entry.value.length;
      averageByWeekday[entry.key] = avg;
    }

    final observations = _buildObservations(
      totalDays: totalDays,
      loggedDays: loggedDays,
      coverageRate: coverageRate,
      averageByWeekday: averageByWeekday,
    );

    return SleepPeriodReport(
      startDate: start,
      endDate: end,
      days: dayReports,
      totalDays: totalDays,
      loggedDays: loggedDays,
      daysWithGoals: totalDays,
      manualOverrideDays: 0,
      dataCoverageRate: coverageRate,
      averageTargetHours: avgTarget,
      averageActualHours: avgActual,
      totalSleepDebtHours: totalSleepDebt,
      goalHitRate: hitRate,
      averageScore: avgScore,
      averageHoursByWeekday: averageByWeekday,
      goalPerformance: const [],
      observations: observations,
    );
  }

  List<String> _buildObservations({
    required int totalDays,
    required int loggedDays,
    required double coverageRate,
    required Map<int, double> averageByWeekday,
  }) {
    final lines = <String>[
      'Logged $loggedDays of $totalDays days (${coverageRate.toStringAsFixed(0)}% coverage).',
    ];

    if (averageByWeekday.isNotEmpty) {
      final sorted = averageByWeekday.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final best = sorted.first;
      final worst = sorted.last;
      lines.add(
        'Best weekday average: ${_weekdayName(best.key)} (${best.value.toStringAsFixed(1)}h).',
      );
      lines.add(
        'Lowest weekday average: ${_weekdayName(worst.key)} (${worst.value.toStringAsFixed(1)}h).',
      );
    }

    return lines;
  }

  String _weekdayName(int weekday) {
    const names = <int, String>{
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    return names[weekday] ?? 'Unknown';
  }
}
