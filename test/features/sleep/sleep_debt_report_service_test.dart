import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/sleep/data/models/sleep_record.dart';
import 'package:life_manager/features/sleep/data/repositories/sleep_record_repository.dart';
import 'package:life_manager/features/sleep/data/services/sleep_debt_report_service.dart';

void main() {
  group('SleepDebtReportService', () {
    test(
      'weekly breakdown applies repayment within Monday-Sunday week',
      () async {
        final repo = FakeSleepRecordRepository();
        repo.records = [
          _record(DateTime(2025, 2, 3, 22, 0), 6), // Mon: +1h debt (target 7h)
          _record(DateTime(2025, 2, 4, 22, 0), 6), // Tue: +1h debt => 2h
          _record(
            DateTime(2025, 2, 5, 22, 0),
            8,
          ), // Wed: -1h repayment => 1h left
        ];

        final service = SleepDebtReportService(repository: repo);
        final weekly = await service.getWeeklyBreakdown(
          start: DateTime(2025, 2, 3),
          end: DateTime(2025, 2, 5),
          targetHours: 7.0,
        );

        expect(weekly.length, 1);
        expect(weekly.first.weekStart, DateTime(2025, 2, 3));
        expect(weekly.first.debtMinutes, 60);
        expect(weekly.first.nightsWithData, 3);
      },
    );

    test('monthly breakdown applies repayment within month', () async {
      final repo = FakeSleepRecordRepository();
      repo.records = [
        _record(DateTime(2025, 2, 3, 22, 0), 6),
        _record(DateTime(2025, 2, 4, 22, 0), 6),
        _record(DateTime(2025, 2, 5, 22, 0), 8),
      ];

      final service = SleepDebtReportService(repository: repo);
      final monthly = await service.getMonthlyBreakdown(
        start: DateTime(2025, 2, 3),
        end: DateTime(2025, 2, 5),
        targetHours: 7.0,
      );

      expect(monthly.length, 1);
      expect(monthly.first.year, 2025);
      expect(monthly.first.month, 2);
      expect(monthly.first.debtMinutes, 60);
    });

    test('all-time debt starts from first logged main sleep date', () async {
      final repo = FakeSleepRecordRepository();
      final now = DateTime.now();
      repo.records = [_record(DateTime(now.year, now.month, now.day, 0, 0), 8)];

      final service = SleepDebtReportService(repository: repo);
      final total = await service.getAllTimeDebtMinutes(targetHours: 8.0);
      final yearly = await service.getAllTimeYearlyBreakdown(targetHours: 8.0);

      expect(total, 0);
      expect(yearly.length, 1);
      expect(yearly.first.year, now.year);
      expect(yearly.first.debtMinutes, 0);
    });

    test('all-time debt is zero when no records exist', () async {
      final repo = FakeSleepRecordRepository();
      final service = SleepDebtReportService(repository: repo);

      final total = await service.getAllTimeDebtMinutes(targetHours: 8.0);
      final yearly = await service.getAllTimeYearlyBreakdown(targetHours: 8.0);

      expect(total, 0);
      expect(yearly, isEmpty);
    });
  });
}

SleepRecord _record(DateTime bedTime, double hours, {bool isNap = false}) {
  return SleepRecord(
    bedTime: bedTime,
    wakeTime: bedTime.add(Duration(minutes: (hours * 60).round())),
    quality: 'good',
    isNap: isNap,
  );
}

class FakeSleepRecordRepository extends SleepRecordRepository {
  List<SleepRecord> records = [];

  @override
  Future<List<SleepRecord>> getMainSleepByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return records.where((r) {
      if (r.isNap) return false;
      final d = DateTime(r.bedTime.year, r.bedTime.month, r.bedTime.day);
      return !d.isBefore(startDate) && !d.isAfter(endDate);
    }).toList();
  }

  @override
  Future<List<SleepRecord>> getMainSleepRecords() async {
    final mainSleep = records.where((r) => !r.isNap).toList();
    mainSleep.sort((a, b) => b.bedTime.compareTo(a.bedTime));
    return mainSleep;
  }
}
