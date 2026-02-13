import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/sleep/data/models/sleep_record.dart';
import 'package:life_manager/features/sleep/data/services/sleep_period_report_service.dart';
import 'package:life_manager/features/sleep/data/services/sleep_scoring_service.dart';

void main() {
  group('SleepPeriodReportService', () {
    final scoringService = SleepScoringService();
    final reportService = SleepPeriodReportService(scoringService: scoringService);

    test('builds period metrics with fixed target hours', () {
      final start = DateTime(2026, 2, 1);
      final end = DateTime(2026, 2, 5);

      final records = <SleepRecord>[
        SleepRecord(
          bedTime: DateTime(2026, 2, 1, 22, 30),
          wakeTime: DateTime(2026, 2, 2, 6, 0),
        ),
        SleepRecord(
          bedTime: DateTime(2026, 2, 2, 23, 30),
          wakeTime: DateTime(2026, 2, 3, 7, 0),
        ),
        SleepRecord(
          bedTime: DateTime(2026, 2, 3, 23, 30),
          wakeTime: DateTime(2026, 2, 4, 8, 0),
        ),
      ];

      final report = reportService.calculatePeriodReport(
        startDate: start,
        endDate: end,
        records: records,
        targetHours: 7.5,
      );

      expect(report.totalDays, 5);
      expect(report.loggedDays, 3);
      expect(report.daysWithGoals, 5);
      expect(report.dataCoverageRate, closeTo(60, 0.01));
      expect(report.goalHitRate, greaterThanOrEqualTo(0));
      expect(report.observations, isNotEmpty);
    });
  });
}
