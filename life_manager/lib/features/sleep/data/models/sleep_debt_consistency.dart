/// DTO for Sleep Debt + Consistency Tracking (Phase 1)
///
/// Product rules:
/// - Debt: only main sleep (isNap=false) counts. Missing night = full target.
/// - 7-day window: Mon-Sun week containing reference date.
/// - Debt accumulates from Monday through reference date only (ongoing).
/// - Consistency: % of nights within ±30min of median bedtime; min 2 nights.
class SleepDebtConsistency {
  /// Debt for the selected/reference date's night (minutes). Null when future.
  final int? dailyDebtMinutes;

  /// Cumulative debt over the 7-day window (minutes). Used for exact formatting.
  final int weeklyDebtMinutes;

  /// Consistency score 0-100. Null when insufficient data (< 2 main sleeps).
  final int? consistencyScorePercent;

  /// Number of nights within bedtime window.
  final int nightsInWindow;

  /// Total main sleep nights in the 7-day window.
  final int totalNightsWithData;

  /// Whether we have enough data to show consistency (>= 2 main sleeps).
  final bool hasEnoughDataForConsistency;

  /// Reference date for the 7-day window end.
  final DateTime referenceDate;

  /// Target hours used for debt calculation.
  final double targetHours;

  const SleepDebtConsistency({
    this.dailyDebtMinutes,
    required this.weeklyDebtMinutes,
    this.consistencyScorePercent,
    required this.nightsInWindow,
    required this.totalNightsWithData,
    required this.hasEnoughDataForConsistency,
    required this.referenceDate,
    required this.targetHours,
  });

  /// Formatted 7-day debt string (e.g. "2h 30m" or "0h 0m").
  String get formattedWeeklyDebt {
    if (weeklyDebtMinutes <= 0) return '0h 0m';
    final h = weeklyDebtMinutes ~/ 60;
    final m = weeklyDebtMinutes % 60;
    return '${h}h ${m}m';
  }

  /// Formatted daily debt string.
  String get formattedDailyDebt {
    if (dailyDebtMinutes == null) return '—';
    if (dailyDebtMinutes! <= 0) return '0h 0m';
    final h = dailyDebtMinutes! ~/ 60;
    final m = dailyDebtMinutes! % 60;
    return '${h}h ${m}m';
  }

  /// Whether user is in debt (weekly > 0).
  bool get hasDebt => weeklyDebtMinutes > 0;

  /// Consistency label for UI (e.g. "71% consistent").
  String get consistencyLabel {
    if (!hasEnoughDataForConsistency) return 'Insufficient data';
    if (consistencyScorePercent == null) return 'Insufficient data';
    return '$consistencyScorePercent% consistent';
  }
}
