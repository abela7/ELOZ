import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/sleep/data/models/sleep_record.dart';
import 'package:life_manager/features/sleep/data/repositories/sleep_record_repository.dart';
import 'package:life_manager/features/sleep/data/services/sleep_debt_consistency_service.dart';

void main() {
  group('SleepDebtConsistencyService', () {
    // Use fixed dates: Sun Feb 9, 2025. Week = Mon Feb 3 - Sun Feb 9.
    // overrideToday = Feb 10 so all week days are in the past.
    final testToday = DateTime(2025, 2, 10);
    final refDate = DateTime(2025, 2, 9);

    test('weekly debt sums deficit across nights', () async {
      final repo = FakeSleepRecordRepository();
      repo.records = [
        SleepRecord(
          bedTime: DateTime(2025, 2, 5, 22, 0), // Wed Feb 5, 6h sleep
          wakeTime: DateTime(2025, 2, 6, 4, 0),
          quality: 'good',
          isNap: false,
        ),
        SleepRecord(
          bedTime: DateTime(2025, 2, 8, 23, 0), // Sat Feb 8, 5h sleep
          wakeTime: DateTime(2025, 2, 9, 4, 0),
          quality: 'good',
          isNap: false,
        ),
      ];
      final service = SleepDebtConsistencyService(repository: repo);
      final result = await service.calculate(
        referenceDate: refDate,
        targetHours: 8.0,
        overrideToday: testToday,
      );

      expect(result.targetHours, 8.0);
      expect(result.weeklyDebtMinutes, greaterThan(0));
      // Mon,Tue,Thu,Fri,Sun missing = 5*480min; Wed deficit 120min; Sat 180min
      expect(result.weeklyDebtMinutes, equals(5 * 480 + 120 + 180));
    });

    test(
      'extra sleep repays debt within the same Monday-Sunday week',
      () async {
        final repo = FakeSleepRecordRepository();
        repo.records = [
          SleepRecord(
            bedTime: DateTime(
              2025,
              2,
              3,
              22,
              0,
            ), // Mon: 6h (target 7h => +1h debt)
            wakeTime: DateTime(2025, 2, 4, 4, 0),
            quality: 'good',
            isNap: false,
          ),
          SleepRecord(
            bedTime: DateTime(2025, 2, 4, 22, 0), // Tue: 6h (debt becomes 2h)
            wakeTime: DateTime(2025, 2, 5, 4, 0),
            quality: 'good',
            isNap: false,
          ),
          SleepRecord(
            bedTime: DateTime(
              2025,
              2,
              5,
              22,
              0,
            ), // Wed: 8h (repays 1h, debt -> 1h)
            wakeTime: DateTime(2025, 2, 6, 6, 0),
            quality: 'good',
            isNap: false,
          ),
        ];

        final service = SleepDebtConsistencyService(repository: repo);
        final result = await service.calculate(
          referenceDate: DateTime(2025, 2, 5), // Wed
          targetHours: 7.0,
          overrideToday: testToday,
        );

        expect(result.weeklyDebtMinutes, equals(60)); // 1h left
        expect(result.dailyDebtMinutes, equals(0)); // Wed itself has no deficit
      },
    );

    test('debt never goes below zero when surplus exceeds deficit', () async {
      final repo = FakeSleepRecordRepository();
      repo.records = [
        SleepRecord(
          bedTime: DateTime(
            2025,
            2,
            3,
            22,
            0,
          ), // Mon: 6h (target 7h => +1h debt)
          wakeTime: DateTime(2025, 2, 4, 4, 0),
          quality: 'good',
          isNap: false,
        ),
        SleepRecord(
          bedTime: DateTime(2025, 2, 4, 22, 0), // Tue: 10h (repays all debt)
          wakeTime: DateTime(2025, 2, 5, 8, 0),
          quality: 'good',
          isNap: false,
        ),
      ];

      final service = SleepDebtConsistencyService(repository: repo);
      final result = await service.calculate(
        referenceDate: DateTime(2025, 2, 4), // Tue
        targetHours: 7.0,
        overrideToday: testToday,
      );

      expect(result.weeklyDebtMinutes, equals(0));
      expect(result.dailyDebtMinutes, equals(0));
    });

    test('naps are excluded from debt calculation', () async {
      final repo = FakeSleepRecordRepository();
      repo.records = [
        SleepRecord(
          bedTime: DateTime(2025, 2, 8, 2, 0), // nap on Sat Feb 8
          wakeTime: DateTime(2025, 2, 8, 4, 0),
          quality: 'good',
          isNap: true,
        ),
      ];
      final service = SleepDebtConsistencyService(repository: repo);
      final result = await service.calculate(
        referenceDate: refDate,
        targetHours: 8.0,
        overrideToday: testToday,
      );

      expect(result.totalNightsWithData, 0);
      expect(
        result.weeklyDebtMinutes,
        equals(8 * 60 * 7),
      ); // Full week, no main sleep
    });

    test('consistency is computed with available data (>= 2 nights)', () async {
      final repo = FakeSleepRecordRepository();
      repo.records = [
        SleepRecord(
          bedTime: DateTime(2025, 2, 6, 22, 0),
          wakeTime: DateTime(2025, 2, 7, 4, 0),
          quality: 'good',
          isNap: false,
        ),
        SleepRecord(
          bedTime: DateTime(2025, 2, 8, 23, 30),
          wakeTime: DateTime(2025, 2, 9, 4, 0),
          quality: 'good',
          isNap: false,
        ),
      ];
      final service = SleepDebtConsistencyService(repository: repo);
      final result = await service.calculate(
        referenceDate: refDate,
        targetHours: 8.0,
        overrideToday: testToday,
      );

      expect(result.hasEnoughDataForConsistency, isTrue);
      expect(result.consistencyScorePercent, isNotNull);
      expect(result.consistencyScorePercent, 0);
    });

    test('consistency is shown with 7 nights in the week', () async {
      final repo = FakeSleepRecordRepository();
      // 7 nights Mon Feb 3 - Sun Feb 9, all at 22:30 (±15min)
      repo.records = [
        SleepRecord(
          bedTime: DateTime(2025, 2, 3, 22, 30),
          wakeTime: DateTime(2025, 2, 4, 6, 0),
          quality: 'good',
          isNap: false,
        ),
        SleepRecord(
          bedTime: DateTime(2025, 2, 4, 22, 25),
          wakeTime: DateTime(2025, 2, 5, 6, 0),
          quality: 'good',
          isNap: false,
        ),
        SleepRecord(
          bedTime: DateTime(2025, 2, 5, 22, 35),
          wakeTime: DateTime(2025, 2, 6, 6, 0),
          quality: 'good',
          isNap: false,
        ),
        SleepRecord(
          bedTime: DateTime(2025, 2, 6, 22, 28),
          wakeTime: DateTime(2025, 2, 7, 6, 0),
          quality: 'good',
          isNap: false,
        ),
        SleepRecord(
          bedTime: DateTime(2025, 2, 7, 22, 32),
          wakeTime: DateTime(2025, 2, 8, 6, 0),
          quality: 'good',
          isNap: false,
        ),
        SleepRecord(
          bedTime: DateTime(2025, 2, 8, 22, 27),
          wakeTime: DateTime(2025, 2, 9, 6, 0),
          quality: 'good',
          isNap: false,
        ),
        SleepRecord(
          bedTime: DateTime(2025, 2, 9, 22, 31),
          wakeTime: DateTime(2025, 2, 10, 6, 0),
          quality: 'good',
          isNap: false,
        ),
      ];
      final service = SleepDebtConsistencyService(repository: repo);
      final result = await service.calculate(
        referenceDate: refDate,
        targetHours: 8.0,
        overrideToday: testToday,
      );

      expect(result.hasEnoughDataForConsistency, isTrue);
      expect(result.consistencyScorePercent, isNotNull);
      expect(result.totalNightsWithData, 7);
      expect(
        result.consistencyScorePercent,
        100,
      ); // All within ±30min of median
    });

    test('consistency ignores nights after reference date', () async {
      final repo = FakeSleepRecordRepository();
      repo.records = [
        SleepRecord(
          bedTime: DateTime(2025, 2, 3, 22, 0), // Mon
          wakeTime: DateTime(2025, 2, 4, 6, 0),
          quality: 'good',
          isNap: false,
        ),
        SleepRecord(
          bedTime: DateTime(2025, 2, 4, 22, 10), // Tue
          wakeTime: DateTime(2025, 2, 5, 6, 0),
          quality: 'good',
          isNap: false,
        ),
        SleepRecord(
          bedTime: DateTime(2025, 2, 7, 1, 0), // Fri (after ref date)
          wakeTime: DateTime(2025, 2, 7, 8, 0),
          quality: 'good',
          isNap: false,
        ),
      ];

      final service = SleepDebtConsistencyService(repository: repo);
      final result = await service.calculate(
        referenceDate: DateTime(2025, 2, 5), // Wed
        targetHours: 8.0,
        overrideToday: testToday,
      );

      expect(result.totalNightsWithData, 2);
      expect(result.hasEnoughDataForConsistency, isTrue);
      expect(result.consistencyScorePercent, 100);
    });

    test('debt resets on new week (Mon-Sun boundary)', () async {
      final repo = FakeSleepRecordRepository();
      repo.records = [
        SleepRecord(
          bedTime: DateTime(2025, 2, 8, 23, 0), // Sat Feb 8
          wakeTime: DateTime(2025, 2, 9, 7, 0), // 8h
          quality: 'good',
          isNap: false,
        ),
      ];
      final service = SleepDebtConsistencyService(repository: repo);

      // Week Feb 3-9: has 1 night with 8h. Mon-Sat missing = 6*8 = 48h debt
      final week1 = await service.calculate(
        referenceDate: DateTime(2025, 2, 9), // Sun
        targetHours: 8.0,
        overrideToday: testToday,
      );
      expect(week1.weeklyDebtMinutes, equals(6 * 8 * 60)); // 48h in minutes

      // Week Feb 10-16: new week, only Mon Feb 10 in range (ref=Feb 10, today=Feb 10)
      final week2 = await service.calculate(
        referenceDate: DateTime(2025, 2, 10), // Mon next week
        targetHours: 8.0,
        overrideToday: testToday,
      );
      expect(week2.weeklyDebtMinutes, equals(8 * 60)); // 1 day missing
    });
  });
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
}
