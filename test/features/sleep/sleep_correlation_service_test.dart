import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/sleep/data/models/sleep_record.dart';
import 'package:life_manager/features/sleep/data/repositories/sleep_record_repository.dart';
import 'package:life_manager/features/sleep/data/services/sleep_correlation_service.dart';

void main() {
  group('SleepCorrelationService', () {
    final testEnd = DateTime(2025, 2, 15);

    SleepRecord record({
      required DateTime bedTime,
      required DateTime wakeTime,
      List<String>? factors,
      int? sleepScore,
    }) {
      return SleepRecord(
        bedTime: bedTime,
        wakeTime: wakeTime,
        quality: 'good',
        isNap: false,
        factorsBeforeSleep: factors,
        sleepScore: sleepScore,
      );
    }

    test('returns hasEnoughData false when insufficient nights', () async {
      final repo = FakeSleepRecordRepository();
      for (var i = 0; i < 4; i++) {
        repo.records.add(record(
          bedTime: DateTime(2025, 2, 7 + i, 22, 0),
          wakeTime: DateTime(2025, 2, 8 + i, 6, 0),
          sleepScore: 75,
        ));
      }
      final service = SleepCorrelationService(repository: repo);
      final result = await service.getInsights(
        lookbackDays: 30,
        overrideEnd: testEnd,
      );

      expect(result.hasEnoughData, isFalse);
      expect(result.totalNightsAnalyzed, 4);
      expect(result.positive, isEmpty);
      expect(result.negative, isEmpty);
    });

    test('returns hasEnoughData true with 10+ nights and produces insights', () async {
      final repo = FakeSleepRecordRepository();
      const factorId = 'caffeine';
      // 12 nights: 6 with caffeine (score 65), 6 without (score 80)
      for (var i = 0; i < 6; i++) {
        repo.records.add(record(
          bedTime: DateTime(2025, 2, 1 + i, 22, 0),
          wakeTime: DateTime(2025, 2, 2 + i, 6, 0),
          factors: [factorId],
          sleepScore: 65,
        ));
      }
      for (var i = 0; i < 6; i++) {
        repo.records.add(record(
          bedTime: DateTime(2025, 2, 7 + i, 22, 0),
          wakeTime: DateTime(2025, 2, 8 + i, 6, 0),
          factors: null,
          sleepScore: 80,
        ));
      }
      final service = SleepCorrelationService(repository: repo);
      final result = await service.getInsights(
        lookbackDays: 30,
        overrideEnd: testEnd,
      );

      expect(result.hasEnoughData, isTrue);
      expect(result.totalNightsAnalyzed, 12);
      expect(result.negative.length, greaterThan(0));
      final caffeineInsight = result.negative.firstWhere(
        (i) => i.factorId == factorId,
        orElse: () => throw StateError('caffeine insight not found'),
      );
      expect(caffeineInsight.impactScore, lessThan(0));
      expect(caffeineInsight.countWith, 6);
      expect(caffeineInsight.countWithout, 6);
    });

    test('skips factors with fewer than 2 nights with or without', () async {
      final repo = FakeSleepRecordRepository();
      const rareFactor = 'alcohol';
      for (var i = 0; i < 12; i++) {
        final factors = (i == 0) ? [rareFactor] : null;
        repo.records.add(record(
          bedTime: DateTime(2025, 2, 1 + i, 22, 0),
          wakeTime: DateTime(2025, 2, 2 + i, 6, 0),
          factors: factors,
          sleepScore: 75,
        ));
      }
      final service = SleepCorrelationService(repository: repo);
      final result = await service.getInsights(
        lookbackDays: 30,
        overrideEnd: testEnd,
      );

      expect(result.hasEnoughData, isTrue);
      expect(result.positive, isEmpty);
      expect(result.negative, isEmpty);
      expect(result.neutral, isEmpty);
    });

    test('classifies positive impact when factor improves sleep', () async {
      final repo = FakeSleepRecordRepository();
      const factorId = 'exercise';
      for (var i = 0; i < 5; i++) {
        repo.records.add(record(
          bedTime: DateTime(2025, 2, 5 + i, 22, 0),
          wakeTime: DateTime(2025, 2, 6 + i, 6, 0),
          factors: [factorId],
          sleepScore: 85,
        ));
      }
      for (var i = 0; i < 5; i++) {
        repo.records.add(record(
          bedTime: DateTime(2025, 2, 10 + i, 22, 0),
          wakeTime: DateTime(2025, 2, 11 + i, 6, 0),
          factors: null,
          sleepScore: 70,
        ));
      }
      final service = SleepCorrelationService(repository: repo);
      final result = await service.getInsights(
        lookbackDays: 30,
        overrideEnd: testEnd,
      );

      expect(result.positive.length, greaterThan(0));
      final exerciseInsight = result.positive.firstWhere(
        (i) => i.factorId == factorId,
        orElse: () => throw StateError('exercise insight not found'),
      );
      expect(exerciseInsight.impactScore, greaterThan(0));
      expect(exerciseInsight.isPositive, isTrue);
    });

    test('excludes naps from analysis', () async {
      final repo = FakeSleepRecordRepository();
      for (var i = 0; i < 12; i++) {
        repo.records.add(SleepRecord(
          bedTime: DateTime(2025, 2, 1 + i, 22, 0),
          wakeTime: DateTime(2025, 2, 2 + i, 6, 0),
          quality: 'good',
          isNap: i < 6,
          sleepScore: 75,
        ));
      }
      final service = SleepCorrelationService(repository: repo);
      final result = await service.getInsights(
        lookbackDays: 30,
        overrideEnd: testEnd,
      );

      expect(result.totalNightsAnalyzed, 6);
      expect(result.hasEnoughData, isFalse);
    });
  });
}

class FakeSleepRecordRepository extends SleepRecordRepository {
  final List<SleepRecord> records = [];

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
