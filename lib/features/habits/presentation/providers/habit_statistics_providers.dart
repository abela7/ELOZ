import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_completion.dart';
import '../../data/models/habit_statistics.dart';
import '../../data/services/habit_statistics_service.dart';
import 'habit_providers.dart';

/// Simple data class for daily habit stats
class DailyHabitStats {
  final int total;
  final int completed;
  final int pending;
  final int streaks;
  final int missed;   // Past days with no log (regular habits only)
  final int skipped;  // Explicitly skipped

  const DailyHabitStats({
    required this.total,
    required this.completed,
    required this.pending,
    required this.streaks,
    this.missed = 0,
    this.skipped = 0,
  });

  factory DailyHabitStats.empty() => const DailyHabitStats(
        total: 0,
        completed: 0,
        pending: 0,
        streaks: 0,
        missed: 0,
        skipped: 0,
      );
}

/// Provider for the HabitStatisticsService
final habitStatisticsServiceProvider = Provider<HabitStatisticsService>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  return HabitStatisticsService(repository);
});

/// Provider for a single habit's detailed statistics
final habitStatisticsProvider = FutureProvider.family<HabitStatistics, String>((
  ref,
  habitId,
) async {
  final service = ref.watch(habitStatisticsServiceProvider);
  final habit = ref.watch(
    habitByIdProvider(habitId).select((habitAsync) => habitAsync.valueOrNull),
  );
  if (habit == null) return HabitStatistics.empty(habitId);
  return service.calculateStatistics(habit);
});

/// Provider for monthly habit completion stats (for calendar heatmap)
/// Returns a map of date -> completion percentage for the entire month
final monthlyHabitStatsProvider = FutureProvider.family<
    Map<DateTime, double>,
    ({int year, int month})>((ref, params) async {
  final habits = ref.watch(habitListValueProvider);
  final repository = ref.watch(habitRepositoryProvider);

  // Hide quit habits from dashboard stats when configured.
  final activeHabits = habits
      .where((h) => !h.isArchived && !h.shouldHideQuitHabit)
      .toList();
  if (activeHabits.isEmpty) return const <DateTime, double>{};

  final result = <DateTime, double>{};
  final lastDay = DateTime(params.year, params.month + 1, 0);

  for (var day = 1; day <= lastDay.day; day++) {
    final date = DateTime(params.year, params.month, day);

    // Don't calculate for future dates
    if (date.isAfter(DateTime.now())) continue;

    // Filter habits due on this date
    final habitsForDate = activeHabits.where((h) => h.isDueOn(date)).toList();
    if (habitsForDate.isEmpty) continue;

    final completionsByHabit = await repository.getCompletionsForAllHabitsOnDate(
      date,
    );
    var scoreSum = 0.0;

    for (final habit in habitsForDate) {
      final completions = completionsByHabit[habit.id] ?? const <HabitCompletion>[];
      final progress = _bestProgressForDate(completions, habit);
      scoreSum += progress;
      // For quit habits: after auto-backfill, past resisted days have records.
      // Today without explicit/backfilled log remains pending until day closes.
    }

    result[DateTime(date.year, date.month, date.day)] =
        habitsForDate.isNotEmpty ? scoreSum / habitsForDate.length : 0.0;
  }

  return result;
});

/// Provider for daily habit stats (total, completed, pending, streaks)
/// Used by the habits dashboard to show summary statistics for a specific date.
///
/// For today: uses the synchronous [todayHabitStatusesProvider] pre-computed
/// during loadHabits(), so it resolves instantly — no async gap.
/// For other dates: falls back to the async [habitStatusesOnDateProvider].
final dailyHabitStatsProvider =
    FutureProvider.family<DailyHabitStats, DateTime>((ref, date) async {
  final habits = ref.watch(habitListValueProvider);
  final activeHabits = habits
      .where((h) => !h.isArchived && !h.shouldHideQuitHabit)
      .toList();
  if (activeHabits.isEmpty) return DailyHabitStats.empty();

  final dateOnly = DateTime(date.year, date.month, date.day);

  // Filter habits due on this date
  final habitsForDate = activeHabits.where((h) => h.isDueOn(dateOnly)).toList();

  final total = habitsForDate.length;
  var completed = 0;
  var skipped = 0;
  var missed = 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final isPastDay = dateOnly.isBefore(today);

  // Fast path: today's statuses are pre-computed (no await needed).
  final isToday = dateOnly == today;
  final Map<String, HabitDayStatus> dayStatuses;
  if (isToday) {
    dayStatuses = ref.watch(todayHabitStatusesProvider);
  } else {
    dayStatuses = await ref.watch(habitStatusesOnDateProvider(dateOnly).future);
  }

  for (final habit in habitsForDate) {
    final status = dayStatuses[habit.id] ?? HabitDayStatus.empty;
    final isCompleted = status.isCompleted;
    final isSkipped = status.isSkipped;
    final hasNoLog = !status.hasLog;

    if (isCompleted) {
      completed++;
    } else if (isSkipped) {
      skipped++;
    } else if (hasNoLog && isPastDay) {
      // For quit habits: After auto-backfill, past days should have completion records.
      // If they don't, treat as missed (will be fixed on next app load by backfill).
      // For regular habits: No log = missed
      missed++;
    }
  }

  // Count habits with active streaks that are due on this date
  final streaks = habitsForDate.where((h) => h.currentStreak > 0).length;

  // Pending = habits still to be done today (not missed)
  // For past days, pending = 0 (you can't complete past habits now)
  final pending = isPastDay ? 0 : (total - completed - skipped);

  return DailyHabitStats(
    total: total,
    completed: completed,
    pending: pending,
    streaks: streaks,
    missed: missed,
    skipped: skipped,
  );
});

double _bestProgressForDate(List<HabitCompletion> completions, Habit habit) {
  if (completions.isEmpty) return 0.0;

  double best = 0.0;
  for (final completion in completions) {
    final progress = _completionProgressForEntry(completion, habit);
    if (progress > best) best = progress;
  }
  return best.clamp(0.0, 1.0);
}

double _completionProgressForEntry(HabitCompletion completion, Habit habit) {
  if (completion.isSkipped || completion.isPostponed) return 0.0;

  switch (habit.completionType) {
    case 'yesNo':
    case 'yes_no':
      return (completion.answer == true || completion.count > 0) ? 1.0 : 0.0;

    case 'numeric':
      if (completion.actualValue != null) {
        final target = habit.targetValue ?? 0;
        if (target <= 0) return completion.actualValue! > 0 ? 1.0 : 0.0;
        return (completion.actualValue! / target).clamp(0.0, 1.0).toDouble();
      }
      return (completion.count > 0 || completion.answer == true) ? 1.0 : 0.0;

    case 'timer':
      if (completion.actualDurationMinutes != null) {
        final target = habit.targetDurationMinutes ?? 0;
        if (target <= 0) return completion.actualDurationMinutes! > 0 ? 1.0 : 0.0;
        return (completion.actualDurationMinutes! / target).clamp(0.0, 1.0).toDouble();
      }
      return (completion.count > 0 || completion.answer == true) ? 1.0 : 0.0;

    case 'checklist':
      if (completion.answer == true) return 1.0;
      final itemCount = (habit.checklist?.length ?? 1);
      if (itemCount <= 0) return completion.count > 0 ? 1.0 : 0.0;
      return (completion.count / itemCount).clamp(0.0, 1.0).toDouble();

    case 'quit':
      if (completion.answer != null) return completion.answer == true ? 1.0 : 0.0;
      return completion.count > 0 ? 1.0 : 0.0;

    default:
      return (completion.count > 0 || completion.answer == true) ? 1.0 : 0.0;
  }
}
