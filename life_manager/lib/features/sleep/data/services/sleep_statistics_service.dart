import '../models/sleep_record.dart';
import '../models/sleep_statistics.dart';

/// Service for Sleep Analytics and Statistics
class SleepStatisticsService {
  /// Calculate statistics for a list of sleep records
  SleepStatistics calculateStatistics(
    List<SleepRecord> records, {
    DateTime? startDate,
    DateTime? endDate,
    double? targetHours,
  }) {
    if (records.isEmpty) {
      return SleepStatistics(
        startDate: startDate ?? DateTime.now(),
        endDate: endDate ?? DateTime.now(),
        totalRecords: 0,
        averageSleepHours: 0,
        averageSleepScore: 0,
        totalSleepHours: 0,
        goodSleepDays: 0,
        poorSleepDays: 0,
        sleepEfficiency: 0,
        qualityDistribution: {},
        sleepByDayOfWeek: {},
      );
    }

    // Calculate basic metrics
    final totalHours = records.fold<double>(
      0,
      (sum, record) => sum + record.actualSleepHours,
    );

    final averageHours = totalHours / records.length;

    final totalScore = records.fold<int>(
      0,
      (sum, record) => sum + (record.sleepScore ?? record.calculateSleepScore()),
    );

    final averageScore = totalScore / records.length;

    // Count quality distribution
    final qualityDistribution = <String, int>{};
    int goodDays = 0;
    int poorDays = 0;

    for (final record in records) {
      qualityDistribution[record.quality] =
          (qualityDistribution[record.quality] ?? 0) + 1;

      if (record.quality == 'good' ||
          record.quality == 'veryGood' ||
          record.quality == 'excellent') {
        goodDays++;
      }

      if (record.quality == 'poor' || record.quality == 'fair') {
        poorDays++;
      }
    }

    // Calculate sleep efficiency
    final totalEfficiency = records.fold<double>(
      0,
      (sum, record) => sum + record.sleepEfficiency,
    );
    final averageEfficiency = totalEfficiency / records.length;

    // Calculate sleep by day of week
    final sleepByDay = <int, List<double>>{};
    for (final record in records) {
      final weekday = record.bedTime.weekday;
      sleepByDay[weekday] = (sleepByDay[weekday] ?? [])
        ..add(record.actualSleepHours);
    }

    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    final sleepByDayOfWeek = <String, double>{};
    for (int i = 1; i <= 7; i++) {
      if (sleepByDay.containsKey(i)) {
        final hours = sleepByDay[i]!;
        final avg = hours.fold<double>(0, (sum, h) => sum + h) / hours.length;
        sleepByDayOfWeek[dayNames[i - 1]] = avg;
      }
    }

    // Calculate average fall asleep time
    final fallAsleepTimes = records
        .where((r) => r.fellAsleepMinutes != null)
        .map((r) => r.fellAsleepMinutes!.toDouble())
        .toList();

    final averageFallAsleep = fallAsleepTimes.isEmpty
        ? null
        : fallAsleepTimes.fold<double>(0, (sum, t) => sum + t) /
            fallAsleepTimes.length;

    // Calculate average times awake
    final timesAwakeList = records
        .where((r) => r.timesAwake != null)
        .map((r) => r.timesAwake!.toDouble())
        .toList();

    final averageTimesAwake = timesAwakeList.isEmpty
        ? null
        : timesAwakeList.fold<double>(0, (sum, t) => sum + t) /
            timesAwakeList.length;

    // Find most common mood
    final moodCounts = <String, int>{};
    for (final record in records) {
      if (record.mood != null) {
        moodCounts[record.mood!] = (moodCounts[record.mood!] ?? 0) + 1;
      }
    }

    String? mostCommonMood;
    if (moodCounts.isNotEmpty) {
      mostCommonMood = moodCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // Find common factors
    final factorCounts = <String, int>{};
    for (final record in records) {
      if (record.factorsBeforeSleep != null) {
        for (final factor in record.factorsBeforeSleep!) {
          factorCounts[factor] = (factorCounts[factor] ?? 0) + 1;
        }
      }
    }

    final commonFactors = factorCounts.entries
        .where((e) => e.value >= records.length * 0.3) // Appears in 30%+ of records
        .map((e) => e.key)
        .toList();

    // Calculate average sleep stages (if available)
    final deepSleepHours = records
        .where((r) => r.deepSleepHours != null)
        .map((r) => r.deepSleepHours!)
        .toList();

    final averageDeepSleep = deepSleepHours.isEmpty
        ? null
        : deepSleepHours.fold<double>(0, (sum, h) => sum + h) /
            deepSleepHours.length;

    final remSleepHours = records
        .where((r) => r.remSleepHours != null)
        .map((r) => r.remSleepHours!)
        .toList();

    final averageRemSleep = remSleepHours.isEmpty
        ? null
        : remSleepHours.fold<double>(0, (sum, h) => sum + h) / remSleepHours.length;

    final lightSleepHours = records
        .where((r) => r.lightSleepHours != null)
        .map((r) => r.lightSleepHours!)
        .toList();

    final averageLightSleep = lightSleepHours.isEmpty
        ? null
        : lightSleepHours.fold<double>(0, (sum, h) => sum + h) /
            lightSleepHours.length;

    // Calculate target met (if target provided)
    int goalsMetCount = 0;
    if (targetHours != null) {
      for (final record in records) {
        final meetsTarget =
            (record.actualSleepHours - targetHours).abs() <= 0.5;
        if (meetsTarget) goalsMetCount++;
      }
    }

    final goalsMetPercentage =
        records.isEmpty ? 0.0 : (goalsMetCount / records.length * 100);

    return SleepStatistics(
      startDate: startDate ??
          records.map((r) => r.bedTime).reduce((a, b) => a.isBefore(b) ? a : b),
      endDate: endDate ??
          records.map((r) => r.bedTime).reduce((a, b) => a.isAfter(b) ? a : b),
      totalRecords: records.length,
      averageSleepHours: averageHours,
      averageSleepScore: averageScore,
      totalSleepHours: totalHours,
      goodSleepDays: goodDays,
      poorSleepDays: poorDays,
      sleepEfficiency: averageEfficiency,
      qualityDistribution: qualityDistribution,
      sleepByDayOfWeek: sleepByDayOfWeek,
      averageFallAsleepMinutes: averageFallAsleep,
      averageTimesAwake: averageTimesAwake,
      mostCommonMood: mostCommonMood,
      commonFactors: commonFactors,
      averageDeepSleep: averageDeepSleep,
      averageRemSleep: averageRemSleep,
      averageLightSleep: averageLightSleep,
      goalsMetCount: goalsMetCount,
      goalsMetPercentage: goalsMetPercentage,
    );
  }

  /// Get sleep trend for last N days
  List<Map<String, dynamic>> getSleepTrend(
    List<SleepRecord> records,
    int days,
  ) {
    final now = DateTime.now();
    final trend = <Map<String, dynamic>>[];

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = DateTime(date.year, date.month, date.day);

      final dayRecords = records.where((record) {
        final recordDate = DateTime(
          record.bedTime.year,
          record.bedTime.month,
          record.bedTime.day,
        );
        return recordDate == dateKey;
      }).toList();

      if (dayRecords.isNotEmpty) {
        final totalHours = dayRecords.fold<double>(
          0,
          (sum, record) => sum + record.actualSleepHours,
        );
        final avgHours = totalHours / dayRecords.length;

        final totalScore = dayRecords.fold<int>(
          0,
          (sum, record) =>
              sum + (record.sleepScore ?? record.calculateSleepScore()),
        );
        final avgScore = totalScore / dayRecords.length;

        trend.add({
          'date': dateKey,
          'hours': avgHours,
          'score': avgScore,
          'count': dayRecords.length,
        });
      } else {
        trend.add({
          'date': dateKey,
          'hours': 0.0,
          'score': 0,
          'count': 0,
        });
      }
    }

    return trend;
  }

  /// Calculate sleep debt for a period
  double calculateSleepDebt(
    List<SleepRecord> records, {
    double targetHours = 8.0,
  }) {
    double debt = 0.0;

    for (final record in records) {
      final deficit = targetHours - record.actualSleepHours;
      if (deficit > 0) {
        debt += deficit;
      }
    }

    return debt;
  }

  /// Get sleep recommendations based on statistics
  List<String> getRecommendations(
    SleepStatistics stats,
    List<SleepRecord> recentRecords,
  ) {
    final recommendations = <String>[];

    // Check average duration
    if (stats.averageSleepHours < 7) {
      recommendations.add(
        'Try to increase your sleep duration. You\'re averaging ${stats.formattedAverageSleep}, but 7-9 hours is recommended.',
      );
    } else if (stats.averageSleepHours > 9) {
      recommendations.add(
        'You\'re sleeping more than 9 hours on average. Consider if you might be oversleeping.',
      );
    }

    // Check efficiency
    if (stats.sleepEfficiency < 75) {
      recommendations.add(
        'Your sleep efficiency is ${stats.sleepEfficiency.toStringAsFixed(0)}%. Try to reduce time awake in bed.',
      );
    }

    // Check consistency
    if (stats.sleepByDayOfWeek.isNotEmpty) {
      final values = stats.sleepByDayOfWeek.values.toList();
      final max = values.reduce((a, b) => a > b ? a : b);
      final min = values.reduce((a, b) => a < b ? a : b);
      final variation = max - min;

      if (variation > 2) {
        recommendations.add(
          'Your sleep duration varies significantly between days. Try to maintain a consistent sleep schedule.',
        );
      }
    }

    // Check recent quality
    if (recentRecords.length >= 3) {
      final lastThree = recentRecords.take(3).toList();
      final poorQuality = lastThree.where((r) =>
          r.quality == 'poor' || r.quality == 'fair').length;

      if (poorQuality >= 2) {
        recommendations.add(
          'Your recent sleep quality has been low. Consider factors like stress, caffeine, or sleep environment.',
        );
      }
    }

    // Check common negative factors
    if (stats.commonFactors.contains('caffeine')) {
      recommendations.add(
        'Caffeine appears frequently before sleep. Try avoiding caffeine 6 hours before bed.',
      );
    }

    if (stats.commonFactors.contains('screen-time')) {
      recommendations.add(
        'Screen time before bed is common for you. Try reducing screen use 1 hour before sleep.',
      );
    }

    // Check fall asleep time
    if (stats.averageFallAsleepMinutes != null &&
        stats.averageFallAsleepMinutes! > 30) {
      recommendations.add(
        'You take an average of ${stats.averageFallAsleepMinutes!.toStringAsFixed(0)} minutes to fall asleep. Consider relaxation techniques or adjusting your bedtime routine.',
      );
    }

    // Check interruptions
    if (stats.averageTimesAwake != null && stats.averageTimesAwake! > 2) {
      recommendations.add(
        'You wake up frequently during the night. Consider optimizing your sleep environment (temperature, noise, light).',
      );
    }

    // Check sleep debt
    if (stats.sleepDebt > 10) {
      recommendations.add(
        'You have accumulated ${stats.formattedSleepDebt} of sleep debt. Try to gradually catch up on sleep.',
      );
    }

    // If everything is good
    if (recommendations.isEmpty) {
      recommendations.add(
        'Great job! Your sleep patterns are healthy. Keep maintaining your routine.',
      );
    }

    return recommendations;
  }

  /// Compare two periods
  Map<String, dynamic> comparePeriods(
    SleepStatistics current,
    SleepStatistics previous,
  ) {
    final hoursDiff = current.averageSleepHours - previous.averageSleepHours;
    final scoreDiff = current.averageSleepScore - previous.averageSleepScore;
    final efficiencyDiff = current.sleepEfficiency - previous.sleepEfficiency;

    return {
      'hoursDifference': hoursDiff,
      'hoursImproved': hoursDiff > 0,
      'scoreDifference': scoreDiff,
      'scoreImproved': scoreDiff > 0,
      'efficiencyDifference': efficiencyDiff,
      'efficiencyImproved': efficiencyDiff > 0,
      'overallImproved': hoursDiff > 0 && scoreDiff > 0,
    };
  }
}
