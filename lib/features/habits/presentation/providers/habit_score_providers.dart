import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_score.dart';
import '../../data/repositories/habit_repository.dart';
import '../../data/services/habit_score_service.dart';
import 'habit_providers.dart';

/// Provider for the HabitScoreService
final habitScoreServiceProvider = Provider<HabitScoreService>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  return HabitScoreService(repository);
});

/// Provider for a single habit's score
/// Automatically recalculates when the habit changes
final habitScoreProvider = FutureProvider.family<HabitScore, String>((ref, habitId) async {
  final service = ref.watch(habitScoreServiceProvider);
  final habitAsync = ref.watch(habitByIdProvider(habitId));
  
  return habitAsync.when(
    data: (habit) async {
      if (habit == null) return HabitScore.empty(habitId);
      return service.calculateScore(habit);
    },
    loading: () => HabitScore.empty(habitId),
    error: (_, __) => HabitScore.empty(habitId),
  );
});

/// Provider for a habit's score with custom analysis period
final habitScoreWithPeriodProvider = FutureProvider.family<
    HabitScore,
    ({String habitId, int analysisDays})>((ref, params) async {
  final service = ref.watch(habitScoreServiceProvider);
  final habitAsync = ref.watch(habitByIdProvider(params.habitId));
  
  return habitAsync.when(
    data: (habit) async {
      if (habit == null) return HabitScore.empty(params.habitId);
      return service.calculateScore(
        habit,
        analysisDays: params.analysisDays,
      );
    },
    loading: () => HabitScore.empty(params.habitId),
    error: (_, __) => HabitScore.empty(params.habitId),
  );
});

/// Provider for scores of all active habits
final allHabitScoresProvider = FutureProvider<Map<String, HabitScore>>((ref) async {
  final service = ref.watch(habitScoreServiceProvider);
  final habitsAsync = ref.watch(habitNotifierProvider);
  
  return habitsAsync.when(
    data: (habits) async {
      final activeHabits = habits.where((h) => !h.isArchived).toList();
      return service.calculateScoresForHabits(activeHabits);
    },
    loading: () => <String, HabitScore>{},
    error: (_, __) => <String, HabitScore>{},
  );
});

/// Provider for overall habit score (average of all habits)
final overallHabitScoreProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(habitScoreServiceProvider);
  final habitsAsync = ref.watch(habitNotifierProvider);
  
  return habitsAsync.when(
    data: (habits) async {
      final activeHabits = habits.where((h) => !h.isArchived).toList();
      return service.getOverallHabitScore(activeHabits);
    },
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider for top performing habits (sorted by score)
final topPerformingHabitsProvider = FutureProvider<List<({Habit habit, HabitScore score})>>((ref) async {
  final scoresAsync = await ref.watch(allHabitScoresProvider.future);
  final habitsAsync = ref.watch(habitNotifierProvider);
  
  return habitsAsync.when(
    data: (habits) {
      final result = <({Habit habit, HabitScore score})>[];
      
      for (final habit in habits) {
        final score = scoresAsync[habit.id];
        if (score != null && score.analysisDays >= HabitScoreService.minimumDaysForScore) {
          result.add((habit: habit, score: score));
        }
      }
      
      // Sort by score descending
      result.sort((a, b) => b.score.overallScore.compareTo(a.score.overallScore));
      
      return result;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for habits needing attention (low scores or declining)
final habitsNeedingAttentionProvider = FutureProvider<List<({Habit habit, HabitScore score, String reason})>>((ref) async {
  final scoresAsync = await ref.watch(allHabitScoresProvider.future);
  final habitsAsync = ref.watch(habitNotifierProvider);
  
  return habitsAsync.when(
    data: (habits) {
      final result = <({Habit habit, HabitScore score, String reason})>[];
      
      for (final habit in habits) {
        final score = scoresAsync[habit.id];
        if (score == null || score.analysisDays < HabitScoreService.minimumDaysForScore) {
          continue;
        }
        
        String? reason;
        
        // Check for low overall score
        if (score.overallScore < 50) {
          reason = 'Score is ${score.overallScore.toStringAsFixed(0)}%';
        }
        // Check for declining trend
        else if (score.trendDirection == 'declining') {
          reason = 'Performance declining';
        }
        // Check for broken streak
        else if (habit.currentStreak == 0 && habit.bestStreak > 7) {
          reason = 'Streak broken (was ${habit.bestStreak} days)';
        }
        // Check for low completion rate
        else if (score.completionRatePercent < 50) {
          reason = 'Low completion rate (${score.completionRatePercent.toStringAsFixed(0)}%)';
        }
        
        if (reason != null) {
          result.add((habit: habit, score: score, reason: reason));
        }
      }
      
      // Sort by score ascending (worst first)
      result.sort((a, b) => a.score.overallScore.compareTo(b.score.overallScore));
      
      return result;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for habits with improving trend
final improvingHabitsProvider = FutureProvider<List<({Habit habit, HabitScore score})>>((ref) async {
  final scoresAsync = await ref.watch(allHabitScoresProvider.future);
  final habitsAsync = ref.watch(habitNotifierProvider);
  
  return habitsAsync.when(
    data: (habits) {
      final result = <({Habit habit, HabitScore score})>[];
      
      for (final habit in habits) {
        final score = scoresAsync[habit.id];
        if (score != null && 
            score.analysisDays >= HabitScoreService.minimumDaysForScore &&
            score.trendDirection == 'improving') {
          result.add((habit: habit, score: score));
        }
      }
      
      return result;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for habit score summary statistics
final habitScoreSummaryProvider = FutureProvider<HabitScoreSummary>((ref) async {
  final scoresAsync = await ref.watch(allHabitScoresProvider.future);
  final habitsAsync = ref.watch(habitNotifierProvider);
  
  return habitsAsync.when(
    data: (habits) {
      final validScores = scoresAsync.values
          .where((s) => s.analysisDays >= HabitScoreService.minimumDaysForScore)
          .toList();
      
      if (validScores.isEmpty) {
        return HabitScoreSummary.empty();
      }
      
      final avgScore = validScores
          .map((s) => s.overallScore)
          .reduce((a, b) => a + b) / validScores.length;
      
      final avgCompletionRate = validScores
          .map((s) => s.completionRatePercent)
          .reduce((a, b) => a + b) / validScores.length;
      
      final totalStreak = habits.fold<int>(0, (sum, h) => sum + h.currentStreak);
      
      final improvingCount = validScores
          .where((s) => s.trendDirection == 'improving')
          .length;
      
      final decliningCount = validScores
          .where((s) => s.trendDirection == 'declining')
          .length;
      
      final excellentCount = validScores.where((s) => s.overallScore >= 90).length;
      final goodCount = validScores.where((s) => s.overallScore >= 70 && s.overallScore < 90).length;
      final needsWorkCount = validScores.where((s) => s.overallScore < 70).length;
      
      return HabitScoreSummary(
        totalHabits: habits.length,
        scoredHabits: validScores.length,
        averageScore: avgScore,
        averageCompletionRate: avgCompletionRate,
        totalCurrentStreak: totalStreak,
        improvingCount: improvingCount,
        decliningCount: decliningCount,
        stableCount: validScores.length - improvingCount - decliningCount,
        excellentCount: excellentCount,
        goodCount: goodCount,
        needsWorkCount: needsWorkCount,
        overallGrade: HabitScore.getGrade(avgScore),
      );
    },
    loading: () => HabitScoreSummary.empty(),
    error: (_, __) => HabitScoreSummary.empty(),
  );
});

/// Summary statistics for all habit scores
class HabitScoreSummary {
  final int totalHabits;
  final int scoredHabits;
  final double averageScore;
  final double averageCompletionRate;
  final int totalCurrentStreak;
  final int improvingCount;
  final int decliningCount;
  final int stableCount;
  final int excellentCount;
  final int goodCount;
  final int needsWorkCount;
  final String overallGrade;

  const HabitScoreSummary({
    required this.totalHabits,
    required this.scoredHabits,
    required this.averageScore,
    required this.averageCompletionRate,
    required this.totalCurrentStreak,
    required this.improvingCount,
    required this.decliningCount,
    required this.stableCount,
    required this.excellentCount,
    required this.goodCount,
    required this.needsWorkCount,
    required this.overallGrade,
  });

  factory HabitScoreSummary.empty() {
    return const HabitScoreSummary(
      totalHabits: 0,
      scoredHabits: 0,
      averageScore: 0,
      averageCompletionRate: 0,
      totalCurrentStreak: 0,
      improvingCount: 0,
      decliningCount: 0,
      stableCount: 0,
      excellentCount: 0,
      goodCount: 0,
      needsWorkCount: 0,
      overallGrade: 'N/A',
    );
  }

  bool get hasData => scoredHabits > 0;

  String get averageScoreFormatted => '${averageScore.toStringAsFixed(0)}%';
  
  String get completionRateFormatted => '${averageCompletionRate.toStringAsFixed(0)}%';
}
