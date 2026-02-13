/// Correlation insight for a single pre-sleep factor.
/// Shows how nights with this factor compare to nights without.
class FactorCorrelationInsight {
  final String factorId;
  final double impactScore; // avgScoreWith - avgScoreWithout (positive = factor helps)
  final double impactHours; // avgHoursWith - avgHoursWithout
  final int countWith;
  final int countWithout;
  final double avgScoreWith;
  final double avgScoreWithout;
  final double avgHoursWith;
  final double avgHoursWithout;

  const FactorCorrelationInsight({
    required this.factorId,
    required this.impactScore,
    required this.impactHours,
    required this.countWith,
    required this.countWithout,
    required this.avgScoreWith,
    required this.avgScoreWithout,
    required this.avgHoursWith,
    required this.avgHoursWithout,
  });

  bool get isPositive => impactScore > 0 || impactHours > 0;
  bool get isNegative => impactScore < 0 || impactHours < 0;
  bool get hasMeaningfulImpact =>
      impactScore.abs() >= 3 || impactHours.abs() >= 0.25;

  /// Human-readable message for the insight.
  String message(String factorName) {
    if (impactScore.abs() >= impactHours.abs() * 10) {
      // Score dominates
      final pts = impactScore.round().abs();
      if (impactScore > 0) {
        return 'On nights with $factorName, your score is +$pts points higher.';
      }
      return 'On nights with $factorName, your score is $pts points lower.';
    }
    // Hours dominate or similar
    final h = impactHours.abs();
    if (h >= 1) {
      final hrs = h.floor();
      final mins = ((h % 1) * 60).round();
      final dur = mins > 0 ? '$hrs h $mins m' : '$hrs h';
      if (impactHours > 0) {
        return 'On nights with $factorName, you sleep $dur more on average.';
      }
      return 'On nights with $factorName, you sleep $dur less on average.';
    }
    final mins = (h * 60).round();
    if (impactHours > 0) {
      return 'On nights with $factorName, you sleep $mins min more on average.';
    }
    return 'On nights with $factorName, you sleep $mins min less on average.';
  }
}

/// Container for all factor correlation insights.
class SleepCorrelationInsights {
  final List<FactorCorrelationInsight> positive;
  final List<FactorCorrelationInsight> negative;
  final List<FactorCorrelationInsight> neutral;
  final bool hasEnoughData;
  final int totalNightsAnalyzed;
  final int nightsWithFactors;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  const SleepCorrelationInsights({
    required this.positive,
    required this.negative,
    required this.neutral,
    required this.hasEnoughData,
    required this.totalNightsAnalyzed,
    this.nightsWithFactors = 0,
    this.rangeStart,
    this.rangeEnd,
  });

  static const int minNightsForInsight = 10;
  static const int minWithPerFactor = 2;
  static const int minWithoutPerFactor = 2;
}
