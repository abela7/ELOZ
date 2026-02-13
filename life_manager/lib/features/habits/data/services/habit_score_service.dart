import 'dart:math' as math;
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_score.dart';
import '../repositories/habit_repository.dart';

/// Service for calculating comprehensive habit scores.
/// 
/// The scoring algorithm considers multiple factors:
/// - **Completion Rate (35%)**: Expected vs actual completions
/// - **Streak Factor (25%)**: Current streak health and consistency
/// - **Consistency (20%)**: Regularity of completions (low variance)
/// - **Trend (10%)**: Recent performance vs historical performance
/// - **Recovery (5%)**: Ability to bounce back after missing
/// - **Quality (5%)**: How close to target (numeric/timer types)
class HabitScoreService {
  final HabitRepository _repository;

  /// Default analysis period in days
  static const int defaultAnalysisDays = 30;

  /// Minimum days needed for accurate scoring
  static const int minimumDaysForScore = 3;

  HabitScoreService(this._repository);

  /// Calculate comprehensive score for a habit
  /// 
  /// [habit] - The habit to score
  /// [analysisDays] - Number of days to analyze (default: 30)
  /// [weights] - Custom weights for scoring factors
  Future<HabitScore> calculateScore(
    Habit habit, {
    int analysisDays = defaultAnalysisDays,
    HabitScoreWeights weights = HabitScoreWeights.defaultWeights,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Adjust analysis period based on habit age
    final habitAge = today.difference(habit.startDate).inDays + 1;
    final effectiveAnalysisDays = math.min(analysisDays, habitAge);
    
    // Not enough data for scoring
    if (effectiveAnalysisDays < minimumDaysForScore) {
      return HabitScore.empty(habit.id);
    }

    final startDate = today.subtract(Duration(days: effectiveAnalysisDays - 1));
    final endDate = today;

    // Get all completions for the period
    final completions = await _repository.getCompletionsInRange(
      habit.id,
      startDate,
      endDate,
    );

    // Calculate expected completions based on frequency
    final expectedCompletions = _calculateExpectedCompletions(
      habit, 
      startDate, 
      endDate,
    );

    // Calculate actual completions
    final actualCompletions = _countActualCompletions(completions, habit);

    // Calculate individual scores
    final completionRateScore = _calculateCompletionRateScore(
      actualCompletions, 
      expectedCompletions,
    );
    final completionRatePercent = expectedCompletions > 0
        ? (actualCompletions / expectedCompletions * 100).clamp(0.0, 100.0)
        : 0.0;
    final effectiveWeights = _getEffectiveWeights(habit, weights);

    final streakScore = _calculateStreakScore(
      habit, 
      effectiveAnalysisDays,
    );

    final consistencyScore = _calculateConsistencyScore(
      completions, 
      habit,
      expectedCompletions: expectedCompletions,
      actualCompletions: actualCompletions,
    );

    final (trendScore, trendDirection) = _calculateTrendScore(
      completions, 
      habit,
      startDate,
      endDate,
    );

    final recoveryScore = _calculateRecoveryScore(
      completions, 
      habit, 
      startDate, 
      endDate,
    );

    final (qualityScore, avgValue, avgDuration, avgPercent) = 
        _calculateQualityScore(
          completions,
          habit,
          completionRatePercent: completionRatePercent,
        );

    // Calculate weighted overall score
    final overallScore = (
      completionRateScore * effectiveWeights.completionRate +
      streakScore * effectiveWeights.streak +
      consistencyScore * effectiveWeights.consistency +
      trendScore * effectiveWeights.trend +
      recoveryScore * effectiveWeights.recovery +
      qualityScore * effectiveWeights.quality
    ).clamp(0.0, 100.0);

    // Generate insights
    final insights = _generateInsights(
      habit: habit,
      completionRateScore: completionRateScore,
      streakScore: streakScore,
      consistencyScore: consistencyScore,
      trendScore: trendScore,
      trendDirection: trendDirection,
      recoveryScore: recoveryScore,
      qualityScore: qualityScore,
      actualCompletions: actualCompletions,
      expectedCompletions: expectedCompletions,
    );

    return HabitScore(
      habitId: habit.id,
      overallScore: overallScore,
      completionRateScore: completionRateScore,
      completionRatePercent: completionRatePercent,
      streakScore: streakScore,
      consistencyScore: consistencyScore,
      trendScore: trendScore,
      recoveryScore: recoveryScore,
      qualityScore: qualityScore,
      analysisDays: effectiveAnalysisDays,
      expectedCompletions: expectedCompletions,
      actualCompletions: actualCompletions,
      currentStreak: habit.currentStreak,
      bestStreak: habit.bestStreak,
      trendDirection: trendDirection,
      averageValue: avgValue,
      averageDurationMinutes: avgDuration,
      averageCompletionPercent: avgPercent,
      grade: HabitScore.getGrade(overallScore),
      scoreLabel: HabitScore.getScoreLabel(overallScore),
      insights: insights,
      calculatedAt: DateTime.now(),
    );
  }

  /// Calculate expected completions based on habit frequency
  int _calculateExpectedCompletions(
    Habit habit,
    DateTime startDate,
    DateTime endDate,
  ) {
    final totalDays = endDate.difference(startDate).inDays + 1;

    switch (habit.frequencyType) {
      case 'daily':
        return totalDays;

      case 'weekly':
        if (habit.weekDays == null || habit.weekDays!.isEmpty) {
          return totalDays ~/ 7;
        }
        int count = 0;
        for (int i = 0; i < totalDays; i++) {
          final date = startDate.add(Duration(days: i));
          final weekday = date.weekday % 7; // 0 = Sunday
          if (habit.weekDays!.contains(weekday)) {
            count++;
          }
        }
        return count;

      case 'xTimesPerWeek':
        final weeks = totalDays / 7;
        return (weeks * habit.targetCount).ceil();

      case 'xTimesPerMonth':
        final months = totalDays / 30;
        return (months * habit.targetCount).ceil();

      case 'custom':
        if (habit.frequencyPeriod != null) {
          switch (habit.frequencyPeriod) {
            case 'day':
              return totalDays * habit.targetCount;
            case 'week':
              final weeks = totalDays / 7;
              return (weeks * habit.targetCount).ceil();
            case 'month':
              final months = totalDays / 30;
              return (months * habit.targetCount).ceil();
            case 'year':
              final years = totalDays / 365;
              return (years * habit.targetCount).ceil();
          }
        }
        if (habit.customIntervalDays != null && habit.customIntervalDays! > 0) {
          return totalDays ~/ habit.customIntervalDays!;
        }
        return totalDays;

      default:
        return totalDays;
    }
  }

  /// Count actual completions from completion records
  int _countActualCompletions(List<HabitCompletion> completions, Habit habit) {
    int count = 0;
    
    for (final completion in completions) {
      if (_isSuccessfulCompletion(completion, habit)) {
        count++;
      }
    }
    
    return count;
  }

  /// Calculate completion rate score (0-100)
  double _calculateCompletionRateScore(int actual, int expected) {
    if (expected == 0) return 0;

    // Keep this linear and transparent: if completion is 10%, score is 10.
    return (actual / expected * 100).clamp(0.0, 100.0);
  }

  /// Calculate streak score (0-100)
  double _calculateStreakScore(Habit habit, int analysisDays) {
    if (habit.currentStreak == 0 && habit.bestStreak == 0) {
      return 0;
    }

    // Factor 1: Current streak as percentage of analysis period
    // A streak covering the whole analysis period is perfect
    final periodCoverage = (habit.currentStreak / analysisDays * 100).clamp(0.0, 100.0);

    // Factor 2: Current streak vs best streak (streak health)
    double streakHealth = 0;
    if (habit.bestStreak > 0) {
      streakHealth = (habit.currentStreak / habit.bestStreak * 100).clamp(0.0, 100.0);
    } else if (habit.currentStreak > 0) {
      streakHealth = 100; // First streak is healthy
    }

    // Factor 3: Bonus for long streaks (> 7 days)
    double longStreakBonus = 0;
    if (habit.currentStreak >= 30) {
      longStreakBonus = 20;
    } else if (habit.currentStreak >= 21) {
      longStreakBonus = 15;
    } else if (habit.currentStreak >= 14) {
      longStreakBonus = 10;
    } else if (habit.currentStreak >= 7) {
      longStreakBonus = 5;
    }

    // Weighted combination
    final baseScore = periodCoverage * 0.4 + streakHealth * 0.6;
    final score = baseScore + longStreakBonus;

    return score.clamp(0.0, 100.0);
  }

  /// Calculate consistency score based on completion regularity (0-100)
  double _calculateConsistencyScore(
    List<HabitCompletion> completions,
    Habit habit,
    {required int expectedCompletions, required int actualCompletions}
  ) {
    if (expectedCompletions <= 0) return 0;

    final adherenceScore =
        (actualCompletions / expectedCompletions * 100).clamp(0.0, 100.0).toDouble();
    if (completions.isEmpty) return adherenceScore * 0.2;

    // Get valid completion dates
    final completionDates = completions
        .where((c) => _isSuccessfulCompletion(c, habit))
        .map((c) => DateTime(
              c.completedDate.year,
              c.completedDate.month,
              c.completedDate.day,
            ))
        .toSet()
        .toList();

    if (completionDates.isEmpty) return 0;
    if (completionDates.length < 2) return (adherenceScore * 0.9 + 10).clamp(0.0, 100.0);

    completionDates.sort();

    // Calculate gaps between completions
    final gaps = <int>[];
    for (int i = 1; i < completionDates.length; i++) {
      final gap = completionDates[i].difference(completionDates[i - 1]).inDays;
      gaps.add(gap);
    }

    final expectedGap = _expectedGapDays(habit);

    // Calculate standard deviation of gaps
    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    final variance = gaps.map((g) => math.pow(g - avgGap, 2)).reduce((a, b) => a + b) / gaps.length;
    final stdDev = math.sqrt(variance);

    // Score based on how close average gap is to expected.
    final gapDeviationFromExpected = (avgGap - expectedGap).abs();
    final gapScore = (100 - (gapDeviationFromExpected / expectedGap * 100))
        .clamp(0.0, 100.0)
        .toDouble();

    // Score based on low standard deviation (regularity).
    final regularityScore = (100 - (stdDev / expectedGap * 100))
        .clamp(0.0, 100.0)
        .toDouble();

    // Timing quality inside the completions that did happen.
    double timingScore = gapScore * 0.5 + regularityScore * 0.5;

    // For weekly habits with explicit weekdays, reward hitting planned weekdays.
    if (habit.frequencyType == 'weekly' &&
        habit.weekDays != null &&
        habit.weekDays!.isNotEmpty) {
      final scheduledHits = completionDates
          .where((d) => habit.weekDays!.contains(d.weekday % 7))
          .length;
      final weekdayAlignment = (scheduledHits / completionDates.length * 100)
          .clamp(0.0, 100.0)
          .toDouble();
      timingScore = timingScore * 0.7 + weekdayAlignment * 0.3;
    }

    // Type-specific consistency for target-based habits.
    if (habit.completionType == 'numeric' || habit.completionType == 'timer') {
      final targetConsistency = _calculateTargetConsistency(completions, habit);
      return (adherenceScore * 0.55 + timingScore * 0.25 + targetConsistency * 0.20)
          .clamp(0.0, 100.0);
    }

    if (habit.completionType == 'quit') {
      return (adherenceScore * 0.8 + timingScore * 0.2).clamp(0.0, 100.0);
    }

    return (adherenceScore * 0.7 + timingScore * 0.3).clamp(0.0, 100.0);
  }

  /// Calculate trend score (0-100, 50 = neutral) and direction
  (double, String) _calculateTrendScore(
    List<HabitCompletion> completions,
    Habit habit,
    DateTime startDate,
    DateTime endDate,
  ) {
    final analysisDays = endDate.difference(startDate).inDays + 1;
    if (completions.isEmpty || analysisDays < 14) {
      return (50.0, 'stable'); // Not enough data for trend
    }
    
    // Split into two periods
    final midpoint = analysisDays ~/ 2;
    final earlierStart = startDate;
    final earlierEnd = startDate.add(Duration(days: midpoint - 1));
    final recentStart = earlierEnd.add(const Duration(days: 1));
    final recentEnd = endDate;
    
    // Count completions in each period
    int recentCount = 0;
    int earlierCount = 0;

    for (final completion in completions) {
      if (!_isSuccessfulCompletion(completion, habit)) continue;

      if (_isDateInRange(completion.completedDate, recentStart, recentEnd)) {
        recentCount++;
      } else if (_isDateInRange(completion.completedDate, earlierStart, earlierEnd)) {
        earlierCount++;
      }
    }

    // Calculate expected completions per period.
    final expectedEarlier = _calculateExpectedCompletions(
      habit,
      earlierStart,
      earlierEnd,
    );
    final expectedRecent = _calculateExpectedCompletions(
      habit,
      recentStart,
      recentEnd,
    );

    // Calculate rates
    final recentRate = expectedRecent > 0 ? recentCount / expectedRecent : 0.0;
    final earlierRate = expectedEarlier > 0 ? earlierCount / expectedEarlier : 0.0;

    // Calculate trend
    double trendScore;
    String direction;

    if (earlierRate == 0 && recentRate == 0) {
      trendScore = 50;
      direction = 'stable';
    } else if (earlierRate == 0) {
      trendScore = 75; // Improvement from nothing
      direction = 'improving';
    } else {
      final improvement = (recentRate - earlierRate) / earlierRate;
      
      if (improvement > 0.1) {
        // Improving: score 50-100 based on improvement magnitude
        trendScore = 50 + (improvement * 100).clamp(0, 50);
        direction = 'improving';
      } else if (improvement < -0.1) {
        // Declining: score 0-50 based on decline magnitude
        trendScore = 50 + (improvement * 100).clamp(-50, 0);
        direction = 'declining';
      } else {
        trendScore = 50;
        direction = 'stable';
      }
    }

    return (trendScore.clamp(0.0, 100.0), direction);
  }

  /// Calculate recovery score based on bounce-back after misses (0-100)
  double _calculateRecoveryScore(
    List<HabitCompletion> completions,
    Habit habit,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (completions.isEmpty) return 0;

    // Build a map of dates to completion status
    final completionMap = <DateTime, bool>{};
    for (final completion in completions) {
      final date = DateTime(
        completion.completedDate.year,
        completion.completedDate.month,
        completion.completedDate.day,
      );
      final isSuccess = _isSuccessfulCompletion(completion, habit);
      completionMap[date] = (completionMap[date] ?? false) || isSuccess;
    }

    // For daily habits, count bouncebacks
    if (habit.frequencyType == 'daily') {
      int missedDays = 0;
      int bouncebacks = 0;
      
      final totalDays = endDate.difference(startDate).inDays + 1;
      
      for (int i = 0; i < totalDays - 1; i++) {
        final date = startDate.add(Duration(days: i));
        final nextDate = date.add(const Duration(days: 1));
        
        final wasCompleted = completionMap[date] ?? false;
        final nextCompleted = completionMap[nextDate] ?? false;
        
        if (!wasCompleted) {
          missedDays++;
          if (nextCompleted) {
            bouncebacks++;
          }
        }
      }

      if (missedDays == 0) {
        return 100; // Perfect record, no misses
      }

      // Score based on bounceback rate
      final bouncebackRate = bouncebacks / missedDays;
      return (bouncebackRate * 100).clamp(0.0, 100.0);
    }

    // Non-daily: use a frequency-aware gap penalty model.
    final successfulDates = completions
        .where((c) => _isSuccessfulCompletion(c, habit))
        .map((c) => DateTime(
              c.completedDate.year,
              c.completedDate.month,
              c.completedDate.day,
            ))
        .toSet()
        .toList()
      ..sort();

    if (successfulDates.length < 2) return 0;

    final expectedGap = _expectedGapDays(habit);
    final gaps = <double>[];
    for (int i = 1; i < successfulDates.length; i++) {
      gaps.add(successfulDates[i]
          .difference(successfulDates[i - 1])
          .inDays
          .toDouble());
    }

    if (gaps.isEmpty) return 0;
    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    final excessRatio =
        ((avgGap - expectedGap) / expectedGap).clamp(0.0, 3.0).toDouble();
    return (100 - excessRatio * 40).clamp(0.0, 100.0);
  }

  /// Calculate quality score for numeric/timer habits (0-100)
  /// Returns: (score, avgValue, avgDuration, avgPercent)
  (double, double?, int?, double?) _calculateQualityScore(
    List<HabitCompletion> completions,
    Habit habit,
    {required double completionRatePercent}
  ) {
    final validCompletions = completions
        .where((c) => !c.isSkipped && !c.isPostponed)
        .toList();

    if (validCompletions.isEmpty) {
      return (completionRatePercent, null, null, completionRatePercent);
    }

    // For Yes/No habits, quality is based on Yes ratio
    if (habit.completionType == 'yesNo' || habit.completionType == 'yes_no') {
      final yesCount = validCompletions
          .where((c) => c.answer == true || c.count > 0)
          .length;
      final score = yesCount / validCompletions.length * 100;
      return (score, null, null, score);
    }

    // For Numeric habits
    if (habit.completionType == 'numeric') {
      final valuesWithTarget = validCompletions
          .where((c) => c.actualValue != null)
          .toList();
      
      if (valuesWithTarget.isEmpty || habit.targetValue == null || habit.targetValue! <= 0) {
        return (completionRatePercent, null, null, completionRatePercent);
      }

      final avgValue = valuesWithTarget
          .map((c) => c.actualValue!)
          .reduce((a, b) => a + b) / valuesWithTarget.length;
      
      final avgPercent = (avgValue / habit.targetValue! * 100).clamp(0.0, 150.0);

      final targetHitRate = valuesWithTarget
          .where((c) => c.actualValue! >= habit.targetValue!)
          .length /
          valuesWithTarget.length *
          100;
      final score = (avgPercent.clamp(0.0, 100.0) * 0.7 + targetHitRate * 0.3)
          .clamp(0.0, 100.0);
      
      return (score, avgValue, null, avgPercent);
    }

    // For Timer habits
    if (habit.completionType == 'timer') {
      final timesWithTarget = validCompletions
          .where((c) => c.actualDurationMinutes != null)
          .toList();
      
      if (timesWithTarget.isEmpty ||
          habit.targetDurationMinutes == null ||
          habit.targetDurationMinutes! <= 0) {
        return (completionRatePercent, null, null, completionRatePercent);
      }

      final avgDuration = timesWithTarget
          .map((c) => c.actualDurationMinutes!)
          .reduce((a, b) => a + b) ~/ timesWithTarget.length;
      
      final avgPercent = (avgDuration / habit.targetDurationMinutes! * 100).clamp(0.0, 150.0);

      final targetHitRate = timesWithTarget
          .where((c) => c.actualDurationMinutes! >= habit.targetDurationMinutes!)
          .length /
          timesWithTarget.length *
          100;
      final score = (avgPercent.clamp(0.0, 100.0) * 0.7 + targetHitRate * 0.3)
          .clamp(0.0, 100.0);
      
      return (score, null, avgDuration, avgPercent);
    }

    // For Checklist habits
    if (habit.completionType == 'checklist') {
      final itemCount = math.max(1, habit.checklist?.length ?? 1).toInt();
      final avgProgress = validCompletions
          .map((c) => (c.count / itemCount).clamp(0.0, 1.0))
          .reduce((a, b) => a + b) /
          validCompletions.length *
          100;
      final fullCompletionRate = validCompletions
          .where((c) => c.count >= itemCount || c.answer == true)
          .length /
          validCompletions.length *
          100;
      final score = (avgProgress * 0.6 + fullCompletionRate * 0.4)
          .clamp(0.0, 100.0);
      return (score, null, null, score);
    }

    // For Quit habits
    if (habit.completionType == 'quit') {
      // Quality = how many days resisted vs total days
      final resistedCount = validCompletions
          .where((c) => c.answer == true || (c.answer == null && c.count > 0))
          .length;
      final slipCount = validCompletions
          .where((c) => c.answer == false)
          .length;
      
      if (resistedCount + slipCount == 0) {
        return (completionRatePercent, null, null, completionRatePercent);
      }
      
      final score = resistedCount / (resistedCount + slipCount) * 100;
      return (score, null, null, score);
    }

    return (completionRatePercent, null, null, completionRatePercent);
  }

  /// Check if a completion counts as successful based on habit type
  bool _isSuccessfulCompletion(HabitCompletion completion, Habit habit) {
    if (completion.isSkipped || completion.isPostponed) return false;

    switch (habit.completionType) {
      case 'yesNo':
      case 'yes_no':
        return completion.answer == true || completion.count > 0;
      case 'numeric':
        if (completion.actualValue == null) {
          return completion.count > 0 || completion.answer == true;
        }
        final target = habit.targetValue ?? 1;
        return completion.actualValue! >= target;
      case 'timer':
        if (completion.actualDurationMinutes == null) {
          return completion.count > 0 || completion.answer == true;
        }
        final target = habit.targetDurationMinutes ?? 1;
        return completion.actualDurationMinutes! >= target;
      case 'quit':
        if (completion.answer != null) return completion.answer == true;
        return completion.count > 0;
      case 'checklist':
        final itemCount = habit.checklist?.length ?? 1;
        return completion.count >= itemCount || completion.answer == true;
      default:
        return completion.count > 0 || completion.answer == true;
    }
  }

  /// Generate actionable insights based on scores
  List<String> _generateInsights({
    required Habit habit,
    required double completionRateScore,
    required double streakScore,
    required double consistencyScore,
    required double trendScore,
    required String trendDirection,
    required double recoveryScore,
    required double qualityScore,
    required int actualCompletions,
    required int expectedCompletions,
  }) {
    final insights = <String>[];

    // Completion rate insights
    if (completionRateScore >= 90) {
      insights.add('Excellent completion rate! You\'re crushing this habit.');
    } else if (completionRateScore >= 70) {
      insights.add('Good completion rate. Keep up the momentum!');
    } else if (completionRateScore >= 50) {
      insights.add('Your completion rate is fair. Try to complete more regularly.');
    } else if (completionRateScore > 0) {
      insights.add('Completion rate needs work. Start with smaller, achievable goals.');
    }

    // Streak insights
    if (habit.currentStreak >= 21) {
      insights.add('Amazing ${habit.currentStreak}-day streak! This habit is becoming automatic.');
    } else if (habit.currentStreak >= 7) {
      insights.add('Great ${habit.currentStreak}-day streak! One more week to make it solid.');
    } else if (habit.currentStreak > 0 && habit.bestStreak > habit.currentStreak * 2) {
      insights.add('Your best streak was ${habit.bestStreak} days. You can get back there!');
    } else if (habit.currentStreak == 0 && habit.bestStreak > 0) {
      insights.add('Time to start a new streak! Your best was ${habit.bestStreak} days.');
    }

    // Trend insights
    if (trendDirection == 'improving') {
      insights.add('You\'re on an upward trend! Keep the momentum going.');
    } else if (trendDirection == 'declining') {
      insights.add('Your performance has dipped recently. What changed?');
    }

    // Consistency insights
    if (consistencyScore >= 80) {
      insights.add('Very consistent timing. Your routine is solid!');
    } else if (consistencyScore < 50) {
      insights.add('Try completing at the same time each day for better results.');
    }

    // Recovery insights
    if (recoveryScore >= 80) {
      insights.add('Great recovery ability! You bounce back well after missing.');
    } else if (recoveryScore < 40) {
      insights.add('When you miss a day, make sure to get back on track immediately.');
    }

    // Type-specific insights
    if (habit.completionType == 'timer' && qualityScore < 80) {
      insights.add('Try to reach your time target more often.');
    }
    if (habit.completionType == 'numeric' && qualityScore < 80) {
      insights.add('Aim to hit your target value consistently.');
    }

    // Fallback
    if (insights.isEmpty) {
      insights.add('Keep tracking to unlock more insights!');
    }

    return insights.take(4).toList(); // Limit to 4 insights
  }

  bool _isDateInRange(DateTime date, DateTime start, DateTime end) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);
    return !dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly);
  }

  HabitScoreWeights _getEffectiveWeights(
    Habit habit,
    HabitScoreWeights baseWeights,
  ) {
    // Recovery is only fully meaningful for daily habits.
    final recoveryWeight =
        habit.frequencyType == 'daily' ? baseWeights.recovery : 0.0;
    final normalized = _normalizeWeights(
      HabitScoreWeights(
        completionRate: baseWeights.completionRate,
        streak: baseWeights.streak,
        consistency: baseWeights.consistency,
        trend: baseWeights.trend,
        recovery: recoveryWeight,
        quality: baseWeights.quality,
      ),
    );
    return normalized;
  }

  HabitScoreWeights _normalizeWeights(HabitScoreWeights weights) {
    final sum = weights.completionRate +
        weights.streak +
        weights.consistency +
        weights.trend +
        weights.recovery +
        weights.quality;

    if (sum <= 0) {
      return const HabitScoreWeights(
        completionRate: 1.0,
        streak: 0.0,
        consistency: 0.0,
        trend: 0.0,
        recovery: 0.0,
        quality: 0.0,
      );
    }

    return HabitScoreWeights(
      completionRate: weights.completionRate / sum,
      streak: weights.streak / sum,
      consistency: weights.consistency / sum,
      trend: weights.trend / sum,
      recovery: weights.recovery / sum,
      quality: weights.quality / sum,
    );
  }

  double _expectedGapDays(Habit habit) {
    switch (habit.frequencyType) {
      case 'daily':
        return 1.0;
      case 'weekly':
        if (habit.weekDays != null && habit.weekDays!.isNotEmpty) {
          return (7 / habit.weekDays!.length).clamp(1.0, 7.0).toDouble();
        }
        return 7.0;
      case 'xTimesPerWeek':
        return habit.targetCount > 0
            ? (7 / habit.targetCount).clamp(1.0, 7.0).toDouble()
            : 7.0;
      case 'xTimesPerMonth':
        return habit.targetCount > 0
            ? (30 / habit.targetCount).clamp(1.0, 30.0).toDouble()
            : 30.0;
      case 'custom':
        if (habit.customIntervalDays != null && habit.customIntervalDays! > 0) {
          return habit.customIntervalDays!.toDouble();
        }
        if (habit.frequencyPeriod != null) {
          switch (habit.frequencyPeriod) {
            case 'day':
              return habit.targetCount > 0
                  ? (1 / habit.targetCount).clamp(0.25, 1.0).toDouble()
                  : 1.0;
            case 'week':
              return habit.targetCount > 0
                  ? (7 / habit.targetCount).clamp(1.0, 7.0).toDouble()
                  : 7.0;
            case 'month':
              return habit.targetCount > 0
                  ? (30 / habit.targetCount).clamp(1.0, 30.0).toDouble()
                  : 30.0;
            case 'year':
              return habit.targetCount > 0
                  ? (365 / habit.targetCount).clamp(1.0, 365.0).toDouble()
                  : 365.0;
          }
        }
        return 1.0;
      default:
        return 1.0;
    }
  }

  double _calculateTargetConsistency(
    List<HabitCompletion> completions,
    Habit habit,
  ) {
    if (habit.completionType == 'numeric') {
      final target = habit.targetValue;
      final values = completions
          .where((c) =>
              !c.isSkipped &&
              !c.isPostponed &&
              c.actualValue != null &&
              c.actualValue! > 0)
          .map((c) => c.actualValue!)
          .toList();
      if (target == null || target <= 0 || values.isEmpty) return 100;
      final ratios = values.map((v) => (v / target).clamp(0.0, 2.0)).toList();
      return _ratioConsistencyScore(ratios);
    }

    if (habit.completionType == 'timer') {
      final target = habit.targetDurationMinutes;
      final durations = completions
          .where((c) =>
              !c.isSkipped &&
              !c.isPostponed &&
              c.actualDurationMinutes != null &&
              c.actualDurationMinutes! > 0)
          .map((c) => c.actualDurationMinutes!)
          .toList();
      if (target == null || target <= 0 || durations.isEmpty) return 100;
      final ratios = durations
          .map((d) => (d / target).clamp(0.0, 2.0))
          .toList();
      return _ratioConsistencyScore(ratios);
    }

    return 100;
  }

  double _ratioConsistencyScore(List<double> ratios) {
    if (ratios.isEmpty) return 100;
    final avg = ratios.reduce((a, b) => a + b) / ratios.length;
    final variance = ratios
            .map((r) => math.pow(r - avg, 2))
            .reduce((a, b) => a + b) /
        ratios.length;
    final stdDev = math.sqrt(variance);
    final closenessToTarget =
        (100 - (avg - 1).abs() * 100).clamp(0.0, 100.0).toDouble();
    final stability = (100 - stdDev * 100).clamp(0.0, 100.0).toDouble();
    return (closenessToTarget * 0.6 + stability * 0.4).clamp(0.0, 100.0);
  }

  /// Calculate scores for multiple habits at once
  Future<Map<String, HabitScore>> calculateScoresForHabits(
    List<Habit> habits, {
    int analysisDays = defaultAnalysisDays,
  }) async {
    final scores = <String, HabitScore>{};
    
    for (final habit in habits) {
      scores[habit.id] = await calculateScore(habit, analysisDays: analysisDays);
    }
    
    return scores;
  }

  /// Get aggregate score across all habits
  Future<double> getOverallHabitScore(List<Habit> habits) async {
    if (habits.isEmpty) return 0;

    final scores = await calculateScoresForHabits(habits);
    final validScores = scores.values
        .where((s) => s.analysisDays >= minimumDaysForScore)
        .toList();

    if (validScores.isEmpty) return 0;

    final totalScore = validScores
        .map((s) => s.overallScore)
        .reduce((a, b) => a + b);

    return totalScore / validScores.length;
  }
}
