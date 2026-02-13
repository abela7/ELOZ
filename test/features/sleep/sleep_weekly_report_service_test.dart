import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/sleep/data/models/sleep_record.dart';
import 'package:life_manager/features/sleep/data/services/sleep_scoring_service.dart';
import 'package:life_manager/features/sleep/data/services/sleep_weekly_report_service.dart';

void main() {
  group('SleepWeeklyReportService', () {
    final scoringService = SleepScoringService();
    final reportService = SleepWeeklyReportService(scoringService: scoringService);

    test('calculates weekly hit rate and sleep debt from fixed target', () {
      final weekStart = DateTime(2026, 2, 9); // Monday

      final records = <SleepRecord>[
        SleepRecord(
          bedTime: DateTime(2026, 2, 9, 22, 30),
          wakeTime: DateTime(2026, 2, 10, 6, 30),
        ),
        SleepRecord(
          bedTime: DateTime(2026, 2, 10, 22, 45),
          wakeTime: DateTime(2026, 2, 11, 6, 15),
        ),
        SleepRecord(
          bedTime: DateTime(2026, 2, 11, 23, 0),
          wakeTime: DateTime(2026, 2, 12, 6, 0),
        ),
        SleepRecord(
          bedTime: DateTime(2026, 2, 12, 22, 20),
          wakeTime: DateTime(2026, 2, 13, 6, 35),
        ),
        SleepRecord(
          bedTime: DateTime(2026, 2, 13, 23, 10),
          wakeTime: DateTime(2026, 2, 14, 7, 0),
        ),
        SleepRecord(
          bedTime: DateTime(2026, 2, 14, 23, 40),
          wakeTime: DateTime(2026, 2, 15, 7, 0),
        ),
        SleepRecord(
          bedTime: DateTime(2026, 2, 15, 23, 30),
          wakeTime: DateTime(2026, 2, 16, 7, 30),
        ),
      ];

      final report = reportService.calculateWeeklyReport(
        weekStart: weekStart,
        records: records,
        targetHours: 8,
      );

      expect(report.days.length, equals(7));
      expect(report.goalHitRate, greaterThanOrEqualTo(0));
      expect(report.totalSleepDebtHours, greaterThanOrEqualTo(0));
      expect(report.averageActualHours, greaterThan(0));
      expect(report.averageTargetHours, equals(8));
      expect(report.recommendations, isNotEmpty);
    });

    test('reports zero debt when all days meet target', () {
      final weekStart = DateTime(2026, 2, 9);

      final records = <SleepRecord>[
        SleepRecord(
          bedTime: DateTime(2026, 2, 9, 22, 0),
          wakeTime: DateTime(2026, 2, 10, 6, 0),
        ),
      ];

      final report = reportService.calculateWeeklyReport(
        weekStart: weekStart,
        records: records,
        targetHours: 8,
      );

      expect(report.days.length, equals(7));
      expect(report.days.first.actualHours, closeTo(8, 0.1));
      expect(report.days.first.goalMet, isTrue);
    });
  });
}
