import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_completion.dart';
import '../../data/models/habit_type.dart';
import '../../data/repositories/habit_repository.dart';
import '../../data/repositories/habit_type_repository.dart';
import '../../../../core/services/reminder_manager.dart';
import '../../../../core/utils/perf_trace.dart';
import 'habit_type_providers.dart';

/// Singleton provider for HabitRepository instance (cached)
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository();
});

/// StateNotifier for managing habit list state
class HabitNotifier extends StateNotifier<AsyncValue<List<Habit>>> {
  final HabitRepository repository;
  final HabitTypeRepository habitTypeRepository;
  final ReminderManager _reminderManager = ReminderManager();
  bool _isQuitBackfillRunning = false;
  DateTime? _lastQuitBackfillAt;
  static const Duration _quitBackfillMinInterval = Duration(minutes: 15);

  // ---------------------------------------------------------------------------
  // Pre-computed today-statuses cache
  // ---------------------------------------------------------------------------
  // Populated atomically alongside loadHabits() so the habits screen can
  // render in a single synchronous frame — no second async round-trip.
  // ---------------------------------------------------------------------------
  Map<String, HabitDayStatus> _todayStatuses = const {};

  /// Synchronously available day statuses for today.
  /// Populated by [loadHabits] in the same async step as habit data.
  Map<String, HabitDayStatus> get todayStatuses => _todayStatuses;

  HabitNotifier(this.repository, this.habitTypeRepository)
    : super(const AsyncValue.loading()) {
    loadHabits();
  }

  /// Pre-open encrypted quit Hive boxes so the next [loadHabits] returns
  /// instantly. Call this right after a successful passcode unlock while the
  /// dialog is still animating out, then follow with [loadHabits].
  Future<void> warmUpSecureBoxes() => repository.warmUpSecureBoxes();

  /// Load all habits from database, pre-computing today's completion statuses
  /// in the same round-trip so the dashboard can render immediately.
  Future<void> loadHabits({bool runBackgroundBackfill = true}) async {
    final trace = PerfTrace('HabitsNotifier.loadHabits');
    if (!state.hasValue) {
      state = const AsyncValue.loading();
      trace.step('set_loading');
    }
    try {
      // Single round-trip: fetch habits + today's completions in parallel.
      final habitsFuture = repository.getAllHabits();
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final completionsFuture = repository.getCompletionsForAllHabitsOnDate(
        todayDate,
      );
      trace.step('futures_created');

      final results = await Future.wait([habitsFuture, completionsFuture]);
      trace.step('futures_resolved');
      final habits = results[0] as List<Habit>;
      final completionsByHabit =
          results[1] as Map<String, List<HabitCompletion>>;

      // Sort by sortOrder, then by createdAt
      habits.sort((a, b) {
        if (a.sortOrder != b.sortOrder) {
          return a.sortOrder.compareTo(b.sortOrder);
        }
        return a.createdAt.compareTo(b.createdAt);
      });
      trace.step('sorted_habits', details: {'count': habits.length});

      // Pre-compute today's statuses
      _todayStatuses = _buildDayStatuses(habits, completionsByHabit);
      trace.step(
        'statuses_built',
        details: {'statusCount': _todayStatuses.length},
      );

      state = AsyncValue.data(habits);
      trace.step('state_updated');

      if (runBackgroundBackfill) {
        _runQuitBackfillInBackground();
        trace.step('quit_backfill_triggered');
      }
      trace.end('done');
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      trace.end('error', details: {'error': e.toString()});
    }
  }

  /// Build HabitDayStatus map from pre-fetched completion data.
  /// Pure computation — no I/O.
  static Map<String, HabitDayStatus> _buildDayStatuses(
    List<Habit> habits,
    Map<String, List<HabitCompletion>> completionsByHabit,
  ) {
    final result = <String, HabitDayStatus>{};
    for (final habit in habits) {
      final completions =
          completionsByHabit[habit.id] ?? const <HabitCompletion>[];
      if (completions.isEmpty) {
        result[habit.id] = HabitDayStatus.empty;
        continue;
      }
      result[habit.id] = HabitDayStatus(
        isCompleted: _isCompletedForHabitOnDate(completions, habit),
        isSkipped: completions.any((c) => c.isSkipped),
        isPostponed: completions.any((c) => c.isPostponed),
        hasLog: true,
      );
    }
    return result;
  }

  void _runQuitBackfillInBackground() {
    if (_isQuitBackfillRunning) return;
    final now = DateTime.now();
    if (_lastQuitBackfillAt != null &&
        now.difference(_lastQuitBackfillAt!) < _quitBackfillMinInterval) {
      return;
    }

    _isQuitBackfillRunning = true;
    () async {
      try {
        await repository.autoBackfillAllQuitHabits();
        _lastQuitBackfillAt = DateTime.now();

        // Re-fetch habits + today's statuses together (same pattern as loadHabits)
        final todayDate = DateTime(now.year, now.month, now.day);
        final results = await Future.wait([
          repository.getAllHabits(),
          repository.getCompletionsForAllHabitsOnDate(todayDate),
        ]);
        final habits = results[0] as List<Habit>;
        final completionsByHabit =
            results[1] as Map<String, List<HabitCompletion>>;

        habits.sort((a, b) {
          if (a.sortOrder != b.sortOrder) {
            return a.sortOrder.compareTo(b.sortOrder);
          }
          return a.createdAt.compareTo(b.createdAt);
        });

        if (mounted) {
          _todayStatuses = _buildDayStatuses(habits, completionsByHabit);
          state = AsyncValue.data(habits);
        }
      } finally {
        _isQuitBackfillRunning = false;
      }
    }();
  }

  /// Add a new habit
  ///
  /// Persists to DB immediately, then fires stats + reminder scheduling in
  /// the background so the UI returns instantly.
  Future<void> addHabit(Habit habit) async {
    try {
      // Update state immediately for instant UI response
      state.whenData((habits) {
        state = AsyncValue.data([...habits, habit]);
      });
      // Persist to database (fast Hive write – the only thing we await)
      await repository.createHabit(habit);

      // Fire-and-forget: stats + reminders in the background.
      // The DB write above already persists the habit; reminders and
      // initial stats are best-effort and should never block the screen.
      unawaited(_backgroundAfterSave(habit, refreshStats: true));
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabits();
    }
  }

  /// Update an existing habit
  ///
  /// Persists to DB immediately, then fires stats refresh + reminder
  /// rescheduling in the background so the UI returns instantly.
  Future<void> updateHabit(Habit habit) async {
    try {
      // Optimistic UI update – the user sees the change immediately
      state.whenData((habits) {
        final updatedHabits = habits
            .map((h) => h.id == habit.id ? habit : h)
            .toList();
        state = AsyncValue.data(updatedHabits);
      });

      // Persist to database (fast Hive write – the only thing we await)
      await repository.updateHabit(habit);

      // Fire-and-forget: stats refresh + reminder rescheduling + state
      // reload all run in the background so the caller returns instantly.
      unawaited(_backgroundAfterSave(habit, refreshStats: true));
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabits();
    }
  }

  /// Heavy work that runs after the DB write completes.
  ///
  /// This is intentionally fire-and-forget so the UI never blocks on
  /// notification scheduling or streak recalculation.
  Future<void> _backgroundAfterSave(
    Habit habit, {
    bool refreshStats = false,
  }) async {
    // Keep reminder rescheduling isolated so a stats-refresh error cannot
    // silently block notification updates.
    if (refreshStats) {
      try {
        await repository.refreshHabitStats(habit.id);
      } catch (e) {
        debugPrint(
          '⚠️ HabitNotifier._backgroundAfterSave refreshHabitStats: $e',
        );
      }
    }

    try {
      // Reschedule reminders (cancel old + schedule new in parallel batches).
      await _reminderManager.rescheduleRemindersForHabit(habit);
    } catch (e) {
      debugPrint(
        '⚠️ HabitNotifier._backgroundAfterSave rescheduleReminders: $e',
      );
    }

    try {
      // Reload the full list so calculated fields (streak, goal status)
      // propagate to all watchers. This intentionally skips quit-backfill
      // since we just saved a single habit – no need for a full scan.
      await loadHabits(runBackgroundBackfill: false);
    } catch (e) {
      debugPrint('⚠️ HabitNotifier._backgroundAfterSave loadHabits: $e');
    }
  }

  Future<void> _cleanupDeletedHabitNotifications(String habitId) async {
    await _reminderManager.handleHabitDeleted(habitId);
  }

  /// Delete a habit
  Future<void> deleteHabit(String id) async {
    try {
      state.whenData((habits) {
        final updatedHabits = habits.where((h) => h.id != id).toList();
        state = AsyncValue.data(updatedHabits);
      });
      // Cancel reminders BEFORE deleting the habit data, so if cancellation
      // partially fails the habit still exists and can be retried.
      await _cleanupDeletedHabitNotifications(id);
      await repository.deleteHabit(id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabits();
    }
  }

  /// Archive a habit
  Future<void> archiveHabit(String id) async {
    try {
      state.whenData((habits) {
        final updatedHabits = habits.where((h) => h.id != id).toList();
        state = AsyncValue.data(updatedHabits);
      });
      // Cancel reminders first — archived habits should not fire notifications
      await _cleanupDeletedHabitNotifications(id);
      await repository.archiveHabit(id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabits();
    }
  }

  /// Unarchive a habit and reschedule its reminders
  Future<void> unarchiveHabit(String id) async {
    try {
      await repository.unarchiveHabit(id);
      final habit = await repository.getHabitById(id);
      if (habit != null && habit.reminderEnabled) {
        await _reminderManager.scheduleRemindersForHabit(habit);
      }
      await loadHabits();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabits();
    }
  }

  /// Complete a habit for a specific date with proper points handling
  ///
  /// For numeric habits: calculates points based on actualValue
  /// For quit habits: awards dailyReward
  /// For yes/no habits: awards configured yes points
  Future<void> completeHabitForDate(
    String habitId,
    DateTime date, {
    String? note,
    double? actualValue,
    int? actualDurationMinutes,
  }) async {
    try {
      final habit = await repository.getHabitById(habitId);
      if (habit == null) return;
      if (!habit.isActiveOn(date)) return;

      // Calculate points to award
      int points = 0;
      if (habit.isNumeric && actualValue != null) {
        points = habit.calculateNumericPoints(actualValue);
      } else if (habit.isTimer && actualDurationMinutes != null) {
        points = habit.calculateTimerPoints(actualDurationMinutes).round();
      } else if (habit.isQuitHabit) {
        // Quit habit: award daily reward for resisting
        points = habit.dailyReward ?? habit.customYesPoints ?? 0;
      } else if (habit.completionType == 'yesNo') {
        // Regular yes/no habit
        points = await _resolveYesPoints(habit);
      } else {
        points = habit.customYesPoints ?? 0;
      }

      final completion = habit.isTimer && actualDurationMinutes != null
          ? HabitCompletion.timer(
              habitId: habitId,
              date: date,
              actualDurationMinutes: actualDurationMinutes,
              pointsEarned: points,
              note: note,
            )
          : habit.isNumeric && actualValue != null
          ? HabitCompletion.numeric(
              habitId: habitId,
              date: date,
              actualValue: actualValue,
              pointsEarned: points,
              note: note,
            )
          : HabitCompletion(
              habitId: habitId,
              completedDate: DateTime(date.year, date.month, date.day),
              completedAt: DateTime.now(),
              count: 1,
              note: note,
              answer: habit.completionType == 'yesNo' ? true : null,
              actualValue: habit.isNumeric ? actualValue : null,
              actualDurationMinutes: habit.isTimer
                  ? actualDurationMinutes
                  : null,
              pointsEarned: points,
            );

      // Add completion with points
      await repository.addCompletionWithPoints(
        completion,
        pointsDelta: points,
        updateMoneySaved: habit.isQuitHabit,
        updateUnitsAvoided: habit.isQuitHabit,
      );

      // Reload to get updated stats
      await loadHabits();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabits();
    }
  }

  /// Skip a habit for a specific date (or record a slip for quit habits)
  ///
  /// For regular habits: Just skips, no point change
  /// For quit habits: This is handled separately by slipHabitForDate
  Future<void> skipHabitForDate(
    String habitId,
    DateTime date, {
    String? reason,
  }) async {
    try {
      final habit = await repository.getHabitById(habitId);
      if (habit == null) return;
      if (!habit.isActiveOn(date)) return;

      int pointsDelta = 0;
      bool usePoints = false;
      if (!habit.isQuitHabit && habit.completionType == 'yesNo') {
        pointsDelta = await _resolveNoPoints(habit);
        usePoints = true;
      }

      final completion = HabitCompletion(
        habitId: habitId,
        completedDate: DateTime(date.year, date.month, date.day),
        completedAt: DateTime.now(),
        count: 0,
        isSkipped: true,
        skipReason: reason,
        answer: false,
        pointsEarned: pointsDelta,
      );

      // For quit habits, this is a SLIP - handled with penalty
      // The penalty is calculated and applied in the UI (habit_detail_modal.dart)
      // This method just records the skip/slip
      if (usePoints) {
        await repository.addCompletionWithPoints(
          completion,
          pointsDelta: pointsDelta,
        );
      } else {
        await repository.addCompletion(completion);
      }

      // Reload to get updated stats
      await loadHabits();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabits();
    }
  }

  /// Record a slip for a quit habit with proper penalty handling
  ///
  /// [penalty] - The penalty points to deduct (should be negative or will be negated)
  /// [slipAmount] - Number of units consumed (for per-unit tracking)
  Future<void> slipHabitForDate(
    String habitId,
    DateTime date, {
    String? reason,
    int penalty = 0,
    int slipAmount = 1,
  }) async {
    try {
      final habit = await repository.getHabitById(habitId);
      if (habit == null || !habit.isQuitHabit) return;
      if (!habit.isActiveOn(date)) return;

      // Ensure penalty is negative
      final actualPenalty = penalty > 0 ? -penalty : penalty;

      final completion = HabitCompletion(
        habitId: habitId,
        completedDate: DateTime(date.year, date.month, date.day),
        completedAt: DateTime.now(),
        count: slipAmount,
        isSkipped: true, // Mark as slip
        skipReason: reason,
        answer: false, // Mark as not resisted
        pointsEarned: actualPenalty, // Store the penalty (negative)
      );

      // Add completion with penalty and update slip count
      await repository.addCompletionWithPoints(
        completion,
        pointsDelta: actualPenalty,
        updateSlipCount: true,
        resetStreak: true, // Slip breaks the streak
        updateMoneySaved: true,
        updateUnitsAvoided: true,
        slipAmount: slipAmount,
      );

      // Reload to get updated stats
      await loadHabits();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabits();
    }
  }

  /// Uncomplete a habit for a specific date (undo) - properly reverts everything
  ///
  /// This undoes:
  /// - Points earned/lost
  /// - Slip count for quit habits
  /// - Recalculates streak
  Future<void> uncompleteHabitForDate(String habitId, DateTime date) async {
    try {
      // Use the new method that properly reverts everything
      await repository.deleteCompletionsForDateWithRevert(habitId, date);
      await loadHabits();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabits();
    }
  }

  /// Convenience method to complete a habit for today
  Future<void> completeHabitToday(String habitId, {String? note}) async {
    await completeHabitForDate(habitId, DateTime.now(), note: note);
  }

  /// Convenience method to skip a habit for today
  Future<void> skipHabitToday(String habitId, {String? reason}) async {
    await skipHabitForDate(habitId, DateTime.now(), reason: reason);
  }

  /// Convenience method to uncomplete a habit for today
  Future<void> uncompleteHabitToday(String habitId) async {
    await uncompleteHabitForDate(habitId, DateTime.now());
  }

  /// Postpone a habit for a specific date (yes/no only)
  Future<void> postponeHabitForDate(
    String habitId,
    DateTime date, {
    String? note,
  }) async {
    try {
      final habit = await repository.getHabitById(habitId);
      if (habit == null || habit.isQuitHabit) return;
      if (!habit.isActiveOn(date)) return;

      if (habit.completionType != 'yesNo') {
        return;
      }

      final pointsDelta = await _resolvePostponePoints(habit);
      final completion = HabitCompletion(
        habitId: habitId,
        completedDate: DateTime(date.year, date.month, date.day),
        completedAt: DateTime.now(),
        count: 0,
        isPostponed: true,
        note: note,
        pointsEarned: pointsDelta,
      );

      await repository.addCompletionWithPoints(
        completion,
        pointsDelta: pointsDelta,
      );

      await loadHabits();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabits();
    }
  }

  Future<int> getYesPointsForHabit(Habit habit) async {
    return _resolveYesPoints(habit);
  }

  Future<int> getNoPointsForHabit(Habit habit) async {
    return _resolveNoPoints(habit);
  }

  Future<int> getPostponePointsForHabit(Habit habit) async {
    return _resolvePostponePoints(habit);
  }

  Future<HabitType?> _getHabitType(Habit habit) async {
    final habitTypeId = habit.habitTypeId;
    if (habitTypeId == null) return null;
    return habitTypeRepository.getHabitTypeById(habitTypeId);
  }

  Future<int> _resolveYesPoints(Habit habit) async {
    if (habit.customYesPoints != null) return habit.customYesPoints!;
    final habitType = await _getHabitType(habit);
    return habitType?.rewardOnDone ?? 0;
  }

  Future<int> _resolveNoPoints(Habit habit) async {
    if (habit.customNoPoints != null) return habit.customNoPoints!;
    final habitType = await _getHabitType(habit);
    return habitType?.penaltyNotDone ?? 0;
  }

  Future<int> _resolvePostponePoints(Habit habit) async {
    if (habit.customPostponePoints != null) return habit.customPostponePoints!;
    final habitType = await _getHabitType(habit);
    return habitType?.penaltyPostpone ?? 0;
  }
}

/// Provider for HabitNotifier
final habitNotifierProvider =
    StateNotifierProvider<HabitNotifier, AsyncValue<List<Habit>>>((ref) {
      final repository = ref.watch(habitRepositoryProvider);
      final habitTypeRepository = ref.watch(habitTypeRepositoryProvider);
      return HabitNotifier(repository, habitTypeRepository);
    });

/// Raw habit list value only.
/// Using `.select` avoids rebuilds for loading/error transitions when callers
/// only need the latest data snapshot.
final habitListValueProvider = Provider<List<Habit>>((ref) {
  return ref.watch(
    habitNotifierProvider.select(
      (state) => state.valueOrNull ?? const <Habit>[],
    ),
  );
});

/// Synchronous today-statuses, pre-computed during loadHabits().
///
/// This eliminates the async waterfall that previously blocked the dashboard:
///   Before: loadHabits → await → habitStatusesOnDateProvider → await → render
///   After:  loadHabits (habits + statuses in parallel) → render immediately
///
/// For non-today dates (calendar screen), use [habitStatusesOnDateProvider]
/// which still does an async lookup but benefits from the repository cache.
final todayHabitStatusesProvider = Provider<Map<String, HabitDayStatus>>((ref) {
  // Trigger rebuild whenever the habit notifier emits (load / backfill / mutation)
  ref.watch(habitNotifierProvider);
  return ref.read(habitNotifierProvider.notifier).todayStatuses;
});

/// Provider for habits due today
final habitsDueTodayProvider = Provider<AsyncValue<List<Habit>>>((ref) {
  final allHabitsAsync = ref.watch(habitNotifierProvider);
  return allHabitsAsync.whenData((habits) {
    return habits.where((h) => h.isDueToday).toList();
  });
});

class HabitDayStatus {
  final bool isCompleted;
  final bool isSkipped;
  final bool isPostponed;
  final bool hasLog;

  const HabitDayStatus({
    required this.isCompleted,
    required this.isSkipped,
    required this.isPostponed,
    required this.hasLog,
  });

  static const HabitDayStatus empty = HabitDayStatus(
    isCompleted: false,
    isSkipped: false,
    isPostponed: false,
    hasLog: false,
  );

  bool get isDeferred => isSkipped || isPostponed;
  bool get isActioned => isCompleted || isDeferred;
}

class HabitsDashboardLists {
  final List<Habit> displayHabits;
  final List<Habit> completedHabits;
  final List<Habit> skippedHabits;
  final List<Habit> notDueHabits;

  const HabitsDashboardLists({
    required this.displayHabits,
    required this.completedHabits,
    required this.skippedHabits,
    required this.notDueHabits,
  });

  static const empty = HabitsDashboardLists(
    displayHabits: <Habit>[],
    completedHabits: <Habit>[],
    skippedHabits: <Habit>[],
    notDueHabits: <Habit>[],
  );
}

/// Memoized dashboard list computation for habits screen.
/// Moves heavy filtering/sorting work out of the widget build method.
///
/// For today's date, uses the synchronous [todayHabitStatusesProvider] so the
/// dashboard renders in a single frame without any async gap.
/// For other dates, falls back to the async [habitStatusesOnDateProvider].
final habitsDashboardListsProvider =
    Provider.family<
      HabitsDashboardLists,
      ({
        DateTime date,
        bool quitLocked,
        String selectedFilter,
        String sortBy,
        bool showOnlySpecial,
      })
    >((ref, args) {
      final trace = PerfTrace('HabitsProvider.dashboardLists');
      final allHabits = ref.watch(habitListValueProvider);
      if (allHabits.isEmpty) {
        trace.end('empty');
        return HabitsDashboardLists.empty;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final isToday = args.date == today;

      // Fast path: today's statuses are pre-computed (synchronous).
      // Slow path: other dates go through the async FutureProvider (with repo cache).
      final Map<String, HabitDayStatus> dayStatuses;
      if (isToday) {
        dayStatuses = ref.watch(todayHabitStatusesProvider);
      } else {
        dayStatuses = ref
            .watch(habitStatusesOnDateProvider(args.date))
            .maybeWhen(
              data: (statuses) => statuses,
              orElse: () => const <String, HabitDayStatus>{},
            );
      }
      trace.step(
        'statuses_ready',
        details: {
          'isToday': isToday,
          'statusCount': dayStatuses.length,
          'habitCount': allHabits.length,
        },
      );

      final displayHabits = <Habit>[];
      final completedHabits = <Habit>[];
      final skippedHabits = <Habit>[];
      final notDueHabits = <Habit>[];

      for (final habit in allHabits) {
        if (habit.isArchived) continue;
        if (habit.shouldHideQuitHabit) continue;
        if (args.quitLocked && habit.isQuitHabit) continue;

        if (habit.isDueOn(args.date)) {
          final status = dayStatuses[habit.id] ?? HabitDayStatus.empty;
          if (status.isCompleted) {
            completedHabits.add(habit);
          }
          if (status.isDeferred) {
            skippedHabits.add(habit);
          }
          if (_matchesDashboardDisplayFilter(
            habit: habit,
            status: status,
            selectedFilter: args.selectedFilter,
            showOnlySpecial: args.showOnlySpecial,
          )) {
            displayHabits.add(habit);
          }
        } else if (habit.isActiveOn(args.date)) {
          notDueHabits.add(habit);
        }
      }

      displayHabits.sort((a, b) => _compareDashboardHabits(a, b, args.sortBy));
      notDueHabits.sort(_compareSpecialThenTitle);
      completedHabits.sort(_compareSpecialThenTitle);
      skippedHabits.sort(_compareSpecialThenTitle);

      final output = HabitsDashboardLists(
        displayHabits: displayHabits,
        completedHabits: completedHabits,
        skippedHabits: skippedHabits,
        notDueHabits: notDueHabits,
      );
      trace.end(
        'done',
        details: {
          'display': output.displayHabits.length,
          'completed': output.completedHabits.length,
          'skipped': output.skippedHabits.length,
          'notDue': output.notDueHabits.length,
        },
      );
      return output;
    });

bool _matchesDashboardDisplayFilter({
  required Habit habit,
  required HabitDayStatus status,
  required String selectedFilter,
  required bool showOnlySpecial,
}) {
  if (showOnlySpecial && !habit.isSpecial) return false;

  final isCompleted = status.isCompleted;
  final isDeferred = status.isDeferred;

  switch (selectedFilter) {
    case 'completed':
      return isCompleted;
    case 'pending':
      return !isCompleted && !isDeferred;
    case 'streak':
      return habit.currentStreak > 0;
    case 'total':
    default:
      return !isCompleted && !isDeferred;
  }
}

int _compareDashboardHabits(Habit a, Habit b, String sortBy) {
  switch (sortBy) {
    case 'alphabetical':
      return a.title.compareTo(b.title);
    case 'streak':
      if (a.currentStreak != b.currentStreak) {
        return b.currentStreak.compareTo(a.currentStreak);
      }
      break;
    case 'newest':
      return b.createdAt.compareTo(a.createdAt);
    case 'priority':
    default:
      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      break;
  }

  return _compareSpecialThenTitle(a, b);
}

int _compareSpecialThenTitle(Habit a, Habit b) {
  if (a.isSpecial != b.isSpecial) {
    return a.isSpecial ? -1 : 1;
  }
  return a.title.compareTo(b.title);
}

/// Provider for all habit statuses on a specific date.
/// This batches completion lookup to avoid N database queries per list render.
final habitStatusesOnDateProvider =
    FutureProvider.family<Map<String, HabitDayStatus>, DateTime>((
      ref,
      date,
    ) async {
      final trace = PerfTrace('HabitsProvider.statusesOnDate');
      final habits = ref.watch(habitListValueProvider);
      final repository = ref.watch(habitRepositoryProvider);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (habits.isEmpty) {
        trace.end('empty');
        return const <String, HabitDayStatus>{};
      }

      final completionsByHabit = await repository
          .getCompletionsForAllHabitsOnDate(dateOnly);
      trace.step(
        'completions_loaded',
        details: {'groups': completionsByHabit.length, 'habits': habits.length},
      );
      final result = <String, HabitDayStatus>{};

      for (final habit in habits) {
        final completions =
            completionsByHabit[habit.id] ?? const <HabitCompletion>[];
        if (completions.isEmpty) {
          result[habit.id] = HabitDayStatus.empty;
          continue;
        }

        result[habit.id] = HabitDayStatus(
          isCompleted: _isCompletedForHabitOnDate(completions, habit),
          isSkipped: completions.any((c) => c.isSkipped),
          isPostponed: completions.any((c) => c.isPostponed),
          hasLog: true,
        );
      }

      trace.end('done', details: {'statuses': result.length});
      return result;
    });

/// Quit-only variant of day statuses for lighter work in quit-focused views.
/// Avoids scanning regular completions when only quit habits are displayed.
final quitHabitStatusesOnDateProvider =
    FutureProvider.family<Map<String, HabitDayStatus>, DateTime>((
      ref,
      date,
    ) async {
      final allHabits = ref.watch(habitListValueProvider);
      final repository = ref.watch(habitRepositoryProvider);
      final dateOnly = DateTime(date.year, date.month, date.day);

      final habits = allHabits.where((h) => h.isQuitHabit).toList();
      if (habits.isEmpty) return const <String, HabitDayStatus>{};

      final completionsByHabit = await repository
          .getCompletionsForAllHabitsOnDate(
            dateOnly,
            includeRegular: false,
            includeQuit: true,
          );
      final result = <String, HabitDayStatus>{};

      for (final habit in habits) {
        final completions =
            completionsByHabit[habit.id] ?? const <HabitCompletion>[];
        if (completions.isEmpty) {
          result[habit.id] = HabitDayStatus.empty;
          continue;
        }

        result[habit.id] = HabitDayStatus(
          isCompleted: _isCompletedForHabitOnDate(completions, habit),
          isSkipped: completions.any((c) => c.isSkipped),
          isPostponed: completions.any((c) => c.isPostponed),
          hasLog: true,
        );
      }

      return result;
    });

/// Provider for checking if a habit is completed on a specific date
final isHabitCompletedOnDateProvider =
    Provider.family<AsyncValue<bool>, ({String habitId, DateTime date})>((
      ref,
      params,
    ) {
      final statusesAsync = ref.watch(habitStatusesOnDateProvider(params.date));
      return statusesAsync.whenData(
        (statuses) => statuses[params.habitId]?.isCompleted ?? false,
      );
    });

/// Provider for checking if a habit is skipped on a specific date
final isHabitSkippedOnDateProvider =
    Provider.family<AsyncValue<bool>, ({String habitId, DateTime date})>((
      ref,
      params,
    ) {
      final statusesAsync = ref.watch(habitStatusesOnDateProvider(params.date));
      return statusesAsync.whenData(
        (statuses) => statuses[params.habitId]?.isSkipped ?? false,
      );
    });

/// Provider for checking if a habit is postponed on a specific date
final isHabitPostponedOnDateProvider =
    Provider.family<AsyncValue<bool>, ({String habitId, DateTime date})>((
      ref,
      params,
    ) {
      final statusesAsync = ref.watch(habitStatusesOnDateProvider(params.date));
      return statusesAsync.whenData(
        (statuses) => statuses[params.habitId]?.isPostponed ?? false,
      );
    });

/// Provider for checking if a habit is completed today
final isHabitCompletedTodayProvider = FutureProvider.family<bool, String>((
  ref,
  habitId,
) async {
  // Watch habitNotifierProvider to refresh when habits/completions change
  ref.watch(habitNotifierProvider);
  final repository = ref.watch(habitRepositoryProvider);
  return repository.isHabitCompletedToday(habitId);
});

/// Provider for checking if a habit is skipped today
final isHabitSkippedTodayProvider = FutureProvider.family<bool, String>((
  ref,
  habitId,
) async {
  // Watch habitNotifierProvider to refresh when habits/completions change
  ref.watch(habitNotifierProvider);
  final repository = ref.watch(habitRepositoryProvider);
  final completions = await repository.getCompletionsForDate(
    habitId,
    DateTime.now(),
  );
  return completions.any((c) => c.isSkipped);
});

/// Provider for completion count on a specific date
final habitCompletionCountOnDateProvider =
    FutureProvider.family<int, ({String habitId, DateTime date})>((
      ref,
      params,
    ) async {
      // Watch habitNotifierProvider to refresh when habits/completions change
      ref.watch(habitNotifierProvider);
      final repository = ref.watch(habitRepositoryProvider);
      final completions = await repository.getCompletionsForDate(
        params.habitId,
        params.date,
      );
      return completions
          .where((c) => !c.isSkipped)
          .fold<int>(0, (sum, c) => sum + c.count);
    });

/// Provider for habit statistics
final habitStatisticsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final repository = ref.watch(habitRepositoryProvider);
  return repository.getHabitStatistics();
});

/// Provider for a single habit by ID
final habitByIdProvider = Provider.family<AsyncValue<Habit?>, String>((
  ref,
  habitId,
) {
  final allHabitsAsync = ref.watch(habitNotifierProvider);
  return allHabitsAsync.whenData((habits) {
    try {
      return habits.firstWhere((h) => h.id == habitId);
    } catch (_) {
      return null;
    }
  });
});

/// Provider for habits by category
final habitsByCategoryProvider =
    Provider.family<AsyncValue<List<Habit>>, String>((ref, categoryId) {
      final allHabitsAsync = ref.watch(habitNotifierProvider);
      return allHabitsAsync.whenData((habits) {
        return habits.where((h) => h.categoryId == categoryId).toList();
      });
    });

/// Provider for habit completions in a date range
final habitCompletionsProvider =
    FutureProvider.family<
      List<HabitCompletion>,
      ({String habitId, DateTime startDate, DateTime endDate})
    >((ref, params) async {
      final repository = ref.watch(habitRepositoryProvider);
      return repository.getCompletionsInRange(
        params.habitId,
        params.startDate,
        params.endDate,
      );
    });

/// Provider for today's habits with completion status
final todayHabitsWithStatusProvider =
    FutureProvider<List<({Habit habit, bool isCompleted, int count})>>((
      ref,
    ) async {
      final repository = ref.watch(habitRepositoryProvider);
      final habits = await repository.getHabitsDueToday();
      final completionsByHabit = await repository
          .getCompletionsForAllHabitsOnDate(DateTime.now());

      final result = <({Habit habit, bool isCompleted, int count})>[];
      for (final habit in habits) {
        final completions =
            completionsByHabit[habit.id] ?? const <HabitCompletion>[];
        final isCompleted = _isCompletedForHabitOnDate(completions, habit);
        final count = completions
            .where((c) => !c.isSkipped && !c.isPostponed)
            .fold<int>(0, (sum, c) => sum + c.count);
        result.add((habit: habit, isCompleted: isCompleted, count: count));
      }

      return result;
    });

bool _isCompletedForHabitOnDate(
  List<HabitCompletion> completions,
  Habit habit,
) {
  if (completions.isEmpty) return false;
  return completions.any((c) {
    if (c.isSkipped || c.isPostponed) return false;
    switch (habit.completionType) {
      case 'yesNo':
      case 'yes_no':
        return c.answer == true || c.count > 0;
      case 'numeric':
        if (c.actualValue != null) {
          final target = habit.targetValue ?? 1;
          return c.actualValue! >= target;
        }
        return c.count > 0 || c.answer == true;
      case 'timer':
        if (c.actualDurationMinutes != null) {
          final target = habit.targetDurationMinutes ?? 1;
          return c.actualDurationMinutes! >= target;
        }
        return c.count > 0 || c.answer == true;
      case 'checklist':
        final itemCount = habit.checklist?.length ?? 1;
        return c.answer == true || c.count >= itemCount;
      case 'quit':
        if (c.answer != null) return c.answer == true;
        return c.count > 0;
      default:
        return c.count > 0 || c.answer == true;
    }
  });
}

