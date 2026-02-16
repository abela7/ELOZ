import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/data/history_optimization_models.dart';
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
  static const String _regularCompletionsDateIndexBoxName =
      'habit_completions_date_index_v1';
  static const String _regularCompletionsHabitIndexBoxName =
      'habit_completions_habit_index_v1';
  static const String _habitDailySummaryBoxName = 'habit_daily_summary_v1';
  static const String _regularCompletionsIndexMetaBoxName =
      'habit_completions_index_meta_v1';
  static const String _rebuildNeededMetaKey = 'rebuild_needed';
  static const String _indexedFromMetaKey = 'indexed_from_date_key';
  static const String _oldestDataMetaKey = 'oldest_data_date_key';
  static const String _lastIndexedMetaKey = 'last_indexed_date_key';
  static const String _backfillCompleteMetaKey = 'backfill_complete';
  static const String _backfillPausedMetaKey = 'backfill_paused';
  static const int _bootstrapWindowDays = 30;
  static const int _defaultBackfillChunkDays = 30;
  static const int _sessionScanYieldInterval = 450;
  static const int _regularCompletionsIndexVersion = 1;

  /// Cached box references for performance
  Box<Habit>? _habitsBox;
  Box<HabitCompletion>? _completionsBox;
  Box<Habit>? _quitHabitsBox;
  Box<HabitCompletion>? _quitCompletionsBox;
  Box<dynamic>? _regularCompletionsDateIndexBox;
  Box<dynamic>? _regularCompletionsHabitIndexBox;
  Box<dynamic>? _habitDailySummaryBox;
  Box<dynamic>? _regularCompletionsIndexMetaBox;
  bool _regularCompletionIndexesReady = false;
  bool _regularCompletionIntegrityChecked = false;
  bool _useRegularCompletionIndexes = true;
  bool _regularBackfillComplete = false;
  DateTime? _regularIndexedFromDate;
  final QuitHabitSecureStorageService _quitSecureStorage;
  final Future<Box<Habit>> Function()? _habitsBoxOpener;
  final Future<Box<HabitCompletion>> Function()? _completionsBoxOpener;
  final Future<Box<dynamic>> Function(String boxName)? _dynamicBoxOpener;

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

  HabitRepository({
    QuitHabitSecureStorageService? quitSecureStorage,
    Future<Box<Habit>> Function()? habitsBoxOpener,
    Future<Box<HabitCompletion>> Function()? completionsBoxOpener,
    Future<Box<dynamic>> Function(String boxName)? dynamicBoxOpener,
  }) : _quitSecureStorage =
           quitSecureStorage ?? QuitHabitSecureStorageService(),
       _habitsBoxOpener = habitsBoxOpener,
       _completionsBoxOpener = completionsBoxOpener,
       _dynamicBoxOpener = dynamicBoxOpener;

  /// Get the habits box (lazy initialization with caching)
  Future<Box<Habit>> _getHabitsBox() async {
    if (_habitsBox != null && _habitsBox!.isOpen) {
      return _habitsBox!;
    }
    final opener = _habitsBoxOpener;
    if (opener != null) {
      _habitsBox = await opener();
    } else {
      _habitsBox = await HiveService.getBox<Habit>(habitsBoxName);
    }
    return _habitsBox!;
  }

  /// Get the completions box (lazy initialization with caching)
  Future<Box<HabitCompletion>> _getCompletionsBox() async {
    if (_completionsBox != null && _completionsBox!.isOpen) {
      return _completionsBox!;
    }
    final opener = _completionsBoxOpener;
    if (opener != null) {
      _completionsBox = await opener();
    } else {
      _completionsBox = await HiveService.getBox<HabitCompletion>(
        completionsBoxName,
      );
    }
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
    if (!habit.isQuitHabit) {
      await _ensureRegularCompletionIndexesReady();
    }

    // Store points in the completion record for undo tracking
    final completionWithPoints = completion.copyWith(pointsEarned: pointsDelta);
    final previous = habit.isQuitHabit
        ? null
        : box.get(completionWithPoints.id);
    await box.put(completionWithPoints.id, completionWithPoints);
    if (!habit.isQuitHabit) {
      if (previous != null) {
        await _removeRegularCompletionFromIndexes(previous);
      }
      await _addRegularCompletionToIndexes(completionWithPoints);
    }

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
      await _ensureRegularCompletionIndexesReady();
      final regularBox = await _getCompletionsBox();
      final existing = <String, HabitCompletion>{};
      for (final id in regularCompletionsMap.keys) {
        final previous = regularBox.get(id);
        if (previous != null) {
          existing[id] = previous;
        }
      }
      await regularBox.putAll(regularCompletionsMap);
      for (final completion in existing.values) {
        await _removeRegularCompletionFromIndexes(completion);
      }
      await _addRegularCompletionsToIndexes(regularCompletionsMap.values);
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

    await _ensureRegularCompletionIndexesReady();
    final regularBox = await _getCompletionsBox();
    if (!_useRegularCompletionIndexes || !_regularBackfillComplete) {
      return regularBox.values.where((c) => c.habitId == habitId).toList();
    }
    final ids = _readStringList(
      (await _getRegularCompletionsHabitIndexBox()).get(habitId),
    );
    if (ids.isEmpty) {
      return const <HabitCompletion>[];
    }

    final completions = <HabitCompletion>[];
    for (final id in ids) {
      final completion = regularBox.get(id);
      if (completion != null && completion.habitId == habitId) {
        completions.add(completion);
      }
    }
    return completions;
  }

  /// Get completions for a habit on a specific date
  Future<List<HabitCompletion>> getCompletionsForDate(
    String habitId,
    DateTime date,
  ) async {
    final habit = await getHabitById(habitId);
    if (habit == null) return const <HabitCompletion>[];
    if (habit.isQuitHabit) {
      final completions = await getCompletionsForHabit(habitId);
      return completions.where((c) => c.isForDate(date)).toList();
    }

    await _ensureRegularCompletionIndexesReady();
    final regularBox = await _getCompletionsBox();
    if (!_useRegularCompletionIndexes ||
        !_isDateWithinRegularIndexedRange(date)) {
      return regularBox.values.where((c) {
        return c.habitId == habitId && c.isForDate(date);
      }).toList();
    }
    final dateIds = _readStringList(
      (await _getRegularCompletionsDateIndexBox()).get(_dateKey(date)),
    );
    if (dateIds.isEmpty) {
      return const <HabitCompletion>[];
    }

    final completions = <HabitCompletion>[];
    for (final id in dateIds) {
      final completion = regularBox.get(id);
      if (completion != null && completion.habitId == habitId) {
        completions.add(completion);
      }
    }
    return completions;
  }

  /// Get cached per-day completion summary for regular habits.
  Future<Map<String, int>> getDailyCompletionSummary(DateTime date) async {
    await _ensureRegularCompletionIndexesReady();
    if (!_useRegularCompletionIndexes ||
        !_isDateWithinRegularIndexedRange(date)) {
      return _buildDailyCompletionSummaryFromCompletions(
        (await _getCompletionsBox()).values.where((c) => c.isForDate(date)),
      );
    }
    final value = (await _getHabitDailySummaryBox()).get(_dateKey(date));
    return _readSummaryMap(value);
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

  Future<Box<dynamic>> _getRegularCompletionsDateIndexBox() async {
    if (_regularCompletionsDateIndexBox != null &&
        _regularCompletionsDateIndexBox!.isOpen) {
      return _regularCompletionsDateIndexBox!;
    }
    _regularCompletionsDateIndexBox = await _openDynamicBox(
      _regularCompletionsDateIndexBoxName,
    );
    return _regularCompletionsDateIndexBox!;
  }

  Future<Box<dynamic>> _getRegularCompletionsHabitIndexBox() async {
    if (_regularCompletionsHabitIndexBox != null &&
        _regularCompletionsHabitIndexBox!.isOpen) {
      return _regularCompletionsHabitIndexBox!;
    }
    _regularCompletionsHabitIndexBox = await _openDynamicBox(
      _regularCompletionsHabitIndexBoxName,
    );
    return _regularCompletionsHabitIndexBox!;
  }

  Future<Box<dynamic>> _getHabitDailySummaryBox() async {
    if (_habitDailySummaryBox != null && _habitDailySummaryBox!.isOpen) {
      return _habitDailySummaryBox!;
    }
    _habitDailySummaryBox = await _openDynamicBox(_habitDailySummaryBoxName);
    return _habitDailySummaryBox!;
  }

  Future<Box<dynamic>> _getRegularCompletionsIndexMetaBox() async {
    if (_regularCompletionsIndexMetaBox != null &&
        _regularCompletionsIndexMetaBox!.isOpen) {
      return _regularCompletionsIndexMetaBox!;
    }
    _regularCompletionsIndexMetaBox = await _openDynamicBox(
      _regularCompletionsIndexMetaBoxName,
    );
    return _regularCompletionsIndexMetaBox!;
  }

  Future<Box<dynamic>> _openDynamicBox(String boxName) async {
    final opener = _dynamicBoxOpener;
    if (opener != null) {
      return opener(boxName);
    }
    return HiveService.getBox<dynamic>(boxName);
  }

  Future<void> _ensureRegularCompletionIndexesReady() async {
    if (_regularCompletionIndexesReady) return;
    final metaBox = await _getRegularCompletionsIndexMetaBox();
    final version = _asInt(metaBox.get('version'));
    final rebuildNeeded = metaBox.get(_rebuildNeededMetaKey) == true;
    final hasBootstrapWindow =
        metaBox.get(_indexedFromMetaKey) is String &&
        metaBox.get(_oldestDataMetaKey) is String;
    var attemptedRebuild = false;

    if (version != _regularCompletionsIndexVersion ||
        rebuildNeeded ||
        !hasBootstrapWindow) {
      final reason = version != _regularCompletionsIndexVersion
          ? 'version_mismatch'
          : rebuildNeeded
          ? 'rebuild_needed_flag'
          : 'missing_bootstrap_window';
      await _bootstrapRecentRegularCompletionIndexes(reason: reason);
      await metaBox.put('version', _regularCompletionsIndexVersion);
      attemptedRebuild = true;
    }

    if (!_regularCompletionIntegrityChecked) {
      var valid = await _hasValidRegularCompletionIndexes();
      if (!valid && !attemptedRebuild) {
        await _bootstrapRecentRegularCompletionIndexes(
          reason: 'integrity_mismatch',
        );
        await metaBox.put('version', _regularCompletionsIndexVersion);
        valid = await _hasValidRegularCompletionIndexes();
      }

      if (!valid) {
        _useRegularCompletionIndexes = false;
        await metaBox.put(_rebuildNeededMetaKey, true);
        _debugLog(
          'Regular completion indexes remained invalid after rebuild; using scan mode for this session.',
        );
      } else {
        _useRegularCompletionIndexes = true;
        await metaBox.delete(_rebuildNeededMetaKey);
      }
      _regularIndexedFromDate = _parseDateKey(
        '${metaBox.get(_indexedFromMetaKey)}',
      );
      _regularBackfillComplete = metaBox.get(_backfillCompleteMetaKey) == true;
      _regularCompletionIntegrityChecked = true;
    }

    _regularCompletionIndexesReady = true;
  }

  Future<bool> _hasValidRegularCompletionIndexes() async {
    final completionsBox = await _getCompletionsBox();
    if (completionsBox.isEmpty) return true;
    final indexedFrom =
        _regularIndexedFromDate ??
        _parseDateKey(
          '${(await _getRegularCompletionsIndexMetaBox()).get(_indexedFromMetaKey)}',
        );
    if (indexedFrom == null) {
      return false;
    }

    var expectedCount = 0;
    for (final completion in completionsBox.values) {
      if (!_isDateBefore(completion.completedDate, indexedFrom)) {
        expectedCount++;
      }
    }

    var dateIndexedCount = 0;
    for (final dynamic value
        in (await _getRegularCompletionsDateIndexBox()).values) {
      dateIndexedCount += _readStringList(value).length;
    }
    if (dateIndexedCount != expectedCount) {
      return false;
    }

    var habitIndexedCount = 0;
    for (final dynamic value
        in (await _getRegularCompletionsHabitIndexBox()).values) {
      habitIndexedCount += _readStringList(value).length;
    }
    if (habitIndexedCount != expectedCount) {
      return false;
    }

    var summarizedTotal = 0;
    for (final dynamic value in (await _getHabitDailySummaryBox()).values) {
      summarizedTotal += _readSummaryMap(value)['entries'] ?? 0;
    }
    return summarizedTotal == expectedCount;
  }

  Future<void> _bootstrapRecentRegularCompletionIndexes({
    required String reason,
  }) async {
    final completionsBox = await _getCompletionsBox();
    final recordCount = completionsBox.length;
    final stopwatch = Stopwatch()..start();
    final dateIndexBox = await _getRegularCompletionsDateIndexBox();
    final habitIndexBox = await _getRegularCompletionsHabitIndexBox();
    final summaryBox = await _getHabitDailySummaryBox();
    final metaBox = await _getRegularCompletionsIndexMetaBox();

    await dateIndexBox.clear();
    await habitIndexBox.clear();
    await summaryBox.clear();

    final dateIndex = <String, List<String>>{};
    final habitIndex = <String, List<String>>{};
    final dailySummary = <String, Map<String, int>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bootstrapFrom = today.subtract(
      const Duration(days: _bootstrapWindowDays - 1),
    );
    DateTime? oldestData;
    var scanned = 0;

    for (final completion in completionsBox.values) {
      scanned++;
      if (scanned % _sessionScanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final completedDate = DateTime(
        completion.completedDate.year,
        completion.completedDate.month,
        completion.completedDate.day,
      );
      if (oldestData == null || completedDate.isBefore(oldestData)) {
        oldestData = completedDate;
      }
      if (_isDateBefore(completedDate, bootstrapFrom)) {
        continue;
      }

      final dateKey = _dateKey(completion.completedDate);
      dateIndex.putIfAbsent(dateKey, () => <String>[]).add(completion.id);
      habitIndex
          .putIfAbsent(completion.habitId, () => <String>[])
          .add(completion.id);
      _applyCompletionDelta(
        dailySummary.putIfAbsent(dateKey, _newDailySummary),
        completion,
        1,
      );
    }

    if (dateIndex.isNotEmpty) {
      await dateIndexBox.putAll(dateIndex);
    }
    if (habitIndex.isNotEmpty) {
      await habitIndexBox.putAll(habitIndex);
    }
    if (dailySummary.isNotEmpty) {
      await summaryBox.putAll(dailySummary);
    }

    final indexedFrom = oldestData == null || oldestData.isAfter(bootstrapFrom)
        ? (oldestData ?? today)
        : bootstrapFrom;
    final backfillComplete =
        oldestData == null || !indexedFrom.isAfter(oldestData);
    await metaBox.put(_indexedFromMetaKey, _dateKey(indexedFrom));
    await metaBox.put(_oldestDataMetaKey, _dateKey(oldestData ?? indexedFrom));
    await metaBox.put(_lastIndexedMetaKey, _dateKey(indexedFrom));
    await metaBox.put(_backfillCompleteMetaKey, backfillComplete);
    await metaBox.put(_backfillPausedMetaKey, false);
    await metaBox.delete(_rebuildNeededMetaKey);

    _regularIndexedFromDate = indexedFrom;
    _regularBackfillComplete = backfillComplete;
    _useRegularCompletionIndexes = true;

    stopwatch.stop();
    _debugLog(
      'Regular completion index rebuild finished. reason=$reason records=$recordCount durationMs=${stopwatch.elapsedMilliseconds}',
    );
  }

  Future<void> _addRegularCompletionsToIndexes(
    Iterable<HabitCompletion> completions,
  ) async {
    if (!_useRegularCompletionIndexes) return;
    for (final completion in completions) {
      await _addRegularCompletionToIndexes(completion);
    }
  }

  Future<void> _addRegularCompletionToIndexes(
    HabitCompletion completion,
  ) async {
    if (!_useRegularCompletionIndexes ||
        !_isDateWithinRegularIndexedRange(completion.completedDate)) {
      await _markRegularBackfillNeededForDate(completion.completedDate);
      return;
    }
    final dateKey = _dateKey(completion.completedDate);
    final dateIndexBox = await _getRegularCompletionsDateIndexBox();
    final idsForDate = _readStringList(dateIndexBox.get(dateKey));
    if (!idsForDate.contains(completion.id)) {
      idsForDate.add(completion.id);
      await dateIndexBox.put(dateKey, idsForDate);
    }

    final habitIndexBox = await _getRegularCompletionsHabitIndexBox();
    final idsForHabit = _readStringList(habitIndexBox.get(completion.habitId));
    if (!idsForHabit.contains(completion.id)) {
      idsForHabit.add(completion.id);
      await habitIndexBox.put(completion.habitId, idsForHabit);
    }

    final summaryBox = await _getHabitDailySummaryBox();
    final summary = _readSummaryMap(summaryBox.get(dateKey));
    _applyCompletionDelta(summary, completion, 1);
    await _writeOrDeleteDailySummary(summaryBox, dateKey, summary);
  }

  Future<void> _removeRegularCompletionFromIndexes(
    HabitCompletion completion,
  ) async {
    if (!_useRegularCompletionIndexes ||
        !_isDateWithinRegularIndexedRange(completion.completedDate)) {
      return;
    }
    final dateKey = _dateKey(completion.completedDate);
    final dateIndexBox = await _getRegularCompletionsDateIndexBox();
    final idsForDate = _readStringList(dateIndexBox.get(dateKey));
    idsForDate.remove(completion.id);
    if (idsForDate.isEmpty) {
      await dateIndexBox.delete(dateKey);
    } else {
      await dateIndexBox.put(dateKey, idsForDate);
    }

    final habitIndexBox = await _getRegularCompletionsHabitIndexBox();
    final idsForHabit = _readStringList(habitIndexBox.get(completion.habitId));
    idsForHabit.remove(completion.id);
    if (idsForHabit.isEmpty) {
      await habitIndexBox.delete(completion.habitId);
    } else {
      await habitIndexBox.put(completion.habitId, idsForHabit);
    }

    final summaryBox = await _getHabitDailySummaryBox();
    final summary = _readSummaryMap(summaryBox.get(dateKey));
    _applyCompletionDelta(summary, completion, -1);
    await _writeOrDeleteDailySummary(summaryBox, dateKey, summary);
  }

  Future<void> _writeOrDeleteDailySummary(
    Box<dynamic> summaryBox,
    String dateKey,
    Map<String, int> summary,
  ) async {
    if ((summary['entries'] ?? 0) <= 0) {
      await summaryBox.delete(dateKey);
      return;
    }
    await summaryBox.put(dateKey, summary);
  }

  Map<String, int> _newDailySummary() {
    return <String, int>{
      'entries': 0,
      'successfulEntries': 0,
      'skippedEntries': 0,
      'postponedEntries': 0,
      'totalCount': 0,
    };
  }

  Map<String, int> _readSummaryMap(Object? value) {
    final summary = _newDailySummary();
    if (value is Map) {
      for (final entry in value.entries) {
        final key = '${entry.key}';
        if (!summary.containsKey(key)) continue;
        summary[key] = _asInt(entry.value);
      }
    }
    return summary;
  }

  void _applyCompletionDelta(
    Map<String, int> summary,
    HabitCompletion completion,
    int delta,
  ) {
    summary['entries'] = (summary['entries'] ?? 0) + delta;
    if (completion.isPostponed) {
      summary['postponedEntries'] = (summary['postponedEntries'] ?? 0) + delta;
    } else if (completion.isSkipped) {
      summary['skippedEntries'] = (summary['skippedEntries'] ?? 0) + delta;
    } else if (completion.count > 0) {
      summary['successfulEntries'] =
          (summary['successfulEntries'] ?? 0) + delta;
    }
    summary['totalCount'] =
        (summary['totalCount'] ?? 0) + (completion.count * delta);

    for (final key in summary.keys.toList()) {
      final value = summary[key] ?? 0;
      summary[key] = value < 0 ? 0 : value;
    }
  }

  List<String> _readStringList(Object? value) {
    if (value is! List) return <String>[];
    return value.map((dynamic item) => '$item').toList();
  }

  String _dateKey(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy$mm$dd';
  }

  DateTime? _parseDateKey(String key) {
    if (key.length != 8) return null;
    final year = int.tryParse(key.substring(0, 4));
    final month = int.tryParse(key.substring(4, 6));
    final day = int.tryParse(key.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  List<String> _dateKeysInRange(DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) {
      return const <String>[];
    }

    final keys = <String>[];
    var current = start;
    while (!current.isAfter(end)) {
      keys.add(_dateKey(current));
      current = current.add(const Duration(days: 1));
    }
    return keys;
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool _isDateWithinRegularIndexedRange(DateTime date) {
    final indexedFrom = _regularIndexedFromDate;
    if (!_useRegularCompletionIndexes || indexedFrom == null) return false;
    return !_isDateBefore(date, indexedFrom);
  }

  bool _isRangeFullyRegularIndexed(DateTime startDate, DateTime endDate) {
    if (!_useRegularCompletionIndexes) return false;
    if (_regularBackfillComplete) return true;
    final indexedFrom = _regularIndexedFromDate;
    if (indexedFrom == null) return false;
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) return false;
    return !start.isBefore(indexedFrom);
  }

  bool _isDateBefore(DateTime a, DateTime b) {
    final aOnly = DateTime(a.year, a.month, a.day);
    final bOnly = DateTime(b.year, b.month, b.day);
    return aOnly.isBefore(bOnly);
  }

  bool _isDateAfter(DateTime a, DateTime b) {
    final aOnly = DateTime(a.year, a.month, a.day);
    final bOnly = DateTime(b.year, b.month, b.day);
    return aOnly.isAfter(bOnly);
  }

  Future<void> _markRegularBackfillNeededForDate(DateTime date) async {
    final meta = await _getRegularCompletionsIndexMetaBox();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final existingOldest = _parseDateKey('${meta.get(_oldestDataMetaKey)}');
    if (existingOldest == null || dateOnly.isBefore(existingOldest)) {
      await meta.put(_oldestDataMetaKey, _dateKey(dateOnly));
    }

    final indexedFrom = _regularIndexedFromDate ??
        _parseDateKey('${meta.get(_indexedFromMetaKey)}');
    if (indexedFrom != null && dateOnly.isBefore(indexedFrom)) {
      await meta.put(_backfillCompleteMetaKey, false);
      _regularBackfillComplete = false;
    }
  }

  Future<List<Map<String, dynamic>>> _scanRegularChunkEntries(
    DateTime chunkStart,
    DateTime chunkEnd,
  ) async {
    final start = DateTime(chunkStart.year, chunkStart.month, chunkStart.day);
    final end = DateTime(chunkEnd.year, chunkEnd.month, chunkEnd.day);
    final entries = <Map<String, dynamic>>[];
    var scanned = 0;
    for (final completion in (await _getCompletionsBox()).values) {
      scanned++;
      if (scanned % _sessionScanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final completedDate = DateTime(
        completion.completedDate.year,
        completion.completedDate.month,
        completion.completedDate.day,
      );
      if (_isDateBefore(completedDate, start) ||
          _isDateAfter(completedDate, end)) {
        continue;
      }
      entries.add(<String, dynamic>{
        'id': completion.id,
        'habitId': completion.habitId,
        'dateKey': _dateKey(completedDate),
        'count': completion.count,
        'isSkipped': completion.isSkipped,
        'isPostponed': completion.isPostponed,
      });
    }
    return entries;
  }

  List<HabitCompletion> _scanHabitRangeFromBox(
    Iterable<HabitCompletion> completions,
    String habitId,
    DateTime startDate,
    DateTime endDate,
  ) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return completions.where((completion) {
      if (completion.habitId != habitId) return false;
      final date = DateTime(
        completion.completedDate.year,
        completion.completedDate.month,
        completion.completedDate.day,
      );
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  Future<List<HabitCompletion>> _readRegularIndexedRange(
    Box<HabitCompletion> regularBox,
    String habitId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final dateIndexBox = await _getRegularCompletionsDateIndexBox();
    final out = <HabitCompletion>[];
    for (final key in _dateKeysInRange(startDate, endDate)) {
      final ids = _readStringList(dateIndexBox.get(key));
      for (final id in ids) {
        final completion = regularBox.get(id);
        if (completion != null && completion.habitId == habitId) {
          out.add(completion);
        }
      }
    }
    return out;
  }

  Map<String, int> _buildDailyCompletionSummaryFromCompletions(
    Iterable<HabitCompletion> completions,
  ) {
    final summary = _newDailySummary();
    for (final completion in completions) {
      _applyCompletionDelta(summary, completion, 1);
    }
    return summary;
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('[HabitRepository] $message');
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
    if (includeRegular &&
        includeQuit &&
        _completionDateCache.containsKey(dateKey)) {
      return _completionDateCache[dateKey]!;
    }

    final result = <String, List<HabitCompletion>>{};

    if (includeRegular) {
      await _ensureRegularCompletionIndexesReady();
      final regularHabitsBox = await _getHabitsBox();
      final regularHabitIds = regularHabitsBox.values
          .where((h) => !h.isQuitHabit)
          .map((h) => h.id)
          .toSet();

      final regularCompletionsBox = await _getCompletionsBox();
      if (_useRegularCompletionIndexes &&
          _isDateWithinRegularIndexedRange(date)) {
        final ids = _readStringList(
          (await _getRegularCompletionsDateIndexBox()).get(_dateKey(date)),
        );
        for (final id in ids) {
          final completion = regularCompletionsBox.get(id);
          if (completion == null) continue;
          if (!regularHabitIds.contains(completion.habitId)) continue;
          result
              .putIfAbsent(completion.habitId, () => <HabitCompletion>[])
              .add(completion);
        }
      } else {
        for (final completion in regularCompletionsBox.values) {
          if (!completion.isForDate(date)) continue;
          if (!regularHabitIds.contains(completion.habitId)) continue;
          result
              .putIfAbsent(completion.habitId, () => <HabitCompletion>[])
              .add(completion);
        }
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
    final habit = await getHabitById(habitId);
    if (habit == null) return const <HabitCompletion>[];
    if (habit.isQuitHabit) {
      final completions = await getCompletionsForHabit(habitId);
      return completions.where((c) {
        return c.completedDate.isAfter(
              startDate.subtract(const Duration(days: 1)),
            ) &&
            c.completedDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    }

    await _ensureRegularCompletionIndexesReady();
    final regularBox = await _getCompletionsBox();
    if (!_useRegularCompletionIndexes) {
      return _scanHabitRangeFromBox(
        regularBox.values,
        habitId,
        startDate,
        endDate,
      );
    }

    if (!_isRangeFullyRegularIndexed(startDate, endDate)) {
      final indexedFrom = _regularIndexedFromDate;
      if (indexedFrom == null) {
        return _scanHabitRangeFromBox(
          regularBox.values,
          habitId,
          startDate,
          endDate,
        );
      }

      final out = <HabitCompletion>[];
      final startOnly = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
      final dayBeforeIndexed = indexedFrom.subtract(const Duration(days: 1));

      if (!startOnly.isAfter(dayBeforeIndexed)) {
        final olderEnd = endOnly.isBefore(dayBeforeIndexed)
            ? endOnly
            : dayBeforeIndexed;
        out.addAll(
          _scanHabitRangeFromBox(
            regularBox.values,
            habitId,
            startOnly,
            olderEnd,
          ),
        );
      }

      if (!endOnly.isBefore(indexedFrom)) {
        final indexedStart = startOnly.isBefore(indexedFrom)
            ? indexedFrom
            : startOnly;
        out.addAll(
          await _readRegularIndexedRange(
            regularBox,
            habitId,
            indexedStart,
            endOnly,
          ),
        );
      }
      return out;
    }
    final dateIndexBox = await _getRegularCompletionsDateIndexBox();
    final out = <HabitCompletion>[];

    for (final key in _dateKeysInRange(startDate, endDate)) {
      final ids = _readStringList(dateIndexBox.get(key));
      for (final id in ids) {
        final completion = regularBox.get(id);
        if (completion != null && completion.habitId == habitId) {
          out.add(completion);
        }
      }
    }

    return out;
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
    await _ensureRegularCompletionIndexesReady();
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
    if (identical(sourceBox, regularBox)) {
      await _removeRegularCompletionFromIndexes(completion);
    }

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
    if (!habit.isQuitHabit) {
      await _ensureRegularCompletionIndexesReady();
    }

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
      if (!habit.isQuitHabit) {
        await _removeRegularCompletionFromIndexes(completion);
      }
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

    List<String> toDelete;
    if (habit.isQuitHabit) {
      toDelete = box.values
          .where((c) => c.habitId == habitId)
          .map((c) => c.id)
          .toList();
    } else {
      await _ensureRegularCompletionIndexesReady();
      if (_useRegularCompletionIndexes && _regularBackfillComplete) {
        toDelete = _readStringList(
          (await _getRegularCompletionsHabitIndexBox()).get(habitId),
        );
      } else {
        toDelete = box.values
            .where((c) => c.habitId == habitId)
            .map((c) => c.id)
            .toList();
      }
    }

    for (final id in toDelete) {
      if (!habit.isQuitHabit) {
        final completion = box.get(id);
        if (completion != null) {
          await _removeRegularCompletionFromIndexes(completion);
        }
      }
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
    await _ensureRegularCompletionIndexesReady();
    final habitsBox = await _getHabitsBox();
    final completionsBox = await _getCompletionsBox();
    await habitsBox.clear();
    await completionsBox.clear();
    final quitHabitsBox = await _getQuitHabitsBoxOrNull();
    final quitCompletionsBox = await _getQuitCompletionsBoxOrNull();
    await quitHabitsBox?.clear();
    await quitCompletionsBox?.clear();
    await (await _getRegularCompletionsDateIndexBox()).clear();
    await (await _getRegularCompletionsHabitIndexBox()).clear();
    await (await _getHabitDailySummaryBox()).clear();
    final meta = await _getRegularCompletionsIndexMetaBox();
    await meta.put('version', _regularCompletionsIndexVersion);
    await meta.delete(_rebuildNeededMetaKey);
    await meta.put(_backfillCompleteMetaKey, true);
    await meta.put(_backfillPausedMetaKey, false);
    final todayKey = _dateKey(DateTime.now());
    await meta.put(_indexedFromMetaKey, todayKey);
    await meta.put(_oldestDataMetaKey, todayKey);
    await meta.put(_lastIndexedMetaKey, todayKey);
    _regularIndexedFromDate = _parseDateKey(todayKey);
    _regularBackfillComplete = true;
    invalidateCompletionCache();
  }

  Future<void> setBackfillPaused(bool paused) async {
    await _ensureRegularCompletionIndexesReady();
    await (await _getRegularCompletionsIndexMetaBox()).put(
      _backfillPausedMetaKey,
      paused,
    );
  }

  Future<ModuleHistoryOptimizationStatus> getHistoryOptimizationStatus() async {
    await _ensureRegularCompletionIndexesReady();
    final meta = await _getRegularCompletionsIndexMetaBox();
    return ModuleHistoryOptimizationStatus(
      moduleId: 'habits',
      ready: _regularCompletionIndexesReady,
      usingScanFallback: !_useRegularCompletionIndexes,
      backfillComplete: meta.get(_backfillCompleteMetaKey) == true,
      paused: meta.get(_backfillPausedMetaKey) == true,
      indexedFromDateKey: meta.get(_indexedFromMetaKey) as String?,
      oldestDataDateKey: meta.get(_oldestDataMetaKey) as String?,
      lastIndexedDateKey: meta.get(_lastIndexedMetaKey) as String?,
      bootstrapWindowDays: _bootstrapWindowDays,
    );
  }

  Future<bool> backfillNextChunk({
    int chunkDays = _defaultBackfillChunkDays,
  }) async {
    await _ensureRegularCompletionIndexesReady();
    if (!_useRegularCompletionIndexes) return false;

    final meta = await _getRegularCompletionsIndexMetaBox();
    if (meta.get(_backfillPausedMetaKey) == true) {
      return false;
    }
    if (meta.get(_backfillCompleteMetaKey) == true) {
      return false;
    }

    final indexedFrom = _parseDateKey('${meta.get(_indexedFromMetaKey)}');
    final oldestData = _parseDateKey('${meta.get(_oldestDataMetaKey)}');
    if (indexedFrom == null || oldestData == null) {
      await meta.put(_rebuildNeededMetaKey, true);
      return false;
    }
    if (!indexedFrom.isAfter(oldestData)) {
      await meta.put(_backfillCompleteMetaKey, true);
      _regularBackfillComplete = true;
      return false;
    }

    final chunkEnd = indexedFrom.subtract(const Duration(days: 1));
    final chunkStartCandidate = chunkEnd.subtract(
      Duration(days: chunkDays - 1),
    );
    final chunkStart = chunkStartCandidate.isBefore(oldestData)
        ? oldestData
        : chunkStartCandidate;

    final entries = await _scanRegularChunkEntries(chunkStart, chunkEnd);
    final aggregated = await Isolate.run<Map<String, dynamic>>(
      () => _aggregateHabitChunkWorker(<String, dynamic>{'entries': entries}),
    );

    final dateIndexRaw = aggregated['dateIndex'] as Map<String, dynamic>? ?? {};
    final habitIndexRaw =
        aggregated['habitIndex'] as Map<String, dynamic>? ?? {};
    final dailySummaryRaw =
        aggregated['dailySummary'] as Map<String, dynamic>? ?? {};

    final dateIndex = <String, List<String>>{};
    final habitIndex = <String, List<String>>{};
    final dailySummary = <String, Map<String, int>>{};

    for (final entry in dateIndexRaw.entries) {
      dateIndex[entry.key] = (entry.value as List).map((e) => '$e').toList();
    }
    for (final entry in habitIndexRaw.entries) {
      habitIndex[entry.key] = (entry.value as List).map((e) => '$e').toList();
    }
    for (final entry in dailySummaryRaw.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      dailySummary[entry.key] = <String, int>{
        'entries': _asInt(raw['entries']),
        'successfulEntries': _asInt(raw['successfulEntries']),
        'skippedEntries': _asInt(raw['skippedEntries']),
        'postponedEntries': _asInt(raw['postponedEntries']),
        'totalCount': _asInt(raw['totalCount']),
      };
    }

    final dateIndexBox = await _getRegularCompletionsDateIndexBox();
    final habitIndexBox = await _getRegularCompletionsHabitIndexBox();
    final summaryBox = await _getHabitDailySummaryBox();
    if (dateIndex.isNotEmpty) {
      await dateIndexBox.putAll(dateIndex);
    }
    if (habitIndex.isNotEmpty) {
      for (final entry in habitIndex.entries) {
        final existing = _readStringList(habitIndexBox.get(entry.key));
        for (final id in entry.value) {
          if (!existing.contains(id)) {
            existing.add(id);
          }
        }
        await habitIndexBox.put(entry.key, existing);
      }
    }
    if (dailySummary.isNotEmpty) {
      await summaryBox.putAll(dailySummary);
    }

    final newIndexedFrom = chunkStart;
    final isComplete = !newIndexedFrom.isAfter(oldestData);
    await meta.put(_indexedFromMetaKey, _dateKey(newIndexedFrom));
    await meta.put(_lastIndexedMetaKey, _dateKey(newIndexedFrom));
    await meta.put(_backfillCompleteMetaKey, isComplete);
    _regularIndexedFromDate = newIndexedFrom;
    _regularBackfillComplete = isComplete;
    return true;
  }
}

Map<String, dynamic> _aggregateHabitChunkWorker(Map<String, dynamic> payload) {
  final entries = (payload['entries'] as List?) ?? const <dynamic>[];
  final dateIndex = <String, List<String>>{};
  final habitIndex = <String, List<String>>{};
  final dailySummary = <String, Map<String, int>>{};

  for (final raw in entries) {
    if (raw is! Map) continue;
    final id = '${raw['id'] ?? ''}';
    final habitId = '${raw['habitId'] ?? ''}';
    final dateKey = '${raw['dateKey'] ?? ''}';
    final count = raw['count'] is int
        ? raw['count'] as int
        : int.tryParse('${raw['count']}') ?? 0;
    final isSkipped = raw['isSkipped'] == true;
    final isPostponed = raw['isPostponed'] == true;
    if (id.isEmpty || habitId.isEmpty || dateKey.length != 8) continue;

    dateIndex.putIfAbsent(dateKey, () => <String>[]).add(id);
    habitIndex.putIfAbsent(habitId, () => <String>[]).add(id);

    final summary = dailySummary.putIfAbsent(dateKey, () {
      return <String, int>{
        'entries': 0,
        'successfulEntries': 0,
        'skippedEntries': 0,
        'postponedEntries': 0,
        'totalCount': 0,
      };
    });
    summary['entries'] = (summary['entries'] ?? 0) + 1;
    if (isPostponed) {
      summary['postponedEntries'] = (summary['postponedEntries'] ?? 0) + 1;
    } else if (isSkipped) {
      summary['skippedEntries'] = (summary['skippedEntries'] ?? 0) + 1;
    } else if (count > 0) {
      summary['successfulEntries'] = (summary['successfulEntries'] ?? 0) + 1;
    }
    summary['totalCount'] = (summary['totalCount'] ?? 0) + count;
  }

  return <String, dynamic>{
    'dateIndex': dateIndex,
    'habitIndex': habitIndex,
    'dailySummary': dailySummary,
  };
}
