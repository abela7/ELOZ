/// Represents a comprehensive habit score with breakdown of all factors.
/// The score is calculated on a 0-100 scale.
class HabitScore {
  /// The habit ID this score belongs to
  final String habitId;

  /// Overall score (0-100)
  final double overallScore;

  /// Completion rate score (0-100)
  /// Based on: expected vs actual completions over the analysis period
  final double completionRateScore;

  /// Raw completion rate as percentage (0-100)
  final double completionRatePercent;

  /// Streak factor score (0-100)
  /// Based on: current streak relative to habit age and expectations
  final double streakScore;

  /// Consistency score (0-100)
  /// Based on: regularity of completions (low variance = high score)
  final double consistencyScore;

  /// Trend/momentum score (0-100, 50 = neutral)
  /// Based on: recent performance vs earlier performance
  final double trendScore;

  /// Recovery ability score (0-100)
  /// Based on: how quickly user bounces back after missing
  final double recoveryScore;

  /// Quality factor score (0-100)
  /// Based on: how close to target (for numeric/timer types)
  final double qualityScore;

  /// Number of days analyzed
  final int analysisDays;

  /// Number of expected completions in the period
  final int expectedCompletions;

  /// Number of actual completions in the period
  final int actualCompletions;

  /// Current streak
  final int currentStreak;

  /// Best streak ever
  final int bestStreak;

  /// Trend direction: 'improving', 'stable', 'declining'
  final String trendDirection;

  /// Average value achieved (for numeric habits)
  final double? averageValue;

  /// Average duration achieved (for timer habits)
  final int? averageDurationMinutes;

  /// Average completion percentage (for numeric/timer)
  final double? averageCompletionPercent;

  /// Grade letter (A+, A, B+, B, C+, C, D, F)
  final String grade;

  /// Score category label
  final String scoreLabel;

  /// Detailed insights/suggestions
  final List<String> insights;

  /// When this score was calculated
  final DateTime calculatedAt;

  const HabitScore({
    required this.habitId,
    required this.overallScore,
    required this.completionRateScore,
    required this.completionRatePercent,
    required this.streakScore,
    required this.consistencyScore,
    required this.trendScore,
    required this.recoveryScore,
    required this.qualityScore,
    required this.analysisDays,
    required this.expectedCompletions,
    required this.actualCompletions,
    required this.currentStreak,
    required this.bestStreak,
    required this.trendDirection,
    this.averageValue,
    this.averageDurationMinutes,
    this.averageCompletionPercent,
    required this.grade,
    required this.scoreLabel,
    required this.insights,
    required this.calculatedAt,
  });

  /// Create an empty/default score for new habits
  factory HabitScore.empty(String habitId) {
    return HabitScore(
      habitId: habitId,
      overallScore: 0,
      completionRateScore: 0,
      completionRatePercent: 0,
      streakScore: 0,
      consistencyScore: 0,
      trendScore: 50, // Neutral
      recoveryScore: 50, // Neutral
      qualityScore: 0,
      analysisDays: 0,
      expectedCompletions: 0,
      actualCompletions: 0,
      currentStreak: 0,
      bestStreak: 0,
      trendDirection: 'stable',
      grade: 'N/A',
      scoreLabel: 'Not enough data',
      insights: ['Complete your habit a few times to see your score!'],
      calculatedAt: DateTime.now(),
    );
  }

  /// Get grade from overall score
  static String getGrade(double score) {
    if (score >= 97) return 'A+';
    if (score >= 93) return 'A';
    if (score >= 90) return 'A-';
    if (score >= 87) return 'B+';
    if (score >= 83) return 'B';
    if (score >= 80) return 'B-';
    if (score >= 77) return 'C+';
    if (score >= 73) return 'C';
    if (score >= 70) return 'C-';
    if (score >= 67) return 'D+';
    if (score >= 63) return 'D';
    if (score >= 60) return 'D-';
    return 'F';
  }

  /// Get score label from overall score
  static String getScoreLabel(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 80) return 'Great';
    if (score >= 70) return 'Good';
    if (score >= 60) return 'Fair';
    if (score >= 50) return 'Needs Work';
    if (score >= 30) return 'Struggling';
    return 'Just Starting';
  }

  /// Get color value for the score (for UI)
  int get scoreColorValue {
    if (overallScore >= 90) return 0xFF4CAF50; // Green
    if (overallScore >= 80) return 0xFF8BC34A; // Light Green
    if (overallScore >= 70) return 0xFFCDDC39; // Lime
    if (overallScore >= 60) return 0xFFFFEB3B; // Yellow
    if (overallScore >= 50) return 0xFFFFC107; // Amber
    if (overallScore >= 30) return 0xFFFF9800; // Orange
    return 0xFFF44336; // Red
  }

  /// Check if score is considered good (70+)
  bool get isGood => overallScore >= 70;

  /// Check if score needs improvement (<60)
  bool get needsImprovement => overallScore < 60;

  /// Check if trend is positive
  bool get isImproving => trendDirection == 'improving';

  /// Check if trend is negative
  bool get isDeclining => trendDirection == 'declining';

  /// Get progress percentage (same as overall score but clamped)
  double get progressPercent => overallScore.clamp(0, 100);

  /// Get a short summary string
  String get shortSummary {
    return '$grade - ${overallScore.toStringAsFixed(0)}% ($scoreLabel)';
  }

  /// Get streak health (current vs best)
  double get streakHealth {
    if (bestStreak == 0) return 0;
    return (currentStreak / bestStreak * 100).clamp(0, 100);
  }

  /// Export to JSON for debugging/analytics
  Map<String, dynamic> toJson() {
    return {
      'habitId': habitId,
      'overallScore': overallScore,
      'completionRateScore': completionRateScore,
      'completionRatePercent': completionRatePercent,
      'streakScore': streakScore,
      'consistencyScore': consistencyScore,
      'trendScore': trendScore,
      'recoveryScore': recoveryScore,
      'qualityScore': qualityScore,
      'analysisDays': analysisDays,
      'expectedCompletions': expectedCompletions,
      'actualCompletions': actualCompletions,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'trendDirection': trendDirection,
      'averageValue': averageValue,
      'averageDurationMinutes': averageDurationMinutes,
      'averageCompletionPercent': averageCompletionPercent,
      'grade': grade,
      'scoreLabel': scoreLabel,
      'insights': insights,
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }
}

/// Configuration for score calculation weights
class HabitScoreWeights {
  /// Weight for completion rate (default: 35%)
  final double completionRate;

  /// Weight for streak factor (default: 25%)
  final double streak;

  /// Weight for consistency (default: 20%)
  final double consistency;

  /// Weight for trend/momentum (default: 10%)
  final double trend;

  /// Weight for recovery ability (default: 5%)
  final double recovery;

  /// Weight for quality factor (default: 5%)
  final double quality;

  const HabitScoreWeights({
    this.completionRate = 0.35,
    this.streak = 0.25,
    this.consistency = 0.20,
    this.trend = 0.10,
    this.recovery = 0.05,
    this.quality = 0.05,
  });

  /// Verify weights sum to 1.0
  bool get isValid {
    final sum = completionRate + streak + consistency + trend + recovery + quality;
    return (sum - 1.0).abs() < 0.01;
  }

  /// Default weights optimized for habit building
  static const HabitScoreWeights defaultWeights = HabitScoreWeights();

  /// Weights emphasizing consistency for established habits
  static const HabitScoreWeights consistencyFocused = HabitScoreWeights(
    completionRate: 0.30,
    streak: 0.20,
    consistency: 0.30,
    trend: 0.10,
    recovery: 0.05,
    quality: 0.05,
  );

  /// Weights emphasizing completion for new habits
  static const HabitScoreWeights completionFocused = HabitScoreWeights(
    completionRate: 0.45,
    streak: 0.25,
    consistency: 0.15,
    trend: 0.10,
    recovery: 0.03,
    quality: 0.02,
  );
}
