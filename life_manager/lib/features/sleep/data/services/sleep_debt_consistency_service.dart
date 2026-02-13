import '../models/sleep_debt_consistency.dart';
import '../repositories/sleep_record_repository.dart';

/// Service for Sleep Debt and Bedtime Consistency (Phase 1)
///
/// Product rules:
/// - Only main sleep (isNap=false) counts for debt.
/// - Missing night = full target hours as debt.
/// - 7-day window: Mon-Sun week containing reference date.
/// - Debt is cumulative from Monday through reference date (ongoing within week).
/// - When moving to next week (e.g. Mon), debt resets for the new week.
/// - Consistency: % of nights within ±30min of median bedtime.
/// - Need >= 2 main sleeps to show consistency.
class SleepDebtConsistencyService {
  static const int _consistencyWindowMinutes = 30;
  static const int _minNightsForConsistency = 2;
  static const int _debtWindowDays = 7;

  final SleepRecordRepository _repository;

  SleepDebtConsistencyService({required SleepRecordRepository repository})
      : _repository = repository;

  /// Returns Monday (00:00) of the week containing [date]. Week = Mon-Sun.
  static DateTime _mondayOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    // weekday: 1=Mon, 7=Sun
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// Calculate debt and consistency for the Mon-Sun week containing
  /// [referenceDate]. Debt accumulates from Monday through reference date only.
  /// [overrideToday] can be set in tests for deterministic behavior.
  Future<SleepDebtConsistency> calculate({
    required DateTime referenceDate,
    required double targetHours,
    DateTime? overrideToday,
  }) async {
    final now = overrideToday ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ref = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final weekMonday = _mondayOfWeek(ref);
    final weekSunday = weekMonday.add(const Duration(days: _debtWindowDays - 1));

    final mainSleep = await _repository.getMainSleepByDateRange(weekMonday, weekSunday);

    // Store actual sleep in minutes per date for precise debt calculation.
    final targetMinutes = (targetHours * 60).round();
    final Map<DateTime, int> minutesByDate = {};
    for (final r in mainSleep) {
      final d = DateTime(r.bedTime.year, r.bedTime.month, r.bedTime.day);
      final mins = (r.actualSleepHours * 60).round();
      minutesByDate[d] = (minutesByDate[d] ?? 0) + mins;
    }

    int weeklyDebtMinutes = 0;
    int? dailyDebtMinutes;

    // Only count days from Monday through reference date (ongoing within week).
    // Future days are never counted (no data yet).
    for (int i = 0; i < _debtWindowDays; i++) {
      final d = weekMonday.add(Duration(days: i));
      if (d.isAfter(ref)) break; // Stop at reference date
      if (d.isAfter(today)) break; // Never count future days

      final dayMins = minutesByDate[d] ?? 0;

      if (dayMins > 0) {
        final deficit = targetMinutes - dayMins;
        final debt = deficit > 0 ? deficit : 0;
        weeklyDebtMinutes += debt;
        if (d == ref) {
          dailyDebtMinutes = debt;
        }
      } else {
        weeklyDebtMinutes += targetMinutes;
        if (d == ref) {
          dailyDebtMinutes = targetMinutes;
        }
      }
    }

    int consistencyScore = 0;
    int nightsInWindow = 0;
    final bedtimeByDate = <DateTime, int>{};
    for (final r in mainSleep) {
      final d = DateTime(r.bedTime.year, r.bedTime.month, r.bedTime.day);
      // Consistency is rolling within the selected week and reference date.
      if (d.isAfter(ref) || d.isAfter(today)) continue;
      bedtimeByDate[d] = r.bedTime.hour * 60 + r.bedTime.minute;
    }
    final bedtimes = bedtimeByDate.values.toList()..sort();

    if (bedtimes.length >= _minNightsForConsistency) {
      final median = _median(bedtimes);
      for (final mins in bedtimeByDate.values) {
        final dist = (mins - median).abs();
        final wrapped = dist > 12 * 60 ? (24 * 60 - dist) : dist;
        if (wrapped <= _consistencyWindowMinutes) {
          nightsInWindow++;
        }
      }
      consistencyScore = ((nightsInWindow / bedtimes.length) * 100).round();
    }

    return SleepDebtConsistency(
      dailyDebtMinutes: dailyDebtMinutes,
      weeklyDebtMinutes: weeklyDebtMinutes,
      consistencyScorePercent:
          bedtimes.length >= _minNightsForConsistency ? consistencyScore : null,
      nightsInWindow: nightsInWindow,
      totalNightsWithData: bedtimeByDate.length,
      hasEnoughDataForConsistency: bedtimes.length >= _minNightsForConsistency,
      referenceDate: ref,
      targetHours: targetHours,
    );
  }

  static double _median(List<int> sorted) {
    if (sorted.isEmpty) return 0;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid].toDouble();
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
