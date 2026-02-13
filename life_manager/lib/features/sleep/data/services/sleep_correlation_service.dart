import '../models/sleep_correlation_insight.dart';
import '../models/sleep_record.dart';
import '../repositories/sleep_record_repository.dart';

/// Service for computing pre-sleep factor correlation insights.
/// Compares sleep quality/duration on nights WITH vs WITHOUT each factor.
class SleepCorrelationService {
  static const int _defaultLookbackDays = 30;
  static const int _minWith = 2;
  static const int _minWithout = 2;
  static const int _minTotalNights = 10;
  static const double _meaningfulScoreImpact = 3.0;
  static const double _meaningfulHoursImpact = 0.25;

  final SleepRecordRepository _repository;

  SleepCorrelationService({required SleepRecordRepository repository})
      : _repository = repository;

  /// Compute correlation insights for a date range.
  /// Provide [startDate] and [endDate] for period-based reports (week, month, etc.).
  /// Or use [lookbackDays] + [overrideEnd] for "last N days".
  Future<SleepCorrelationInsights> getInsights({
    DateTime? startDate,
    DateTime? endDate,
    int lookbackDays = _defaultLookbackDays,
    DateTime? overrideEnd,
  }) async {
    DateTime start;
    DateTime end;
    if (startDate != null && endDate != null) {
      start = DateTime(startDate.year, startDate.month, startDate.day);
      end = DateTime(endDate.year, endDate.month, endDate.day);
    } else {
      end = overrideEnd ?? DateTime.now();
      start = end.subtract(Duration(days: lookbackDays));
      start = DateTime(start.year, start.month, start.day);
      end = DateTime(end.year, end.month, end.day);
    }

    final allRecords =
        await _repository.getMainSleepByDateRange(start, end);

    final records = allRecords
        .where((r) =>
            (r.sleepScore != null || r.calculateSleepScore() >= 0) &&
            r.actualSleepHours > 0)
        .toList();

    final minNights = _minNightsForRange(start, end);
    final nightsWithFactors =
        records.where((r) =>
            r.factorsBeforeSleep != null && r.factorsBeforeSleep!.isNotEmpty).length;

    if (records.length < minNights) {
      return SleepCorrelationInsights(
        positive: [],
        negative: [],
        neutral: [],
        hasEnoughData: false,
        totalNightsAnalyzed: records.length,
        nightsWithFactors: nightsWithFactors,
        rangeStart: start,
        rangeEnd: end,
      );
    }

    final allFactorIds = <String>{};
    for (final r in records) {
      if (r.factorsBeforeSleep != null) {
        allFactorIds.addAll(r.factorsBeforeSleep!);
      }
    }

    final insights = <FactorCorrelationInsight>[];
    for (final fid in allFactorIds) {
      final withFactor = <SleepRecord>[];
      final withoutFactor = <SleepRecord>[];
      for (final r in records) {
        final hasFactor =
            r.factorsBeforeSleep != null && r.factorsBeforeSleep!.contains(fid);
        if (hasFactor) {
          withFactor.add(r);
        } else {
          withoutFactor.add(r);
        }
      }

      if (withFactor.length < _minWith || withoutFactor.length < _minWithout) {
        continue;
      }

      final scoreWith = _avgScore(withFactor);
      final scoreWithout = _avgScore(withoutFactor);
      final hoursWith = _avgHours(withFactor);
      final hoursWithout = _avgHours(withoutFactor);
      final impactScore = scoreWith - scoreWithout;
      final impactHours = hoursWith - hoursWithout;

      insights.add(FactorCorrelationInsight(
        factorId: fid,
        impactScore: impactScore,
        impactHours: impactHours,
        countWith: withFactor.length,
        countWithout: withoutFactor.length,
        avgScoreWith: scoreWith,
        avgScoreWithout: scoreWithout,
        avgHoursWith: hoursWith,
        avgHoursWithout: hoursWithout,
      ));
    }

    final meaningful = insights
        .where((i) =>
            i.impactScore.abs() >= _meaningfulScoreImpact ||
            i.impactHours.abs() >= _meaningfulHoursImpact)
        .toList()
      ..sort((a, b) {
        final aMag = a.impactScore.abs() + a.impactHours.abs() * 10;
        final bMag = b.impactScore.abs() + b.impactHours.abs() * 10;
        return bMag.compareTo(aMag);
      });

    final positive = meaningful.where((i) => i.isPositive).toList();
    final negative = meaningful.where((i) => i.isNegative).toList();
    final neutral = insights
        .where((i) =>
            !meaningful.contains(i) &&
            i.impactScore.abs() < _meaningfulScoreImpact &&
            i.impactHours.abs() < _meaningfulHoursImpact)
        .toList();

    return SleepCorrelationInsights(
      positive: positive.take(5).toList(),
      negative: negative.take(5).toList(),
      neutral: neutral,
      hasEnoughData: true,
      totalNightsAnalyzed: records.length,
      nightsWithFactors: nightsWithFactors,
      rangeStart: start,
      rangeEnd: end,
    );
  }

  int _minNightsForRange(DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;
    if (days <= 7) return 5;
    if (days <= 31) return 7;
    return _minTotalNights;
  }

  double _avgScore(List<SleepRecord> records) {
    if (records.isEmpty) return 0;
    var sum = 0.0;
    for (final r in records) {
      sum += (r.sleepScore ?? r.calculateSleepScore()).toDouble();
    }
    return sum / records.length;
  }

  double _avgHours(List<SleepRecord> records) {
    if (records.isEmpty) return 0;
    return records.fold<double>(0, (s, r) => s + r.actualSleepHours) /
        records.length;
  }
}
