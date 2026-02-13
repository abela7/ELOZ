import 'package:hive_flutter/hive_flutter.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../services/quit_habit_secure_storage_service.dart';

/// Repository for habit CRUD operations using Hive
class HabitRepository {
  static const String habitsBoxName = 'habitsBox';
  static const String completionsBoxName = 'habitCompletionsBox';
  static const String secureQuitHabitsBoxName =
      QuitHabitSecureStorageService.secureHabitsBoxName;
  static const String secureQuitCompletionsBoxName =
      QuitHabitSecureStorageService.secureCompletionsBoxName;

  /// Cached box references for performance
  Box<Habit>? _habitsBox;
  Box<HabitCompletion>? _completionsBox;
  Box<Habit>? _quitHabitsBox;
  Box<HabitCompletion>? _quitCompletionsBox;
  final QuitHabitSecureStorageService _quitSecureStorage;

  // ---------------------------------------------------------------------------
  // In-memory completion-by-date cache
  // ---------------------------------------------------------------------------
  // Avoids repeated full Hive box scans for the same date.
  // Key: date-only (midnight). Value: habitId → completions list.
  // Automatically evicts stale entries when the cache exceeds _maxCachedDates.
  // ---------------------------------------------------------------------------
  static const int _maxCachedDates = 7;
  final Map<DateTime, Map<String, List<HabitCompletion>>> _completionDateCache =
      {};

  /// Invalidate cached completions for a specific date (or all dates).
  ///
  /// Call after any write operation that changes completions
  /// (addCompletion, addCompletionWithPoints, deleteCompletion, etc.)
  void invalidateCompletionCache([DateTime? date]) {
    if (date != null) {
      final key = DateTime(date.year, date.month, date.day);
      _completionDateCache.remove(key);
    } else {
      _completionDateCache.clear();
    }
  }

  HabitRepository({QuitHabitSecureStorageService? quitSecureStorage})
    : _quitSecureStorage = quitSecureStorage ?? QuitHabitSecureStorageService();

  /// Get the habits box (lazy initialization with caching)
  Future<Box<Habit>> _getHabitsBox() async {
    if (_habitsBox != null && _habitsBox!.isOpen) {
      return _habitsBox!;
    }
    _habitsBox = await HiveService.getBox<Habit>(habitsBoxName);
    return _habitsBox!;
  }

  /// Get the completions box (lazy initialization with caching)
  Future<Box<HabitCompletion>> _getCompletionsBox() async {
    if (_completionsBox != null && _completionsBox!.isOpen) {
      return _completionsBox!;
    }
    _completionsBox = await HiveService.getBox<HabitCompletion>(
      completionsBoxName,
    );
    return _completionsBox!;
  }

  /// Pre-open the encrypted quit habit & completion boxes so that subsequent
  /// reads (e.g. [getAllHabits]) return instantly instead of paying the
  /// Hive-AES open cost. Safe to call at any time — returns immediately if
  /// boxes are already open or the session is still locked.
  Future<void> warmUpSecureBoxes() async {
    await Future.wait([
      _getQuitHabitsBoxOrNull(),
      _getQuitCompletionsBoxOrNull(),
    ]);
  }

  // ==================== HABIT CRUD ====================

  /// Create a new habit
  ///
  /// NOTE: Initial stats calculation (_updateHabitStats) is intentionally
  /// NOT called here. It runs in the background via the provider layer
  /// (HabitNotifier._backgroundAfterSave) so the save returns instantly.
  Future<void> createHabit(Habit habit) async {
    if (habit.isQuitHabit) {
      final quitBox = await _getQuitHabitsBoxOrNull();
      if (quitBox == null) {
        throw StateError(
          'Quit secure storage is locked. Unlock quit habits to save quit data.',
        );
      }
      await quitBox.put(habit.id, habit);
    } else {
      final box = await _getHabitsBox();
      await box.put(habit.id, habit);
    }
  }

  /// Get all habits (excluding archived by default)
  Future<List<Habit>> getAllHabits({bool includeArchived = false}) async {
    final regularBox = await _getHabitsBox();
    final habits = regularBox.values.where((h) => !h.isQuitHabit).toList();

    final quitBox = await _getQuitHabitsBoxOrNull();
    if (quitBox != null) {
      habits.addAll(quitBox.values);
    }

    if (includeArchived) {
      return habits;
    }
    return habits.where((h) => !h.isArchived).toList();
  }

  /// Get habit by ID
  Future<Habit?> getHabitById(String id) async {
    final regularBox = await _getHabitsBox();
    final regularHabit = regularBox.get(id);
    if (regularHabit != null && !regularHabit.isQuitHabit) {
      return regularHabit;
    }
    final quitBox = await _getQuitHabitsBoxOrNull();
    return quitBox?.get(id);
  }

  /// Update an existing habit
  Future<void> updateHabit(Habit habit) async {
    final regularBox = await _getHabitsBox();
    final quitBox = await _getQuitHabitsBoxOrNull();

    if (habit.isQuitHabit) {
      if (quitBox == null) {
        throw StateError(
          'Quit secure storage is locked. Unlock quit habits to update quit data.',
        );
      }
      await regularBox.delete(habit.id);
      await quitBox.put(habit.id, habit);
      return;
    }

    await regularBox.put(habit.id, habit);
    await quitBox?.delete(habit.id);
  }

  /// Recalculate and update habit statistics (useful when startDate or frequency changes)
  Future<void> refreshHabitStats(String habitId) async {
    await _updateHabitStats(habitId);
  }

  /// Delete a habit and all its completions
  Future<void> deleteHabit(String id) async {
    final habitsBox = await _getHabitsBox();
    await habitsBox.delete(id);
    final quitHabitsBox = await _getQuitHabitsBoxOrNull();
    await quitHabitsBox?.delete(id);

    // Also delete all completions for this habit
    await deleteCompletionsForHabit(id);
  }

  /// Archive a habit (soft delete)
  Future<void> archiveHabit(String id) async {
    final habit = await getHabitById(id);
    if (habit != null) {
      habit.isArchived = true;
      habit.archivedAt = DateTime.now();
      await updateHabit(habit);
    }
  }

  /// Unarchive a habit
  Future<void> unarchiveHabit(String id) async {
    final habit = await getHabitById(id);
    if (habit != null) {
      habit.isArchived = false;
      habit.archivedAt = null;
      await updateHabit(habit);
    }
  }

  /// Get habits by category
  Future<List<Habit>> getHabitsByCategory(String categoryId) async {
    final habits = await getAllHabits();
    return habits.where((h) => h.categoryId == categoryId).toList();
  }

  /// Get habits due today
  Future<List<Habit>> getHabitsDueToday() async {
    final habits = await getAllHabits();
    return habits.where((h) => h.isDueToday).toList();
  }

  // ==================== COMPLETION OPERATIONS ====================

  /// Add a completion for a habit with proper points handling
  ///
  /// For regular habits: Awards points based on habit settings
  /// For quit habits: Awards daily reward for wins, deducts penalty for slips
  Future<void> addCompletion(HabitCompletion completion) async {
    await addCompletionsBulk([completion]);
  }

  /// Add a completion and update habit points atomically
  ///
  /// [completion] - The completion record
  /// [pointsDelta] - Points to add (positive) or deduct (negative) from habit
  /// [updateSlipCount] - For quit habits, increment slip count
  /// [resetStreak] - Whether to reset the streak (for slips)
  /// [updateMoneySaved] - For quit habits, update money saved
  /// [updateUnitsAvoided] - For quit habits, update units avoided
  /// [slipAmount] - Units consumed on a slip (defaults to completion.count)
  Future<void> addCompletionWithPoints(
    HabitCompletion completion, {
    int pointsDelta = 0,
    bool updateSlipCount = false,
    bool resetStreak = false,
    bool updateMoneySaved = false,
    bool updateUnitsAvoided = false,
    int? slipAmount,
  }) async {
    final habit = await getHabitById(completion.habitId);
    if (habit == null) return;
    final box = habit.isQuitHabit
        ? await _getQuitCompletionsBoxOrNull()
        : await _getCompletionsBox();
    if (box == null) {
      throw StateError(
        'Quit secure storage is locked. Unlock quit habits to write quit logs.',
      );
    }

    // Store points in the completion record for undo tracking
    final completionWithPoints = completion.copyWith(pointsEarned: pointsDelta);
    await box.put(completionWithPoints.id, completionWithPoints);

    // Invalidate cached completions for this date
    invalidateCompletionCache(completion.completedDate);

    // Update the habit's points
    habit.pointsEarned = habit.pointsEarned + pointsDelta;

    if (updateSlipCount && habit.isQuitHabit) {
      habit.currentSlipCount = (habit.currentSlipCount ?? 0) + 1;
    }

    if (resetStreak) {
      if (habit.isQuitHabit) {
        if (habit.shouldBreakStreakOnSlip()) {
          habit.currentStreak = 0;
          habit.resetSlipCount();
        }
        // Note: If streak doesn't break, slip count persists across wins
        // This allows streak protection to work correctly (e.g., 2 slips allowed)
      } else {
        habit.currentStreak = 0;
      }
    }

    // REMOVED: Don't reset slip count on every win
    // Slip count should only reset when streak breaks (handled above)
    // This allows streak protection to work: if protection = 2, you can slip twice
    // and still keep streak, even if there are wins in between

    if (habit.isQuitHabit && (updateMoneySaved || updateUnitsAvoided)) {
      final amount = slipAmount ?? completion.count;
      final costPerUnit = habit.costPerUnit ?? 0;
      final canTrackCost = habit.costTrackingEnabled == true && costPerUnit > 0;

      if (completion.isSkipped) {
        if (updateUnitsAvoided) {
          final updatedUnits = (habit.unitsAvoided ?? 0) - amount;
          habit.unitsAvoided = updatedUnits < 0 ? 0 : updatedUnits;
        }
        if (updateMoneySaved && canTrackCost) {
          final updatedMoney = (habit.moneySaved ?? 0) - (costPerUnit * amount);
          habit.moneySaved = updatedMoney < 0 ? 0 : updatedMoney;
        }
      } else {
        if (updateUnitsAvoided) {
          habit.unitsAvoided = (habit.unitsAvoided ?? 0) + 1;
        }
        if (updateMoneySaved && canTrackCost) {
          habit.moneySaved = (habit.moneySaved ?? 0) + costPerUnit;
        }
      }
    }

    await updateHabit(habit);

    // Update stats
    await _updateHabitStats(completion.habitId);
  }

  /// Add multiple completions at once (efficient for large imports)
  Future<void> addCompletionsBulk(List<HabitCompletion> completions) async {
    if (completions.isEmpty) return;

    final regularCompletionsMap = <String, HabitCompletion>{};
    final quitCompletionsMap = <String, HabitCompletion>{};

    for (final completion in completions) {
      final habit = await getHabitById(completion.habitId);
      if (habit == null) continue;
      if (habit.isQuitHabit) {
        quitCompletionsMap[completion.id] = completion;
      } else {
        regularCompletionsMap[completion.id] = completion;
      }
    }

    if (regularCompletionsMap.isNotEmpty) {
      final regularBox = await _getCompletionsBox();
      await regularBox.putAll(regularCompletionsMap);
    }
    if (quitCompletionsMap.isNotEmpty) {
      final quitBox = await _getQuitCompletionsBoxOrNull();
      if (quitBox == null) {
        throw StateError(
          'Quit secure storage is locked. Unlock quit habits to write quit logs.',
        );
      }
      await quitBox.putAll(quitCompletionsMap);
    }

    // Invalidate cached completions for all affected dates
    for (final c in completions) {
      invalidateCompletionCache(c.completedDate);
    }

    // Update habit stats only once per habit involved
    final uniqueHabitIds = completions.map((c) => c.habitId).toSet();
    for (final habitId in uniqueHabitIds) {
      await _updateHabitStats(habitId);
    }
  }

  /// Get all completions for a habit
  Future<List<HabitCompletion>> getCompletionsForHabit(String habitId) async {
    final habit = await getHabitById(habitId);
    if (habit == null) return const <HabitCompletion>[];

    if (habit.isQuitHabit) {
      final quitBox = await _getQuitCompletionsBoxOrNull();
      if (quitBox == null) return const <HabitCompletion>[];
      return quitBox.values.where((c) => c.habitId == habitId).toList();
    }

    final regularBox = await _getCompletionsBox();
    return regularBox.values.where((c) => c.habitId == habitId).toList();
  }

  /// Get completions for a habit on a specific date
  Future<List<HabitCompletion>> getCompletionsForDate(
    String habitId,
    DateTime date,
  ) async {
    final completions = await getCompletionsForHabit(habitId);
    return completions.where((c) => c.isForDate(date)).toList();
  }

  Future<Box<Habit>?> _getQuitHabitsBoxOrNull() async {
    if (_quitHabitsBox != null && _quitHabitsBox!.isOpen) {
      return _quitHabitsBox!;
    }
    if (!_quitSecureStorage.isSessionUnlocked) {
      return null;
    }
    _quitHabitsBox = await _quitSecureStorage.openSecureBox<Habit>(
      secureQuitHabitsBoxName,
    );
    return _quitHabitsBox!;
  }

  Future<Box<HabitCompletion>?> _getQuitCompletionsBoxOrNull() async {
    if (_quitCompletionsBox != null && _quitCompletionsBox!.isOpen) {
      return _quitCompletionsBox!;
    }
    if (!_quitSecureStorage.isSessionUnlocked) {
      return null;
    }
    _quitCompletionsBox = await _quitSecureStorage
        .openSecureBox<HabitCompletion>(secureQuitCompletionsBoxName);
    return _quitCompletionsBox!;
  }

  /// Get all completions grouped by habit id for a specific date.
  /// This avoids N queries when building day dashboards.
  ///
  /// Results for each date are cached in-memory. Subsequent calls for the same
  /// date return instantly without touching Hive. The cache is invalidated
  /// whenever completions are written (see [invalidateCompletionCache]).
  Future<Map<String, List<HabitCompletion>>> getCompletionsForAllHabitsOnDate(
    DateTime date, {
    bool includeRegular = true,
    bool includeQuit = true,
  }) async {
    final dateKey = DateTime(date.year, date.month, date.day);

    // Full cache hit — both regular & quit requested and we already have it.
    if (includeRegular && includeQuit && _completionDateCache.containsKey(dateKey)) {
      return _completionDateCache[dateKey]!;
    }

    final result = <String, List<HabitCompletion>>{};

    if (includeRegular) {
      final regularHabitsBox = await _getHabitsBox();
      final regularHabitIds = regularHabitsBox.values
          .where((h) => !h.isQuitHabit)
          .map((h) => h.id)
          .toSet();

      final regularCompletionsBox = await _getCompletionsBox();
      for (final completion in regularCompletionsBox.values) {
        if (!completion.isForDate(date)) continue;
        if (!regularHabitIds.contains(completion.habitId)) continue;
        result
            .putIfAbsent(completion.habitId, () => <HabitCompletion>[])
            .add(completion);
      }
    }

    if (includeQuit) {
      final quitHabitsBox = await _getQuitHabitsBoxOrNull();
      final quitCompletionsBox = await _getQuitCompletionsBoxOrNull();
      if (quitHabitsBox != null && quitCompletionsBox != null) {
        final quitHabitIds = quitHabitsBox.values.map((h) => h.id).toSet();
        for (final completion in quitCompletionsBox.values) {
          if (!completion.isForDate(date)) continue;
          if (!quitHabitIds.contains(completion.habitId)) continue;
          result
              .putIfAbsent(completion.habitId, () => <HabitCompletion>[])
              .add(completion);
        }
      }
    }

    // Cache only full (regular+quit) lookups to keep semantics simple.
    if (includeRegular && includeQuit) {
      // Evict oldest entries when cache is full
      if (_completionDateCache.length >= _maxCachedDates) {
        _completionDateCache.remove(_completionDateCache.keys.first);
      }
      _completionDateCache[dateKey] = result;
    }

    return result;
  }

  /// Get completions for a habit in a date range
  Future<List<HabitCompletion>> getCompletionsInRange(
    String habitId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final completions = await getCompletionsForHabit(habitId);
    return completions.where((c) {
      return c.completedDate.isAfter(
            startDate.subtract(const Duration(days: 1)),
          ) &&
          c.completedDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  /// Check if habit is completed today
  Future<bool> isHabitCompletedToday(String habitId) async {
    final today = DateTime.now();
    final completions = await getCompletionsForDate(habitId, today);
    return completions.any((c) => !c.isSkipped && c.count > 0);
  }

  /// Get today's completion count for a habit
  Future<int> getTodayCompletionCount(String habitId) async {
    final today = DateTime.now();
    final completions = await getCompletionsForDate(habitId, today);
    return completions
        .where((c) => !c.isSkipped)
        .fold<int>(0, (sum, c) => sum + c.count);
  }

  /// Delete a completion and revert its effects (points, slip count, etc.)
  ///
  /// This properly undoes everything:
  /// - Reverts points earned/lost
  /// - Reverts slip count for quit habits
  /// - Recalculates streak
  Future<void> deleteCompletion(String completionId) async {
    final regularBox = await _getCompletionsBox();
    var completion = regularBox.get(completionId);
    Box<HabitCompletion>? sourceBox = regularBox;
    if (completion == null) {
      final quitBox = await _getQuitCompletionsBoxOrNull();
      completion = quitBox?.get(completionId);
      sourceBox = quitBox;
    }

    if (completion == null || sourceBox == null) return;

    final habitId = completion.habitId;
    final habit = await getHabitById(habitId);

    // Revert points that were earned/lost with this completion
    if (habit != null && completion.pointsEarned != 0) {
      habit.pointsEarned = habit.pointsEarned - completion.pointsEarned;
    }

    if (habit != null && habit.isQuitHabit) {
      // For quit habit slips, revert the slip count
      if (completion.isSkipped) {
        habit.currentSlipCount = ((habit.currentSlipCount ?? 0) - 1).clamp(
          0,
          999999,
        );
      }

      final amount = completion.count;
      final costPerUnit = habit.costPerUnit ?? 0;
      final canTrackCost = habit.costTrackingEnabled == true && costPerUnit > 0;

      if (completion.isSkipped) {
        final updatedUnits = (habit.unitsAvoided ?? 0) + amount;
        habit.unitsAvoided = updatedUnits < 0 ? 0 : updatedUnits;
        if (canTrackCost) {
          habit.moneySaved = (habit.moneySaved ?? 0) + (costPerUnit * amount);
        }
      } else {
        final updatedUnits = (habit.unitsAvoided ?? 0) - 1;
        habit.unitsAvoided = updatedUnits < 0 ? 0 : updatedUnits;
        if (canTrackCost) {
          final updatedMoney = (habit.moneySaved ?? 0) - costPerUnit;
          habit.moneySaved = updatedMoney < 0 ? 0 : updatedMoney;
        }
      }
    }

    // Delete the completion
    await sourceBox.delete(completionId);

    // Invalidate cached completions for this date
    invalidateCompletionCache(completion.completedDate);

    // Save habit changes and recalculate stats
    if (habit != null) {
      await updateHabit(habit);
      await _updateHabitStats(habitId);
    }
  }

  /// Delete all completions for a date and revert their effects
  /// Returns the total points that were reverted
  Future<int> deleteCompletionsForDateWithRevert(
    String habitId,
    DateTime date,
  ) async {
    final completions = await getCompletionsForDate(habitId, date);
    int totalPointsReverted = 0;

    final habit = await getHabitById(habitId);
    if (habit == null) return 0;
    final completionBox = habit.isQuitHabit
        ? await _getQuitCompletionsBoxOrNull()
        : await _getCompletionsBox();
    if (completionBox == null) return 0;

    for (final completion in completions) {
      // Track points to revert
      totalPointsReverted += completion.pointsEarned;

      if (habit.isQuitHabit) {
        // For quit habit slips, revert the slip count
        if (completion.isSkipped) {
          habit.currentSlipCount = ((habit.currentSlipCount ?? 0) - 1).clamp(
            0,
            999999,
          );
        }

        final amount = completion.count;
        final costPerUnit = habit.costPerUnit ?? 0;
        final canTrackCost =
            habit.costTrackingEnabled == true && costPerUnit > 0;

        if (completion.isSkipped) {
          final updatedUnits = (habit.unitsAvoided ?? 0) + amount;
          habit.unitsAvoided = updatedUnits < 0 ? 0 : updatedUnits;
          if (canTrackCost) {
            habit.moneySaved = (habit.moneySaved ?? 0) + (costPerUnit * amount);
          }
        } else {
          final updatedUnits = (habit.unitsAvoided ?? 0) - 1;
          habit.unitsAvoided = updatedUnits < 0 ? 0 : updatedUnits;
          if (canTrackCost) {
            final updatedMoney = (habit.moneySaved ?? 0) - costPerUnit;
            habit.moneySaved = updatedMoney < 0 ? 0 : updatedMoney;
          }
        }
      }

      // Delete the completion
      await completionBox.delete(completion.id);
    }

    // Invalidate cached completions for this date
    invalidateCompletionCache(date);

    // Revert points
    habit.pointsEarned = habit.pointsEarned - totalPointsReverted;

    // Save and recalculate
    await updateHabit(habit);
    await _updateHabitStats(habitId);

    return totalPointsReverted;
  }

  /// Delete all completions for a habit
  Future<void> deleteCompletionsForHabit(String habitId) async {
    final habit = await getHabitById(habitId);
    if (habit == null) return;
    final box = habit.isQuitHabit
        ? await _getQuitCompletionsBoxOrNull()
        : await _getCompletionsBox();
    if (box == null) return;
    final toDelete = box.values
        .where((c) => c.habitId == habitId)
        .map((c) => c.id)
        .toList();

    for (final id in toDelete) {
      await box.delete(id);
    }

    // Invalidate all cached dates (completions for any date may have been removed)
    invalidateCompletionCache();
  }

  // ==================== AUTO-BACKFILL FOR QUIT HABITS ====================

  /// Automatically backfill "win" completions for quit habit past days
  ///
  /// For quit habits, if a past day has no log at all (no slip, no resist),
  /// it means the user successfully avoided the bad habit. We auto-create
  /// a "win" completion for that day WITH the daily reward points.
  ///
  /// This is smart because:
  /// - Asking "did you smoke yesterday?" could trigger cravings
  /// - If they didn't log a slip, they probably didn't slip
  /// - The system handles it silently in the background
  ///
  /// For regular habits: Do nothing - unlogged days remain as "missed"
  Future<void> autoBackfillQuitHabitWins(String habitId) async {
    final habit = await getHabitById(habitId);
    if (habit == null || !habit.isQuitHabit) return;
    if (habit.quitHabitActive == false) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDateOnly = DateTime(
      habit.startDate.year,
      habit.startDate.month,
      habit.startDate.day,
    );

    // Don't process if habit hasn't started yet
    if (today.isBefore(startDateOnly)) return;

    // Get all existing completions
    final completions = await getCompletionsForHabit(habitId);

    // Get all dates that already have a log (either win or slip)
    final loggedDates = completions
        .map(
          (c) => DateTime(
            c.completedDate.year,
            c.completedDate.month,
            c.completedDate.day,
          ),
        )
        .toSet();

    // Find past days without any log and create "win" completions for them
    final List<HabitCompletion> winsToAdd = [];
    int totalPointsToAdd = 0;
    int totalUnitsToAdd = 0;
    double totalMoneyToAdd = 0;
    DateTime checkDate = startDateOnly;

    // Daily reward for quit habit wins (default 10 if not set)
    final dailyReward = habit.dailyReward ?? habit.customYesPoints ?? 10;
    final costPerUnit = habit.costPerUnit ?? 0;
    final canTrackCost = habit.costTrackingEnabled == true && costPerUnit > 0;

    // Only check PAST days (before today)
    while (checkDate.isBefore(today)) {
      if (!habit.isActiveOn(checkDate)) {
        checkDate = checkDate.add(const Duration(days: 1));
        continue;
      }
      if (!loggedDates.contains(checkDate)) {
        // This past day has no log - auto-create a "win" completion with points
        winsToAdd.add(
          HabitCompletion(
            habitId: habitId,
            completedDate: checkDate,
            completedAt: DateTime(
              checkDate.year,
              checkDate.month,
              checkDate.day,
              23,
              59,
              59,
            ),
            count: 1,
            note: 'Auto: No slip logged',
            answer: true, // Mark as resisted
            pointsEarned: dailyReward, // Award daily reward points
          ),
        );
        totalPointsToAdd += dailyReward;
        totalUnitsToAdd += 1;
        if (canTrackCost) {
          totalMoneyToAdd += costPerUnit;
        }
      }
      checkDate = checkDate.add(const Duration(days: 1));
    }

    // Bulk add the auto-completions if any
    if (winsToAdd.isNotEmpty) {
      final box = await _getQuitCompletionsBoxOrNull();
      if (box == null) return;
      final Map<String, HabitCompletion> completionsMap = {
        for (var c in winsToAdd) c.id: c,
      };
      await box.putAll(completionsMap);

      // Invalidate cached completions for all affected dates
      for (final c in winsToAdd) {
        invalidateCompletionCache(c.completedDate);
      }

      // Update habit's total points
      habit.pointsEarned = habit.pointsEarned + totalPointsToAdd;
      if (totalUnitsToAdd > 0) {
        habit.unitsAvoided = (habit.unitsAvoided ?? 0) + totalUnitsToAdd;
      }
      if (totalMoneyToAdd > 0) {
        habit.moneySaved = (habit.moneySaved ?? 0) + totalMoneyToAdd;
      }
      // Note: Do NOT reset slip count on auto-wins.
      // Slip count should only reset when a streak actually breaks.
      await updateHabit(habit);

      // Update stats after backfill
      await _updateHabitStats(habitId);
    }
  }

  /// Backfill all quit habits at once (called on app startup)
  Future<void> autoBackfillAllQuitHabits() async {
    final habits = await getAllHabits();
    final quitHabits = habits.where((h) => h.isQuitHabit).toList();

    for (final habit in quitHabits) {
      await autoBackfillQuitHabitWins(habit.id);
    }
  }

  // ==================== STATS & STREAKS ====================

  bool _isCompletionSuccessful(HabitCompletion completion, Habit habit) {
    if (completion.isSkipped || completion.isPostponed) return false;
    if (completion.count <= 0) return false;
    if (habit.isNumeric) {
      final target = habit.targetValue ?? 0.0;
      final actual = completion.actualValue ?? 0.0;
      if (target <= 0) return actual > 0;
      return actual >= target;
    }
    if (habit.isTimer) {
      final target = habit.targetDurationMinutes ?? 0;
      final actual = completion.actualDurationMinutes ?? 0;
      if (target <= 0) return actual > 0;
      return actual >= target;
    }
    return true;
  }

  /// Update habit statistics after a completion change
  Future<void> _updateHabitStats(String habitId) async {
    final habit = await getHabitById(habitId);
    if (habit == null) return;

    final completions = await getCompletionsForHabit(habitId);

    // Successful completions (numeric must meet target)
    final successfulCompletions = completions
        .where((c) => _isCompletionSuccessful(c, habit))
        .toList();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Update total completions
    // After auto-backfill runs, quit habits have completion records for past wins.
    // So we can use the same counting logic for both habit types.
    if (habit.isQuitHabit) {
      // Count unique days with valid completions (wins)
      final winDates = successfulCompletions
          .map(
            (c) => DateTime(
              c.completedDate.year,
              c.completedDate.month,
              c.completedDate.day,
            ),
          )
          .toSet();
      habit.totalCompletions = winDates.length;
    } else {
      habit.totalCompletions = successfulCompletions.fold<int>(
        0,
        (sum, c) => sum + c.count,
      );
    }

    // Update last completed date
    if (successfulCompletions.isNotEmpty) {
      successfulCompletions.sort(
        (a, b) => b.completedDate.compareTo(a.completedDate),
      );
      habit.lastCompletedAt = successfulCompletions.first.completedAt;
    }

    // Calculate current streak
    habit.currentStreak = await _calculateCurrentStreak(habit, completions);

    // Update best streak if current is higher
    if (habit.currentStreak > habit.bestStreak) {
      habit.bestStreak = habit.currentStreak;
    }

    final goalMet = _meetsGoal(habit);
    if (!habit.hasGoal && habit.goalCompletedDate != null) {
      habit.goalCompletedDate = null;
    } else if (habit.hasGoal) {
      if (goalMet && habit.goalCompletedDate == null) {
        habit.goalCompletedDate = DateTime.now();
      } else if (!goalMet && habit.goalCompletedDate != null) {
        habit.goalCompletedDate = null;
      }
    }

    // Apply end condition and update habit status when reached.
    // End logic uses real logs: for end-by-date, we look at the last log on the end date.
    // For end-by-occurrences, reaching the count is considered a successful finish.
    final todayOnly = DateTime(todayDate.year, todayDate.month, todayDate.day);
    bool endReached = false;
    bool endSuccessful = false;

    if (habit.endCondition == 'after_occurrences' &&
        habit.endOccurrences != null) {
      if (habit.totalCompletions >= habit.endOccurrences!) {
        endReached = true;
        endSuccessful = true;
      }
    } else if (habit.endCondition == 'on_date' && habit.endDate != null) {
      final endDateOnly = DateTime(
        habit.endDate!.year,
        habit.endDate!.month,
        habit.endDate!.day,
      );
      final hasLogOnEndDate = completions.any((c) {
        final dateOnly = DateTime(
          c.completedDate.year,
          c.completedDate.month,
          c.completedDate.day,
        );
        return dateOnly == endDateOnly;
      });

      if (todayOnly.isAfter(endDateOnly) || hasLogOnEndDate) {
        endReached = true;

        if (hasLogOnEndDate) {
          final endDateLogs = completions.where((c) {
            final dateOnly = DateTime(
              c.completedDate.year,
              c.completedDate.month,
              c.completedDate.day,
            );
            return dateOnly == endDateOnly;
          }).toList()..sort((a, b) => b.completedAt.compareTo(a.completedAt));

          final lastLog = endDateLogs.first;
          endSuccessful = _isCompletionSuccessful(lastLog, habit);
        } else {
          endSuccessful = false;
        }
      }
    }

    if (endReached &&
        (habit.habitStatus == 'active' || habit.habitStatus == 'paused')) {
      final successStatus =
          (habit.hasGoal ||
              habit.endCondition == 'after_occurrences' ||
              habit.isQuitHabit)
          ? 'completed'
          : 'built';
      habit.habitStatus = endSuccessful ? successStatus : 'failed';
      habit.statusChangedDate = DateTime.now();
      if (habit.isQuitHabit) {
        habit.quitHabitActive = false;
        habit.quitCompletedDate = endSuccessful
            ? DateTime.now()
            : habit.quitCompletedDate;
      }
    }

    await updateHabit(habit);
  }

  /// Calculate the current streak for a habit
  Future<int> _calculateCurrentStreak(
    Habit habit,
    List<HabitCompletion> completions,
  ) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final startDateOnly = DateTime(
      habit.startDate.year,
      habit.startDate.month,
      habit.startDate.day,
    );

    // If habit hasn't started yet, streak is 0
    if (todayDate.isBefore(startDateOnly)) return 0;

    // Get unique dates for completions and skips
    final completedDates = completions
        .where((c) => _isCompletionSuccessful(c, habit))
        .map(
          (c) => DateTime(
            c.completedDate.year,
            c.completedDate.month,
            c.completedDate.day,
          ),
        )
        .toSet();

    final skippedDates = completions
        .where((c) => c.isSkipped || c.isPostponed)
        .map(
          (c) => DateTime(
            c.completedDate.year,
            c.completedDate.month,
            c.completedDate.day,
          ),
        )
        .toSet();

    int streak = 0;
    DateTime checkDate = todayDate;

    // For Quit Habits: Streak continues if NOT skipped (not slipped)
    // After auto-backfill, past days have completion records for wins.
    if (habit.isQuitHabit) {
      final allowedSlips = habit.streakProtection ?? 0;
      int slipsUsed = 0;

      // Check if user has explicitly logged a "resist" for today
      // OR if today has a completion record (from any source)
      final todayHasWin = completedDates.contains(todayDate);
      final todayHasSlip = skippedDates.contains(todayDate);

      // If today has no log yet, start counting from YESTERDAY
      // Today is still "in progress" - can't count it as a win yet
      if (!todayHasWin && !todayHasSlip) {
        checkDate = todayDate.subtract(const Duration(days: 1));
      }

      // Count consecutive days with wins, allowing limited slips
      while (!checkDate.isBefore(startDateOnly)) {
        if (skippedDates.contains(checkDate)) {
          slipsUsed++;
          if (slipsUsed > allowedSlips) {
            break;
          }
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }
        if (completedDates.contains(checkDate)) {
          // Has a win record (manual or auto-backfilled)
          streak++;
        } else {
          // No record = gap in streak (shouldn't happen after backfill, but handle edge case)
          break;
        }
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
      return streak;
    }

    // For Regular Habits:
    // If not completed today, start checking from yesterday
    if (!completedDates.contains(todayDate)) {
      // Check if it's even due today. If not due today, streak continues from yesterday.
      // But if it IS due today and not done, the streak hasn't "broken" yet until the day is over.
      // However, for "current streak" display, we usually show streak up to yesterday if today isn't done.
      checkDate = todayDate.subtract(const Duration(days: 1));
    }

    while (!checkDate.isBefore(startDateOnly)) {
      final weekday = checkDate.weekday % 7; // 0=Sunday
      bool isDue = false;

      // Determine if habit was due on checkDate
      switch (habit.frequency) {
        case HabitFrequency.daily:
          isDue = true;
          break;
        case HabitFrequency.weekly:
          isDue = habit.weekDays?.contains(weekday) ?? false;
          break;
        case HabitFrequency.xTimesPerWeek:
        case HabitFrequency.xTimesPerMonth:
        case HabitFrequency.custom:
          // For flexible habits, streak is just consecutive completions
          isDue = completedDates.contains(checkDate);
          break;
      }

      if (isDue) {
        if (completedDates.contains(checkDate)) {
          streak++;
        } else if (skippedDates.contains(checkDate)) {
          // Explicitly skipped breaks the streak
          break;
        } else {
          // Missed a due day breaks the streak
          break;
        }
      }

      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  bool _meetsGoal(Habit habit) {
    if (!habit.hasGoal) return false;

    switch (habit.goalType) {
      case 'streak':
        return habit.currentStreak >= (habit.goalTarget ?? 0);
      case 'count':
        return habit.totalCompletions >= (habit.goalTarget ?? 0);
      case 'duration':
        if (habit.goalStartDate == null) return false;
        final daysSinceStart = DateTime.now()
            .difference(habit.goalStartDate!)
            .inDays;
        return daysSinceStart >= (habit.goalTarget ?? 0);
      default:
        return false;
    }
  }

  /// Get habit statistics
  Future<Map<String, dynamic>> getHabitStatistics() async {
    final habits = await getAllHabits();
    final completedToday = <Habit>[];
    final pendingToday = <Habit>[];

    for (final habit in habits) {
      if (habit.isDueToday) {
        final isCompleted = await isHabitCompletedToday(habit.id);
        if (isCompleted) {
          completedToday.add(habit);
        } else {
          pendingToday.add(habit);
        }
      }
    }

    return {
      'total': habits.length,
      'dueToday': completedToday.length + pendingToday.length,
      'completedToday': completedToday.length,
      'pendingToday': pendingToday.length,
      'totalStreaks': habits.fold<int>(0, (sum, h) => sum + h.currentStreak),
      'bestStreak': habits.isEmpty
          ? 0
          : habits.map((h) => h.bestStreak).reduce((a, b) => a > b ? a : b),
    };
  }

  /// Delete all habits (for reset functionality)
  Future<void> deleteAllHabits() async {
    final habitsBox = await _getHabitsBox();
    final completionsBox = await _getCompletionsBox();
    await habitsBox.clear();
    await completionsBox.clear();
    final quitHabitsBox = await _getQuitHabitsBoxOrNull();
    final quitCompletionsBox = await _getQuitCompletionsBoxOrNull();
    await quitHabitsBox?.clear();
    await quitCompletionsBox?.clear();
    invalidateCompletionCache();
  }
}
