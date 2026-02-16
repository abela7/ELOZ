import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/data/history_optimization_models.dart';
import '../models/task.dart';
import '../local/hive/hive_service.dart';

/// Repository for task CRUD operations using Hive
/// Optimized: Caches box reference to avoid repeated lookups
class TaskRepository {
  static const String boxName = 'tasksBox';
  static const String _dueDateIndexBoxName = 'task_due_date_index_v1';
  static const String _dailySummaryBoxName = 'task_daily_summary_v1';
  static const String _indexMetaBoxName = 'task_index_meta_v1';
  static const String _rebuildNeededMetaKey = 'rebuild_needed';
  static const String _indexedFromMetaKey = 'indexed_from_date_key';
  static const String _oldestDataMetaKey = 'oldest_data_date_key';
  static const String _lastIndexedMetaKey = 'last_indexed_date_key';
  static const String _backfillCompleteMetaKey = 'backfill_complete';
  static const String _backfillPausedMetaKey = 'backfill_paused';
  static const int _bootstrapWindowDays = 30;
  static const int _defaultBackfillChunkDays = 30;
  static const int _sessionScanYieldInterval = 400;
  static const int _indexVersion = 1;

  /// Cached box reference for performance
  Box<Task>? _cachedBox;
  Box<dynamic>? _dueDateIndexBox;
  Box<dynamic>? _dailySummaryBox;
  Box<dynamic>? _indexMetaBox;
  bool _indexesReady = false;
  bool _integrityChecked = false;
  bool _useIndexedReads = true;
  bool _backfillComplete = false;
  DateTime? _indexedFromDate;
  final Future<Box<Task>> Function()? _taskBoxOpener;
  final Future<Box<dynamic>> Function(String boxName)? _dynamicBoxOpener;

  TaskRepository({
    Future<Box<Task>> Function()? taskBoxOpener,
    Future<Box<dynamic>> Function(String boxName)? dynamicBoxOpener,
  }) : _taskBoxOpener = taskBoxOpener,
       _dynamicBoxOpener = dynamicBoxOpener;

  /// Get the tasks box (lazy initialization with caching)
  Future<Box<Task>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    final opener = _taskBoxOpener;
    if (opener != null) {
      _cachedBox = await opener();
    } else {
      _cachedBox = await HiveService.getBox<Task>(boxName);
    }
    return _cachedBox!;
  }

  /// Create a new task
  Future<void> createTask(Task task) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    await box.put(task.id, task);
    await _addTaskToIndexes(task);
  }

  /// Get all tasks
  Future<List<Task>> getAllTasks() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get task by ID
  Future<Task?> getTaskById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing task
  Future<void> updateTask(Task task) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    final previous = box.get(task.id);
    await box.put(task.id, task);
    if (previous != null) {
      await _removeTaskFromIndexes(previous);
    }
    await _addTaskToIndexes(task);
  }

  /// Delete a task
  Future<void> deleteTask(String id) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    final existing = box.get(id);
    await box.delete(id);
    if (existing != null) {
      await _removeTaskFromIndexes(existing);
    }
  }

  /// Get tasks by status
  Future<List<Task>> getTasksByStatus(String status) async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) => task.status == status).toList();
  }

  /// Get tasks for a specific date
  Future<List<Task>> getTasksForDate(DateTime date) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    if (!_useIndexedReads || !_isDateWithinIndexedRange(date)) {
      return box.values
          .where((task) => _isSameDate(task.dueDate, date))
          .toList();
    }
    final ids = _readStringList(
      (await _getDueDateIndexBox()).get(_dateKey(date)),
    );
    if (ids.isEmpty) {
      return const <Task>[];
    }

    final tasks = <Task>[];
    for (final id in ids) {
      final task = box.get(id);
      if (task != null) {
        tasks.add(task);
      }
    }
    return tasks;
  }

  /// Get overdue tasks
  Future<List<Task>> getOverdueTasks() async {
    await _ensureIndexesReady();
    final box = await _getBox();
    if (!_useIndexedReads || !_backfillComplete) {
      return box.values.where((task) => task.isOverdue).toList();
    }
    final indexBox = await _getDueDateIndexBox();

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final overdue = <Task>[];

    for (final dynamic rawKey in indexBox.keys) {
      final key = '$rawKey';
      final date = _parseDateKey(key);
      if (date == null) continue;
      if (date.isAfter(todayOnly)) continue;

      final ids = _readStringList(indexBox.get(key));
      for (final id in ids) {
        final task = box.get(id);
        if (task != null && task.isOverdue) {
          overdue.add(task);
        }
      }
    }

    return overdue;
  }

  /// Get tasks by category
  Future<List<Task>> getTasksByCategory(String categoryId) async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) => task.categoryId == categoryId).toList();
  }

  /// Get tasks by priority
  Future<List<Task>> getTasksByPriority(String priority) async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) => task.priority == priority).toList();
  }

  /// Search tasks by title or description
  Future<List<Task>> searchTasks(String query) async {
    final allTasks = await getAllTasks();
    final lowerQuery = query.toLowerCase();
    return allTasks.where((task) {
      return task.title.toLowerCase().contains(lowerQuery) ||
          (task.description != null &&
              task.description!.toLowerCase().contains(lowerQuery)) ||
          (task.notes != null &&
              task.notes!.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Get task statistics
  Future<Map<String, int>> getTaskStatistics() async {
    await _ensureIndexesReady();
    final box = await _getBox();
    if (!_useIndexedReads || !_backfillComplete) {
      return _buildStatisticsFromTasks(box.values);
    }
    final summaryBox = await _getDailySummaryBox();
    final indexBox = await _getDueDateIndexBox();

    var total = 0;
    var pending = 0;
    var completed = 0;
    var postponed = 0;
    var overdue = 0;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final todayKey = _dateKey(todayOnly);

    for (final entry in summaryBox.toMap().entries) {
      final date = _parseDateKey('${entry.key}');
      final summary = _readSummaryMap(entry.value);
      total += summary['total'] ?? 0;
      pending += summary['pending'] ?? 0;
      completed += summary['completed'] ?? 0;
      postponed += summary['postponed'] ?? 0;

      if (date != null && date.isBefore(todayOnly)) {
        overdue += summary['pending'] ?? 0;
      }
    }

    // Today's overdue depends on current time, so evaluate only today's tasks.
    final todayIds = _readStringList(indexBox.get(todayKey));
    for (final id in todayIds) {
      final task = box.get(id);
      if (task != null && task.isOverdue) {
        overdue++;
      }
    }

    return {
      'total': total,
      'pending': pending,
      'completed': completed,
      'overdue': overdue,
      'postponed': postponed,
    };
  }

  /// Get cached per-day task summary by due date.
  Future<Map<String, int>> getDailySummary(DateTime date) async {
    await _ensureIndexesReady();
    if (!_useIndexedReads || !_isDateWithinIndexedRange(date)) {
      return _buildDailySummaryFromTasks(
        (await _getBox()).values.where(
          (task) => _isSameDate(task.dueDate, date),
        ),
      );
    }
    final summaryBox = await _getDailySummaryBox();
    return _readSummaryMap(summaryBox.get(_dateKey(date)));
  }

  /// Delete all tasks (for reset functionality)
  Future<void> deleteAllTasks() async {
    await _ensureIndexesReady();
    final box = await _getBox();
    await box.clear();
    await (await _getDueDateIndexBox()).clear();
    await (await _getDailySummaryBox()).clear();
    final metaBox = await _getIndexMetaBox();
    await metaBox.put('version', _indexVersion);
    await metaBox.delete(_rebuildNeededMetaKey);
    await metaBox.put(_backfillCompleteMetaKey, true);
    await metaBox.put(_backfillPausedMetaKey, false);
    final todayKey = _dateKey(DateTime.now());
    await metaBox.put(_indexedFromMetaKey, todayKey);
    await metaBox.put(_oldestDataMetaKey, todayKey);
    await metaBox.put(_lastIndexedMetaKey, todayKey);
    _indexedFromDate = _parseDateKey(todayKey);
    _backfillComplete = true;
  }

  Future<void> setBackfillPaused(bool paused) async {
    await _ensureIndexesReady();
    await (await _getIndexMetaBox()).put(_backfillPausedMetaKey, paused);
  }

  Future<ModuleHistoryOptimizationStatus> getHistoryOptimizationStatus() async {
    await _ensureIndexesReady();
    final meta = await _getIndexMetaBox();
    return ModuleHistoryOptimizationStatus(
      moduleId: 'tasks',
      ready: _indexesReady,
      usingScanFallback: !_useIndexedReads,
      backfillComplete: meta.get(_backfillCompleteMetaKey) == true,
      paused: meta.get(_backfillPausedMetaKey) == true,
      indexedFromDateKey: meta.get(_indexedFromMetaKey) as String?,
      oldestDataDateKey: meta.get(_oldestDataMetaKey) as String?,
      lastIndexedDateKey: meta.get(_lastIndexedMetaKey) as String?,
      bootstrapWindowDays: _bootstrapWindowDays,
    );
  }

  /// Backfills one historical chunk (older than current indexed window).
  /// Returns true if a chunk was processed.
  Future<bool> backfillNextChunk({
    int chunkDays = _defaultBackfillChunkDays,
  }) async {
    await _ensureIndexesReady();
    if (!_useIndexedReads) return false;

    final meta = await _getIndexMetaBox();
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
      _backfillComplete = true;
      return false;
    }

    final chunkEnd = indexedFrom.subtract(const Duration(days: 1));
    final chunkStartCandidate = chunkEnd.subtract(
      Duration(days: chunkDays - 1),
    );
    final chunkStart = chunkStartCandidate.isBefore(oldestData)
        ? oldestData
        : chunkStartCandidate;

    final entries = await _scanChunkEntries(chunkStart, chunkEnd);
    final aggregated = await Isolate.run<Map<String, dynamic>>(
      () => _aggregateTaskChunkWorker(<String, dynamic>{'entries': entries}),
    );

    final indexMapRaw = aggregated['indexMap'] as Map<String, dynamic>? ?? {};
    final summaryMapRaw =
        aggregated['summaryMap'] as Map<String, dynamic>? ?? {};
    final indexMap = <String, List<String>>{};
    final summaryMap = <String, Map<String, int>>{};

    for (final entry in indexMapRaw.entries) {
      indexMap[entry.key] = (entry.value as List).map((e) => '$e').toList();
    }
    for (final entry in summaryMapRaw.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      summaryMap[entry.key] = <String, int>{
        'total': _asInt(raw['total']),
        'pending': _asInt(raw['pending']),
        'completed': _asInt(raw['completed']),
        'postponed': _asInt(raw['postponed']),
      };
    }

    final indexBox = await _getDueDateIndexBox();
    final summaryBox = await _getDailySummaryBox();
    if (indexMap.isNotEmpty) {
      await indexBox.putAll(indexMap);
    }
    if (summaryMap.isNotEmpty) {
      await summaryBox.putAll(summaryMap);
    }

    final newIndexedFrom = chunkStart;
    final isComplete = !newIndexedFrom.isAfter(oldestData);
    await meta.put(_indexedFromMetaKey, _dateKey(newIndexedFrom));
    await meta.put(_lastIndexedMetaKey, _dateKey(newIndexedFrom));
    await meta.put(_backfillCompleteMetaKey, isComplete);
    _indexedFromDate = newIndexedFrom;
    _backfillComplete = isComplete;
    return true;
  }

  Future<Box<dynamic>> _getDueDateIndexBox() async {
    if (_dueDateIndexBox != null && _dueDateIndexBox!.isOpen) {
      return _dueDateIndexBox!;
    }
    _dueDateIndexBox = await _openDynamicBox(_dueDateIndexBoxName);
    return _dueDateIndexBox!;
  }

  Future<Box<dynamic>> _getDailySummaryBox() async {
    if (_dailySummaryBox != null && _dailySummaryBox!.isOpen) {
      return _dailySummaryBox!;
    }
    _dailySummaryBox = await _openDynamicBox(_dailySummaryBoxName);
    return _dailySummaryBox!;
  }

  Future<Box<dynamic>> _getIndexMetaBox() async {
    if (_indexMetaBox != null && _indexMetaBox!.isOpen) {
      return _indexMetaBox!;
    }
    _indexMetaBox = await _openDynamicBox(_indexMetaBoxName);
    return _indexMetaBox!;
  }

  Future<Box<dynamic>> _openDynamicBox(String boxName) async {
    final opener = _dynamicBoxOpener;
    if (opener != null) {
      return opener(boxName);
    }
    return HiveService.getBox<dynamic>(boxName);
  }

  Future<void> _ensureIndexesReady() async {
    if (_indexesReady) return;
    final metaBox = await _getIndexMetaBox();
    final version = _asInt(metaBox.get('version'));
    final rebuildNeeded = metaBox.get(_rebuildNeededMetaKey) == true;
    final hasBootstrapWindow =
        metaBox.get(_indexedFromMetaKey) is String &&
        metaBox.get(_oldestDataMetaKey) is String;
    var attemptedRebuild = false;

    if (version != _indexVersion || rebuildNeeded || !hasBootstrapWindow) {
      final reason = version != _indexVersion
          ? 'version_mismatch'
          : rebuildNeeded
          ? 'rebuild_needed_flag'
          : 'missing_bootstrap_window';
      await _bootstrapRecentWindowIndexes(reason: reason);
      await metaBox.put('version', _indexVersion);
      attemptedRebuild = true;
    }

    if (!_integrityChecked) {
      var valid = await _hasValidIndexes();
      if (!valid && !attemptedRebuild) {
        await _bootstrapRecentWindowIndexes(reason: 'integrity_mismatch');
        await metaBox.put('version', _indexVersion);
        valid = await _hasValidIndexes();
      }

      if (!valid) {
        _useIndexedReads = false;
        await metaBox.put(_rebuildNeededMetaKey, true);
        _debugLog(
          'Index mismatch persisted after rebuild; falling back to scan mode for this session.',
        );
      } else {
        _useIndexedReads = true;
        await metaBox.delete(_rebuildNeededMetaKey);
      }

      _indexedFromDate = _parseDateKey('${metaBox.get(_indexedFromMetaKey)}');
      _backfillComplete = metaBox.get(_backfillCompleteMetaKey) == true;
      _integrityChecked = true;
    }

    _indexesReady = true;
  }

  Future<bool> _hasValidIndexes() async {
    final box = await _getBox();
    if (box.isEmpty) return true;
    final indexedFrom =
        _indexedFromDate ??
        _parseDateKey('${(await _getIndexMetaBox()).get(_indexedFromMetaKey)}');
    if (indexedFrom == null) {
      return false;
    }

    var expectedCount = 0;
    for (final task in box.values) {
      if (!_isDateBefore(task.dueDate, indexedFrom)) {
        expectedCount++;
      }
    }

    var indexedCount = 0;
    for (final dynamic value in (await _getDueDateIndexBox()).values) {
      indexedCount += _readStringList(value).length;
    }
    if (indexedCount != expectedCount) {
      return false;
    }

    var summarizedTotal = 0;
    for (final dynamic value in (await _getDailySummaryBox()).values) {
      summarizedTotal += _readSummaryMap(value)['total'] ?? 0;
    }
    return summarizedTotal == expectedCount;
  }

  Future<void> _bootstrapRecentWindowIndexes({required String reason}) async {
    final box = await _getBox();
    final recordCount = box.length;
    final stopwatch = Stopwatch()..start();
    final indexBox = await _getDueDateIndexBox();
    final summaryBox = await _getDailySummaryBox();
    final metaBox = await _getIndexMetaBox();
    await indexBox.clear();
    await summaryBox.clear();

    final indexMap = <String, List<String>>{};
    final summaryMap = <String, Map<String, int>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bootstrapFrom = today.subtract(
      const Duration(days: _bootstrapWindowDays - 1),
    );
    DateTime? oldestData;
    var scanned = 0;
    for (final task in box.values) {
      scanned++;
      if (scanned % _sessionScanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      final dueDateOnly = DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
      );
      if (oldestData == null || dueDateOnly.isBefore(oldestData)) {
        oldestData = dueDateOnly;
      }
      if (_isDateBefore(dueDateOnly, bootstrapFrom)) {
        continue;
      }

      final key = _dateKey(task.dueDate);
      indexMap.putIfAbsent(key, () => <String>[]).add(task.id);
      _applyTaskDelta(summaryMap.putIfAbsent(key, _newSummaryMap), task, 1);
    }

    if (indexMap.isNotEmpty) {
      await indexBox.putAll(indexMap);
    }
    if (summaryMap.isNotEmpty) {
      await summaryBox.putAll(summaryMap);
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

    _indexedFromDate = indexedFrom;
    _backfillComplete = backfillComplete;
    _useIndexedReads = true;

    stopwatch.stop();
    _debugLog(
      'Index rebuild finished. reason=$reason records=$recordCount durationMs=${stopwatch.elapsedMilliseconds}',
    );
  }

  Future<void> _addTaskToIndexes(Task task) async {
    if (!_useIndexedReads || !_isDateWithinIndexedRange(task.dueDate)) {
      await _markBackfillNeededForDate(task.dueDate);
      return;
    }
    final key = _dateKey(task.dueDate);
    final indexBox = await _getDueDateIndexBox();
    final ids = _readStringList(indexBox.get(key));
    if (!ids.contains(task.id)) {
      ids.add(task.id);
      await indexBox.put(key, ids);
    }

    final summaryBox = await _getDailySummaryBox();
    final summary = _readSummaryMap(summaryBox.get(key));
    _applyTaskDelta(summary, task, 1);
    await _writeOrDeleteSummary(summaryBox, key, summary);
  }

  Future<void> _removeTaskFromIndexes(Task task) async {
    if (!_useIndexedReads || !_isDateWithinIndexedRange(task.dueDate)) return;
    final key = _dateKey(task.dueDate);
    final indexBox = await _getDueDateIndexBox();
    final ids = _readStringList(indexBox.get(key));
    ids.remove(task.id);
    if (ids.isEmpty) {
      await indexBox.delete(key);
    } else {
      await indexBox.put(key, ids);
    }

    final summaryBox = await _getDailySummaryBox();
    final summary = _readSummaryMap(summaryBox.get(key));
    _applyTaskDelta(summary, task, -1);
    await _writeOrDeleteSummary(summaryBox, key, summary);
  }

  Future<void> _writeOrDeleteSummary(
    Box<dynamic> summaryBox,
    String key,
    Map<String, int> summary,
  ) async {
    final total = summary['total'] ?? 0;
    if (total <= 0) {
      await summaryBox.delete(key);
      return;
    }
    await summaryBox.put(key, summary);
  }

  Map<String, int> _newSummaryMap() {
    return <String, int>{
      'total': 0,
      'pending': 0,
      'completed': 0,
      'postponed': 0,
    };
  }

  Map<String, int> _readSummaryMap(Object? value) {
    final base = _newSummaryMap();
    if (value is Map) {
      for (final entry in value.entries) {
        final key = '${entry.key}';
        if (!base.containsKey(key)) continue;
        base[key] = _asInt(entry.value);
      }
    }
    return base;
  }

  void _applyTaskDelta(Map<String, int> summary, Task task, int delta) {
    summary['total'] = (summary['total'] ?? 0) + delta;
    switch (task.status) {
      case 'pending':
        summary['pending'] = (summary['pending'] ?? 0) + delta;
        break;
      case 'completed':
        summary['completed'] = (summary['completed'] ?? 0) + delta;
        break;
      case 'postponed':
        summary['postponed'] = (summary['postponed'] ?? 0) + delta;
        break;
      default:
        break;
    }

    // Clamp values for safety.
    for (final key in summary.keys.toList()) {
      final current = summary[key] ?? 0;
      summary[key] = current < 0 ? 0 : current;
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

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, int> _buildDailySummaryFromTasks(Iterable<Task> tasks) {
    final summary = _newSummaryMap();
    for (final task in tasks) {
      _applyTaskDelta(summary, task, 1);
    }
    return summary;
  }

  Map<String, int> _buildStatisticsFromTasks(Iterable<Task> tasks) {
    var total = 0;
    var pending = 0;
    var completed = 0;
    var postponed = 0;
    var overdue = 0;

    for (final task in tasks) {
      total++;
      switch (task.status) {
        case 'pending':
          pending++;
          break;
        case 'completed':
          completed++;
          break;
        case 'postponed':
          postponed++;
          break;
        default:
          break;
      }
      if (task.isOverdue) {
        overdue++;
      }
    }

    return <String, int>{
      'total': total,
      'pending': pending,
      'completed': completed,
      'overdue': overdue,
      'postponed': postponed,
    };
  }

  Future<List<Map<String, String>>> _scanChunkEntries(
    DateTime chunkStart,
    DateTime chunkEnd,
  ) async {
    final start = DateTime(chunkStart.year, chunkStart.month, chunkStart.day);
    final end = DateTime(chunkEnd.year, chunkEnd.month, chunkEnd.day);
    final entries = <Map<String, String>>[];
    var scanned = 0;
    for (final task in (await _getBox()).values) {
      scanned++;
      if (scanned % _sessionScanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final dueDateOnly = DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
      );
      if (_isDateBefore(dueDateOnly, start) || _isDateAfter(dueDateOnly, end)) {
        continue;
      }
      entries.add(<String, String>{
        'id': task.id,
        'dateKey': _dateKey(dueDateOnly),
        'status': task.status,
      });
    }
    return entries;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isDateWithinIndexedRange(DateTime date) {
    final indexedFrom = _indexedFromDate;
    if (!_useIndexedReads || indexedFrom == null) return false;
    return !_isDateBefore(date, indexedFrom);
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

  Future<void> _markBackfillNeededForDate(DateTime date) async {
    final metaBox = await _getIndexMetaBox();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final existingOldest = _parseDateKey('${metaBox.get(_oldestDataMetaKey)}');
    if (existingOldest == null || dateOnly.isBefore(existingOldest)) {
      await metaBox.put(_oldestDataMetaKey, _dateKey(dateOnly));
    }

    final indexedFrom = _indexedFromDate ??
        _parseDateKey('${metaBox.get(_indexedFromMetaKey)}');
    if (indexedFrom != null && dateOnly.isBefore(indexedFrom)) {
      await metaBox.put(_backfillCompleteMetaKey, false);
      _backfillComplete = false;
    }
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('[TaskRepository] $message');
  }
}

Map<String, dynamic> _aggregateTaskChunkWorker(Map<String, dynamic> payload) {
  final entries = (payload['entries'] as List?) ?? const <dynamic>[];
  final indexMap = <String, List<String>>{};
  final summaryMap = <String, Map<String, int>>{};

  for (final raw in entries) {
    if (raw is! Map) continue;
    final id = '${raw['id'] ?? ''}';
    final dateKey = '${raw['dateKey'] ?? ''}';
    final status = '${raw['status'] ?? ''}';
    if (id.isEmpty || dateKey.length != 8) continue;

    indexMap.putIfAbsent(dateKey, () => <String>[]).add(id);
    final summary = summaryMap.putIfAbsent(dateKey, () {
      return <String, int>{
        'total': 0,
        'pending': 0,
        'completed': 0,
        'postponed': 0,
      };
    });
    summary['total'] = (summary['total'] ?? 0) + 1;
    switch (status) {
      case 'pending':
        summary['pending'] = (summary['pending'] ?? 0) + 1;
        break;
      case 'completed':
        summary['completed'] = (summary['completed'] ?? 0) + 1;
        break;
      case 'postponed':
        summary['postponed'] = (summary['postponed'] ?? 0) + 1;
        break;
      default:
        break;
    }
  }

  return <String, dynamic>{'indexMap': indexMap, 'summaryMap': summaryMap};
}
