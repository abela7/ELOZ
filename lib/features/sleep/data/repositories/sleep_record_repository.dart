import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../../../core/data/history_optimization_models.dart';
import '../models/sleep_record.dart';
import '../../sleep_module.dart';
import '../../../../data/local/hive/hive_service.dart';

/// Repository for Sleep Record CRUD operations
class SleepRecordRepository {
  static const String _dateIndexBoxName = 'sleep_records_date_index_v1';
  static const String _dailySummaryBoxName = 'sleep_daily_summary_v1';
  static const String _indexMetaBoxName = 'sleep_index_meta_v1';
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

  Box<dynamic>? _dateIndexBox;
  Box<dynamic>? _dailySummaryBox;
  Box<dynamic>? _indexMetaBox;
  bool _indexesReady = false;
  bool _integrityChecked = false;
  bool _useIndexedReads = true;
  bool _backfillComplete = false;
  DateTime? _indexedFromDate;
  final Future<Box<SleepRecord>> Function()? _sleepBoxOpener;
  final Future<Box<dynamic>> Function(String boxName)? _dynamicBoxOpener;

  SleepRecordRepository({
    Future<Box<SleepRecord>> Function()? sleepBoxOpener,
    Future<Box<dynamic>> Function(String boxName)? dynamicBoxOpener,
  }) : _sleepBoxOpener = sleepBoxOpener,
       _dynamicBoxOpener = dynamicBoxOpener;

  /// Get the Hive box for sleep records
  Future<Box<SleepRecord>> _getBox() async {
    final opener = _sleepBoxOpener;
    if (opener != null) {
      return opener();
    }
    return await HiveService.getBox<SleepRecord>(
      SleepModule.sleepRecordsBoxName,
    );
  }

  /// Create a new sleep record
  Future<void> create(SleepRecord record) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    await box.put(record.id, record);
    await box.flush(); // Ensure data is written to disk
    await _addRecordToIndexes(record);
  }

  /// Get all sleep records
  Future<List<SleepRecord>> getAll() async {
    final box = await _getBox();
    return box.values.toList()
      ..sort((a, b) => b.bedTime.compareTo(a.bedTime)); // Most recent first
  }

  /// Get sleep record by ID
  Future<SleepRecord?> getById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing sleep record
  Future<void> update(SleepRecord record) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    final previous = box.get(record.id);
    record.updatedAt = DateTime.now();
    await box.put(record.id, record);
    await box.flush(); // Ensure data is written to disk
    if (previous != null) {
      await _removeRecordFromIndexes(previous);
    }
    await _addRecordToIndexes(record);
  }

  /// Delete a sleep record
  Future<void> delete(String id) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    final existing = box.get(id);
    await box.delete(id);
    if (existing != null) {
      await _removeRecordFromIndexes(existing);
    }
  }

  /// Get sleep records for a specific date
  Future<List<SleepRecord>> getByDate(DateTime date) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    if (!_useIndexedReads || !_isDateWithinIndexedRange(date)) {
      return box.values
          .where((record) => _isSameDate(record.bedTime, date))
          .toList()
        ..sort((a, b) => b.bedTime.compareTo(a.bedTime));
    }
    final ids = _readStringList((await _getDateIndexBox()).get(_dateKey(date)));
    if (ids.isEmpty) {
      return const <SleepRecord>[];
    }

    final records = <SleepRecord>[];
    for (final id in ids) {
      final record = box.get(id);
      if (record != null) {
        records.add(record);
      }
    }
    records.sort((a, b) => b.bedTime.compareTo(a.bedTime));
    return records;
  }

  /// Get sleep records within a date range
  Future<List<SleepRecord>> getByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    if (!_useIndexedReads) {
      final scanned = _scanRangeFromBox(box.values, startDate, endDate);
      scanned.sort((a, b) => b.bedTime.compareTo(a.bedTime));
      return scanned;
    }

    if (!_isRangeFullyIndexed(startDate, endDate)) {
      final indexedFrom = _regularizedIndexedFrom();
      if (indexedFrom == null) {
        final scanned = _scanRangeFromBox(box.values, startDate, endDate);
        scanned.sort((a, b) => b.bedTime.compareTo(a.bedTime));
        return scanned;
      }

      final out = <SleepRecord>[];
      final startOnly = _dateOnly(startDate);
      final endOnly = _dateOnly(endDate);
      final dayBeforeIndexed = indexedFrom.subtract(const Duration(days: 1));

      if (!startOnly.isAfter(dayBeforeIndexed)) {
        final olderEnd = endOnly.isBefore(dayBeforeIndexed)
            ? endOnly
            : dayBeforeIndexed;
        out.addAll(_scanRangeFromBox(box.values, startOnly, olderEnd));
      }

      if (!endOnly.isBefore(indexedFrom)) {
        final indexedStart = startOnly.isBefore(indexedFrom)
            ? indexedFrom
            : startOnly;
        out.addAll(await _readIndexedRange(box, indexedStart, endOnly));
      }

      out.sort((a, b) => b.bedTime.compareTo(a.bedTime));
      return out;
    }

    final indexBox = await _getDateIndexBox();

    final records = <SleepRecord>[];
    for (final key in _dateKeysInRange(startDate, endDate)) {
      final ids = _readStringList(indexBox.get(key));
      for (final id in ids) {
        final record = box.get(id);
        if (record != null) {
          records.add(record);
        }
      }
    }

    records.sort((a, b) => b.bedTime.compareTo(a.bedTime));
    return records;
  }

  /// Get only non-nap sleep records
  Future<List<SleepRecord>> getMainSleepRecords() async {
    final box = await _getBox();
    return box.values.where((record) => !record.isNap).toList()
      ..sort((a, b) => b.bedTime.compareTo(a.bedTime));
  }

  /// Get only nap records
  Future<List<SleepRecord>> getNapRecords() async {
    final box = await _getBox();
    return box.values.where((record) => record.isNap).toList()
      ..sort((a, b) => b.bedTime.compareTo(a.bedTime));
  }

  /// Get records by quality
  Future<List<SleepRecord>> getByQuality(String quality) async {
    final box = await _getBox();
    return box.values.where((record) => record.quality == quality).toList()
      ..sort((a, b) => b.bedTime.compareTo(a.bedTime));
  }

  /// Get records with tags
  Future<List<SleepRecord>> getByTag(String tag) async {
    final box = await _getBox();
    return box.values.where((record) {
      return record.tags != null && record.tags!.contains(tag);
    }).toList()..sort((a, b) => b.bedTime.compareTo(a.bedTime));
  }

  /// Get all unique tags
  Future<List<String>> getAllTags() async {
    final box = await _getBox();
    final tags = <String>{};

    for (final record in box.values) {
      if (record.tags != null) {
        tags.addAll(record.tags!);
      }
    }

    return tags.toList()..sort();
  }

  /// Get main sleep records (no naps) for a date range.
  Future<List<SleepRecord>> getMainSleepByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final all = await getByDateRange(startDate, endDate);
    return all.where((r) => !r.isNap).toList();
  }

  /// Get records for last N days
  Future<List<SleepRecord>> getLastNDays(int days) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    return getByDateRange(startDate, endDate);
  }

  /// Get this week's records
  Future<List<SleepRecord>> getThisWeek() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startDate = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    final endDate = startDate.add(const Duration(days: 6));
    return getByDateRange(startDate, endDate);
  }

  /// Get this month's records
  Future<List<SleepRecord>> getThisMonth() async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    final endDate = DateTime(now.year, now.month + 1, 0);
    return getByDateRange(startDate, endDate);
  }

  /// Get all record IDs without loading full objects.
  /// Use for batch operations (e.g. reset) to avoid deserializing years of data.
  Future<List<String>> getAllIds() async {
    final box = await _getBox();
    return box.keys.cast<String>().toList();
  }

  /// Get total count
  Future<int> getCount() async {
    final box = await _getBox();
    return box.length;
  }

  /// Check if sleep record exists for a date
  Future<bool> existsForDate(DateTime date) async {
    await _ensureIndexesReady();
    if (!_useIndexedReads || !_isDateWithinIndexedRange(date)) {
      return (await _getBox()).values.any(
        (record) => _isSameDate(record.bedTime, date),
      );
    }
    final ids = _readStringList((await _getDateIndexBox()).get(_dateKey(date)));
    return ids.isNotEmpty;
  }

  /// Get cached per-day sleep summary by bedtime date.
  Future<Map<String, int>> getDailySummary(DateTime date) async {
    await _ensureIndexesReady();
    if (!_useIndexedReads || !_isDateWithinIndexedRange(date)) {
      return _buildDailySummary(
        (await _getBox()).values.where(
          (record) => _isSameDate(record.bedTime, date),
        ),
      );
    }
    return _readSummary((await _getDailySummaryBox()).get(_dateKey(date)));
  }

  /// Get latest sleep record
  Future<SleepRecord?> getLatest() async {
    final box = await _getBox();
    if (box.isEmpty) return null;

    final records = box.values.toList()
      ..sort((a, b) => b.bedTime.compareTo(a.bedTime));

    return records.first;
  }

  /// Clear all sleep records
  Future<void> clearAll() async {
    await _ensureIndexesReady();
    final box = await _getBox();
    await box.clear();
    await (await _getDateIndexBox()).clear();
    await (await _getDailySummaryBox()).clear();
    final meta = await _getIndexMetaBox();
    await meta.put('version', _indexVersion);
    await meta.delete(_rebuildNeededMetaKey);
    await meta.put(_backfillCompleteMetaKey, true);
    await meta.put(_backfillPausedMetaKey, false);
    final todayKey = _dateKey(DateTime.now());
    await meta.put(_indexedFromMetaKey, todayKey);
    await meta.put(_oldestDataMetaKey, todayKey);
    await meta.put(_lastIndexedMetaKey, todayKey);
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
      moduleId: 'sleep',
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
      () => _aggregateSleepChunkWorker(<String, dynamic>{'entries': entries}),
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
        'mainSleep': _asInt(raw['mainSleep']),
        'nap': _asInt(raw['nap']),
        'totalMinutes': _asInt(raw['totalMinutes']),
      };
    }

    final indexBox = await _getDateIndexBox();
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

  /// Watch sleep records stream
  Stream<List<SleepRecord>> watchAll() async* {
    final box = await _getBox();
    yield box.values.toList()..sort((a, b) => b.bedTime.compareTo(a.bedTime));

    await for (final _ in box.watch()) {
      yield box.values.toList()..sort((a, b) => b.bedTime.compareTo(a.bedTime));
    }
  }

  /// Watch specific sleep record by ID
  Stream<SleepRecord?> watchById(String id) async* {
    final box = await _getBox();
    yield box.get(id);

    await for (final _ in box.watch(key: id)) {
      yield box.get(id);
    }
  }

  /// Batch create multiple sleep records
  Future<void> createBatch(List<SleepRecord> records) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    final previousById = <String, SleepRecord>{};
    for (final record in records) {
      final previous = box.get(record.id);
      if (previous != null) {
        previousById[record.id] = previous;
      }
    }
    final map = {for (var record in records) record.id: record};
    await box.putAll(map);
    for (final previous in previousById.values) {
      await _removeRecordFromIndexes(previous);
    }
    for (final record in records) {
      await _addRecordToIndexes(record);
    }
  }

  /// Batch delete multiple sleep records
  Future<void> deleteBatch(List<String> ids) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    final toRemove = <SleepRecord>[];
    for (final id in ids) {
      final record = box.get(id);
      if (record != null) {
        toRemove.add(record);
      }
    }
    await box.deleteAll(ids);
    for (final record in toRemove) {
      await _removeRecordFromIndexes(record);
    }
  }

  Future<Box<dynamic>> _getDateIndexBox() async {
    if (_dateIndexBox != null && _dateIndexBox!.isOpen) {
      return _dateIndexBox!;
    }
    _dateIndexBox = await _openDynamicBox(_dateIndexBoxName);
    return _dateIndexBox!;
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
    final meta = await _getIndexMetaBox();
    final version = _asInt(meta.get('version'));
    final rebuildNeeded = meta.get(_rebuildNeededMetaKey) == true;
    final hasBootstrapWindow =
        meta.get(_indexedFromMetaKey) is String &&
        meta.get(_oldestDataMetaKey) is String;
    var attemptedRebuild = false;

    if (version != _indexVersion || rebuildNeeded || !hasBootstrapWindow) {
      final reason = version != _indexVersion
          ? 'version_mismatch'
          : rebuildNeeded
          ? 'rebuild_needed_flag'
          : 'missing_bootstrap_window';
      await _bootstrapRecentWindowIndexes(reason: reason);
      await meta.put('version', _indexVersion);
      attemptedRebuild = true;
    }

    if (!_integrityChecked) {
      var valid = await _hasValidIndexes();
      if (!valid && !attemptedRebuild) {
        await _bootstrapRecentWindowIndexes(reason: 'integrity_mismatch');
        await meta.put('version', _indexVersion);
        valid = await _hasValidIndexes();
      }

      if (!valid) {
        _useIndexedReads = false;
        await meta.put(_rebuildNeededMetaKey, true);
        _debugLog(
          'Index mismatch persisted after rebuild; falling back to scan mode for this session.',
        );
      } else {
        _useIndexedReads = true;
        await meta.delete(_rebuildNeededMetaKey);
      }
      _indexedFromDate = _parseDateKey('${meta.get(_indexedFromMetaKey)}');
      _backfillComplete = meta.get(_backfillCompleteMetaKey) == true;
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
    for (final record in box.values) {
      if (!_isDateBefore(record.bedTime, indexedFrom)) {
        expectedCount++;
      }
    }
    var indexedCount = 0;
    for (final dynamic value in (await _getDateIndexBox()).values) {
      indexedCount += _readStringList(value).length;
    }
    if (indexedCount != expectedCount) {
      return false;
    }

    var summarizedTotal = 0;
    for (final dynamic value in (await _getDailySummaryBox()).values) {
      summarizedTotal += _readSummary(value)['total'] ?? 0;
    }
    return summarizedTotal == expectedCount;
  }

  Future<void> _bootstrapRecentWindowIndexes({required String reason}) async {
    final box = await _getBox();
    final recordCount = box.length;
    final stopwatch = Stopwatch()..start();
    final indexBox = await _getDateIndexBox();
    final summaryBox = await _getDailySummaryBox();
    final meta = await _getIndexMetaBox();
    await indexBox.clear();
    await summaryBox.clear();

    final dateIndex = <String, List<String>>{};
    final dateSummary = <String, Map<String, int>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bootstrapFrom = today.subtract(
      const Duration(days: _bootstrapWindowDays - 1),
    );
    DateTime? oldestData;
    var scanned = 0;
    for (final record in box.values) {
      scanned++;
      if (scanned % _sessionScanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final bedDate = DateTime(
        record.bedTime.year,
        record.bedTime.month,
        record.bedTime.day,
      );
      if (oldestData == null || bedDate.isBefore(oldestData)) {
        oldestData = bedDate;
      }
      if (_isDateBefore(bedDate, bootstrapFrom)) {
        continue;
      }

      final key = _dateKey(record.bedTime);
      dateIndex.putIfAbsent(key, () => <String>[]).add(record.id);
      _applyRecordDelta(dateSummary.putIfAbsent(key, _newSummary), record, 1);
    }

    if (dateIndex.isNotEmpty) {
      await indexBox.putAll(dateIndex);
    }
    if (dateSummary.isNotEmpty) {
      await summaryBox.putAll(dateSummary);
    }

    final indexedFrom = oldestData == null || oldestData.isAfter(bootstrapFrom)
        ? (oldestData ?? today)
        : bootstrapFrom;
    final backfillComplete =
        oldestData == null || !indexedFrom.isAfter(oldestData);
    await meta.put(_indexedFromMetaKey, _dateKey(indexedFrom));
    await meta.put(_oldestDataMetaKey, _dateKey(oldestData ?? indexedFrom));
    await meta.put(_lastIndexedMetaKey, _dateKey(indexedFrom));
    await meta.put(_backfillCompleteMetaKey, backfillComplete);
    await meta.put(_backfillPausedMetaKey, false);
    await meta.delete(_rebuildNeededMetaKey);

    _indexedFromDate = indexedFrom;
    _backfillComplete = backfillComplete;
    _useIndexedReads = true;

    stopwatch.stop();
    _debugLog(
      'Index rebuild finished. reason=$reason records=$recordCount durationMs=${stopwatch.elapsedMilliseconds}',
    );
  }

  Future<void> _addRecordToIndexes(SleepRecord record) async {
    if (!_useIndexedReads || !_isDateWithinIndexedRange(record.bedTime)) {
      await _markBackfillNeededForDate(record.bedTime);
      return;
    }
    final key = _dateKey(record.bedTime);
    final indexBox = await _getDateIndexBox();
    final ids = _readStringList(indexBox.get(key));
    if (!ids.contains(record.id)) {
      ids.add(record.id);
      await indexBox.put(key, ids);
    }

    final summaryBox = await _getDailySummaryBox();
    final summary = _readSummary(summaryBox.get(key));
    _applyRecordDelta(summary, record, 1);
    await _writeSummary(summaryBox, key, summary);
  }

  Future<void> _removeRecordFromIndexes(SleepRecord record) async {
    if (!_useIndexedReads || !_isDateWithinIndexedRange(record.bedTime)) {
      return;
    }
    final key = _dateKey(record.bedTime);
    final indexBox = await _getDateIndexBox();
    final ids = _readStringList(indexBox.get(key));
    ids.remove(record.id);
    if (ids.isEmpty) {
      await indexBox.delete(key);
    } else {
      await indexBox.put(key, ids);
    }

    final summaryBox = await _getDailySummaryBox();
    final summary = _readSummary(summaryBox.get(key));
    _applyRecordDelta(summary, record, -1);
    await _writeSummary(summaryBox, key, summary);
  }

  Future<void> _writeSummary(
    Box<dynamic> summaryBox,
    String key,
    Map<String, int> summary,
  ) async {
    if ((summary['total'] ?? 0) <= 0) {
      await summaryBox.delete(key);
      return;
    }
    await summaryBox.put(key, summary);
  }

  Map<String, int> _newSummary() {
    return <String, int>{
      'total': 0,
      'mainSleep': 0,
      'nap': 0,
      'totalMinutes': 0,
    };
  }

  Map<String, int> _readSummary(Object? value) {
    final summary = _newSummary();
    if (value is Map) {
      for (final entry in value.entries) {
        final key = '${entry.key}';
        if (!summary.containsKey(key)) continue;
        summary[key] = _asInt(entry.value);
      }
    }
    return summary;
  }

  void _applyRecordDelta(
    Map<String, int> summary,
    SleepRecord record,
    int delta,
  ) {
    summary['total'] = (summary['total'] ?? 0) + delta;
    if (record.isNap) {
      summary['nap'] = (summary['nap'] ?? 0) + delta;
    } else {
      summary['mainSleep'] = (summary['mainSleep'] ?? 0) + delta;
    }
    summary['totalMinutes'] =
        (summary['totalMinutes'] ?? 0) +
        (record.totalSleepHours * 60).round() * delta;

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

  Map<String, int> _buildDailySummary(Iterable<SleepRecord> records) {
    final summary = _newSummary();
    for (final record in records) {
      _applyRecordDelta(summary, record, 1);
    }
    return summary;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isDateWithinIndexedRange(DateTime date) {
    final indexedFrom = _indexedFromDate;
    if (!_useIndexedReads || indexedFrom == null) return false;
    return !_isDateBefore(date, indexedFrom);
  }

  bool _isRangeFullyIndexed(DateTime startDate, DateTime endDate) {
    if (!_useIndexedReads) return false;
    if (_backfillComplete) return true;
    final indexedFrom = _indexedFromDate;
    if (indexedFrom == null) return false;
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) return false;
    return !start.isBefore(indexedFrom);
  }

  DateTime? _regularizedIndexedFrom() {
    final indexedFrom = _indexedFromDate;
    if (indexedFrom == null) return null;
    return _dateOnly(indexedFrom);
  }

  bool _isDateBefore(DateTime a, DateTime b) {
    return _dateOnly(a).isBefore(_dateOnly(b));
  }

  bool _isDateAfter(DateTime a, DateTime b) {
    return _dateOnly(a).isAfter(_dateOnly(b));
  }

  Future<void> _markBackfillNeededForDate(DateTime date) async {
    final meta = await _getIndexMetaBox();
    final dateOnly = _dateOnly(date);
    final existingOldest = _parseDateKey('${meta.get(_oldestDataMetaKey)}');
    if (existingOldest == null || dateOnly.isBefore(existingOldest)) {
      await meta.put(_oldestDataMetaKey, _dateKey(dateOnly));
    }

    final indexedFrom = _indexedFromDate ??
        _parseDateKey('${meta.get(_indexedFromMetaKey)}');
    if (indexedFrom != null && dateOnly.isBefore(indexedFrom)) {
      await meta.put(_backfillCompleteMetaKey, false);
      _backfillComplete = false;
    }
  }

  Future<List<Map<String, dynamic>>> _scanChunkEntries(
    DateTime chunkStart,
    DateTime chunkEnd,
  ) async {
    final start = _dateOnly(chunkStart);
    final end = _dateOnly(chunkEnd);
    final entries = <Map<String, dynamic>>[];
    var scanned = 0;

    for (final record in (await _getBox()).values) {
      scanned++;
      if (scanned % _sessionScanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final bedDate = _dateOnly(record.bedTime);
      if (_isDateBefore(bedDate, start) || _isDateAfter(bedDate, end)) {
        continue;
      }
      entries.add(<String, dynamic>{
        'id': record.id,
        'dateKey': _dateKey(bedDate),
        'isNap': record.isNap,
        'totalMinutes': (record.totalSleepHours * 60).round(),
      });
    }
    return entries;
  }

  List<SleepRecord> _scanRangeFromBox(
    Iterable<SleepRecord> records,
    DateTime startDate,
    DateTime endDate,
  ) {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    return records.where((record) {
      final bedDate = _dateOnly(record.bedTime);
      return !bedDate.isBefore(start) && !bedDate.isAfter(end);
    }).toList();
  }

  Future<List<SleepRecord>> _readIndexedRange(
    Box<SleepRecord> box,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final indexBox = await _getDateIndexBox();
    final out = <SleepRecord>[];
    for (final key in _dateKeysInRange(startDate, endDate)) {
      final ids = _readStringList(indexBox.get(key));
      for (final id in ids) {
        final record = box.get(id);
        if (record != null) {
          out.add(record);
        }
      }
    }
    return out;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('[SleepRecordRepository] $message');
  }
}

Map<String, dynamic> _aggregateSleepChunkWorker(Map<String, dynamic> payload) {
  final entries = (payload['entries'] as List?) ?? const <dynamic>[];
  final indexMap = <String, List<String>>{};
  final summaryMap = <String, Map<String, int>>{};

  for (final raw in entries) {
    if (raw is! Map) continue;
    final id = '${raw['id'] ?? ''}';
    final dateKey = '${raw['dateKey'] ?? ''}';
    final isNap = raw['isNap'] == true;
    final totalMinutes = raw['totalMinutes'] is int
        ? raw['totalMinutes'] as int
        : int.tryParse('${raw['totalMinutes']}') ?? 0;
    if (id.isEmpty || dateKey.length != 8) continue;

    indexMap.putIfAbsent(dateKey, () => <String>[]).add(id);
    final summary = summaryMap.putIfAbsent(dateKey, () {
      return <String, int>{
        'total': 0,
        'mainSleep': 0,
        'nap': 0,
        'totalMinutes': 0,
      };
    });
    summary['total'] = (summary['total'] ?? 0) + 1;
    if (isNap) {
      summary['nap'] = (summary['nap'] ?? 0) + 1;
    } else {
      summary['mainSleep'] = (summary['mainSleep'] ?? 0) + 1;
    }
    summary['totalMinutes'] = (summary['totalMinutes'] ?? 0) + totalMinutes;
  }

  return <String, dynamic>{'indexMap': indexMap, 'summaryMap': summaryMap};
}
