import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/data/history_optimization_models.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../../behavior_module.dart';
import '../models/behavior.dart';
import '../models/behavior_log.dart';
import '../models/behavior_log_reason.dart';
import '../models/behavior_reason.dart';
import '../models/behavior_type.dart';

class BehaviorRepository {
  static const int _indexVersion = 1;
  static const int _bootstrapWindowDays = 30;
  static const int _defaultBackfillChunkDays = 30;
  static const int _scanYieldInterval = 350;

  static const String _rebuildNeededMetaKey = 'rebuild_needed';
  static const String _indexedFromMetaKey = 'indexed_from_date_key';
  static const String _oldestDataMetaKey = 'oldest_data_date_key';
  static const String _lastIndexedMetaKey = 'last_indexed_date_key';
  static const String _backfillCompleteMetaKey = 'backfill_complete';
  static const String _backfillPausedMetaKey = 'backfill_paused';

  BehaviorRepository({
    Future<Box<Behavior>> Function()? behaviorsBoxOpener,
    Future<Box<BehaviorReason>> Function()? reasonsBoxOpener,
    Future<Box<BehaviorLog>> Function()? logsBoxOpener,
    Future<Box<BehaviorLogReason>> Function()? logReasonsBoxOpener,
    Future<Box<dynamic>> Function(String boxName)? dynamicBoxOpener,
  }) : _behaviorsBoxOpener = behaviorsBoxOpener,
       _reasonsBoxOpener = reasonsBoxOpener,
       _logsBoxOpener = logsBoxOpener,
       _logReasonsBoxOpener = logReasonsBoxOpener,
       _dynamicBoxOpener = dynamicBoxOpener;

  final Future<Box<Behavior>> Function()? _behaviorsBoxOpener;
  final Future<Box<BehaviorReason>> Function()? _reasonsBoxOpener;
  final Future<Box<BehaviorLog>> Function()? _logsBoxOpener;
  final Future<Box<BehaviorLogReason>> Function()? _logReasonsBoxOpener;
  final Future<Box<dynamic>> Function(String boxName)? _dynamicBoxOpener;

  Box<Behavior>? _behaviorsBox;
  Box<BehaviorReason>? _reasonsBox;
  Box<BehaviorLog>? _logsBox;
  Box<BehaviorLogReason>? _logReasonsBox;
  Box<dynamic>? _dateIndexBox;
  Box<dynamic>? _behaviorDateIndexBox;
  Box<dynamic>? _reasonByLogIndexBox;
  Box<dynamic>? _dailySummaryBox;
  Box<dynamic>? _metaBox;

  bool _indexesReady = false;
  bool _integrityChecked = false;
  bool _useIndexedReads = true;
  bool _reasonIndexReady = false;
  DateTime? _indexedFromDate;
  Future<void> _indexMutationQueue = Future<void>.value();
  bool _indexMutationInProgress = false;

  Future<Box<Behavior>> _getBehaviorsBox() async {
    if (_behaviorsBox != null && _behaviorsBox!.isOpen) {
      return _behaviorsBox!;
    }
    final opener = _behaviorsBoxOpener;
    if (opener != null) {
      _behaviorsBox = await opener();
      return _behaviorsBox!;
    }
    _behaviorsBox = await HiveService.getBox<Behavior>(
      BehaviorModule.behaviorsBoxName,
    );
    return _behaviorsBox!;
  }

  Future<Box<BehaviorReason>> _getReasonsBox() async {
    if (_reasonsBox != null && _reasonsBox!.isOpen) {
      return _reasonsBox!;
    }
    final opener = _reasonsBoxOpener;
    if (opener != null) {
      _reasonsBox = await opener();
      return _reasonsBox!;
    }
    _reasonsBox = await HiveService.getBox<BehaviorReason>(
      BehaviorModule.reasonsBoxName,
    );
    return _reasonsBox!;
  }

  Future<Box<BehaviorLog>> _getLogsBox() async {
    if (_logsBox != null && _logsBox!.isOpen) {
      return _logsBox!;
    }
    final opener = _logsBoxOpener;
    if (opener != null) {
      _logsBox = await opener();
      return _logsBox!;
    }
    _logsBox = await HiveService.getBox<BehaviorLog>(
      BehaviorModule.logsBoxName,
    );
    return _logsBox!;
  }

  Future<Box<BehaviorLogReason>> _getLogReasonsBox() async {
    if (_logReasonsBox != null && _logReasonsBox!.isOpen) {
      return _logReasonsBox!;
    }
    final opener = _logReasonsBoxOpener;
    if (opener != null) {
      _logReasonsBox = await opener();
      return _logReasonsBox!;
    }
    _logReasonsBox = await HiveService.getBox<BehaviorLogReason>(
      BehaviorModule.logReasonsBoxName,
    );
    return _logReasonsBox!;
  }

  Future<Box<dynamic>> _getDateIndexBox() async {
    if (_dateIndexBox != null && _dateIndexBox!.isOpen) {
      return _dateIndexBox!;
    }
    _dateIndexBox = await _openDynamicBox(BehaviorModule.logDateIndexBoxName);
    return _dateIndexBox!;
  }

  Future<Box<dynamic>> _getBehaviorDateIndexBox() async {
    if (_behaviorDateIndexBox != null && _behaviorDateIndexBox!.isOpen) {
      return _behaviorDateIndexBox!;
    }
    _behaviorDateIndexBox = await _openDynamicBox(
      BehaviorModule.logBehaviorDateIndexBoxName,
    );
    return _behaviorDateIndexBox!;
  }

  Future<Box<dynamic>> _getReasonByLogIndexBox() async {
    if (_reasonByLogIndexBox != null && _reasonByLogIndexBox!.isOpen) {
      return _reasonByLogIndexBox!;
    }
    _reasonByLogIndexBox = await _openDynamicBox(
      BehaviorModule.logReasonByLogIndexBoxName,
    );
    return _reasonByLogIndexBox!;
  }

  Future<Box<dynamic>> _getDailySummaryBox() async {
    if (_dailySummaryBox != null && _dailySummaryBox!.isOpen) {
      return _dailySummaryBox!;
    }
    _dailySummaryBox = await _openDynamicBox(
      BehaviorModule.dailySummaryBoxName,
    );
    return _dailySummaryBox!;
  }

  Future<Box<dynamic>> _getMetaBox() async {
    if (_metaBox != null && _metaBox!.isOpen) {
      return _metaBox!;
    }
    _metaBox = await _openDynamicBox(BehaviorModule.indexMetaBoxName);
    return _metaBox!;
  }

  Future<Box<dynamic>> _openDynamicBox(String boxName) async {
    final opener = _dynamicBoxOpener;
    if (opener != null) {
      return opener(boxName);
    }
    return HiveService.getBox<dynamic>(boxName);
  }

  // ---------------------------------------------------------------------------
  // Behavior config CRUD
  // ---------------------------------------------------------------------------

  Future<Behavior> createBehavior(Behavior behavior) async {
    _validateBehaviorType(behavior.type, fieldName: 'behavior.type');
    await _assertBehaviorNameUnique(behavior.name);
    final stored = behavior.copyWith(
      updatedAt: DateTime.now(),
      deletedAt: null,
    );
    await (await _getBehaviorsBox()).put(stored.id, stored);
    return stored;
  }

  Future<Behavior> updateBehavior(Behavior behavior) async {
    _validateBehaviorType(behavior.type, fieldName: 'behavior.type');
    await _assertBehaviorNameUnique(
      behavior.name,
      excludeBehaviorId: behavior.id,
    );
    final existing = await getBehaviorById(behavior.id);
    if (existing == null) {
      throw StateError('Behavior not found: ${behavior.id}');
    }
    final stored = behavior.copyWith(
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await (await _getBehaviorsBox()).put(stored.id, stored);
    return stored;
  }

  Future<void> softDeleteBehavior(String behaviorId) async {
    final box = await _getBehaviorsBox();
    final existing = box.get(behaviorId);
    if (existing == null || existing.isDeleted) return;
    await box.put(
      behaviorId,
      existing.copyWith(
        isActive: false,
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
      ),
    );
  }

  Future<Behavior?> getBehaviorById(String behaviorId) async {
    return (await _getBehaviorsBox()).get(behaviorId);
  }

  Future<List<Behavior>> getBehaviors({
    bool includeInactive = false,
    bool includeDeleted = false,
  }) async {
    final list = (await _getBehaviorsBox()).values.where((behavior) {
      if (!includeDeleted && behavior.isDeleted) return false;
      if (!includeInactive && !behavior.isActive) return false;
      return true;
    }).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // ---------------------------------------------------------------------------
  // Reason CRUD
  // ---------------------------------------------------------------------------

  Future<BehaviorReason> createReason(BehaviorReason reason) async {
    _validateBehaviorType(reason.type, fieldName: 'reason.type');
    final name = reason.name.trim();
    if (name.isEmpty) {
      throw const FormatException('Reason name is required.');
    }
    final stored = reason.copyWith(
      name: name,
      updatedAt: DateTime.now(),
      deletedAt: null,
    );
    await (await _getReasonsBox()).put(stored.id, stored);
    return stored;
  }

  Future<BehaviorReason> updateReason(BehaviorReason reason) async {
    _validateBehaviorType(reason.type, fieldName: 'reason.type');
    final existing = await getReasonById(reason.id);
    if (existing == null) {
      throw StateError('Reason not found: ${reason.id}');
    }
    final name = reason.name.trim();
    if (name.isEmpty) {
      throw const FormatException('Reason name is required.');
    }
    final stored = reason.copyWith(
      name: name,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await (await _getReasonsBox()).put(stored.id, stored);
    return stored;
  }

  Future<void> softDeleteReason(String reasonId) async {
    final box = await _getReasonsBox();
    final existing = box.get(reasonId);
    if (existing == null || existing.isDeleted) return;
    await box.put(
      reasonId,
      existing.copyWith(
        isActive: false,
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
      ),
    );
  }

  Future<BehaviorReason?> getReasonById(String reasonId) async {
    return (await _getReasonsBox()).get(reasonId);
  }

  Future<List<BehaviorReason>> getReasons({
    String? type,
    bool includeInactive = false,
    bool includeDeleted = false,
  }) async {
    if (type != null) {
      _validateBehaviorType(type, fieldName: 'reason.type');
    }
    final list = (await _getReasonsBox()).values.where((reason) {
      if (type != null && reason.type != type) return false;
      if (!includeDeleted && reason.isDeleted) return false;
      if (!includeInactive && !reason.isActive) return false;
      return true;
    }).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // ---------------------------------------------------------------------------
  // Log CRUD
  // ---------------------------------------------------------------------------

  Future<BehaviorLog> createBehaviorLog({
    required String behaviorId,
    required DateTime occurredAt,
    int? durationMinutes,
    int? intensity,
    String? note,
    List<String> reasonIds = const <String>[],
  }) async {
    return _runIndexMutation(() async {
      await _ensureIndexesReady();
      await _ensureReasonIndexReady();
      _validateLogFields(
        durationMinutes: durationMinutes,
        intensity: intensity,
      );

      final behavior = await _requireBehaviorForLog(
        behaviorId,
        allowInactiveOrDeleted: false,
      );
      final normalizedReasons = _normalizeReasonIds(reasonIds);
      await _validateReasonAssignments(
        behavior: behavior,
        reasonIds: normalizedReasons,
        enforceActive: true,
      );

      final now = DateTime.now();
      final log = BehaviorLog(
        behaviorId: behavior.id,
        occurredAt: occurredAt,
        dateKey: BehaviorLog.deriveDateKey(occurredAt),
        durationMinutes: durationMinutes,
        intensity: intensity,
        note: _normalizeNullableNote(note),
        createdAt: now,
        updatedAt: now,
      );
      await (await _getLogsBox()).put(log.id, log);
      await _replaceReasonAssignments(
        behaviorLogId: log.id,
        reasonIds: normalizedReasons,
        createdAt: now,
      );
      await _addLogToIndexes(log);
      return log;
    });
  }

  Future<BehaviorLog> updateBehaviorLog(
    String logId, {
    String? behaviorId,
    DateTime? occurredAt,
    Object? durationMinutes = _unset,
    Object? intensity = _unset,
    Object? note = _unset,
    List<String>? reasonIds,
  }) async {
    return _runIndexMutation(() async {
      await _ensureIndexesReady();
      await _ensureReasonIndexReady();

      final box = await _getLogsBox();
      final existing = box.get(logId);
      if (existing == null) {
        throw StateError('BehaviorLog not found: $logId');
      }

      final nextBehaviorId = behaviorId ?? existing.behaviorId;
      final isBehaviorChanged = nextBehaviorId != existing.behaviorId;
      final behavior = await _requireBehaviorForLog(
        nextBehaviorId,
        allowInactiveOrDeleted: !isBehaviorChanged,
      );

      final nextOccurredAt = occurredAt ?? existing.occurredAt;
      final nextDuration = durationMinutes == _unset
          ? existing.durationMinutes
          : durationMinutes as int?;
      final nextIntensity = intensity == _unset
          ? existing.intensity
          : intensity as int?;
      final nextNote = note == _unset
          ? existing.note
          : _normalizeNullableNote(note as String?);
      _validateLogFields(
        durationMinutes: nextDuration,
        intensity: nextIntensity,
      );

      final existingReasons = await getReasonIdsForLog(existing.id);
      final nextReasonIds = reasonIds == null
          ? existingReasons
          : _normalizeReasonIds(reasonIds);
      await _validateReasonAssignments(
        behavior: behavior,
        reasonIds: nextReasonIds,
        enforceActive: reasonIds != null,
      );

      final updated = existing.copyWith(
        behaviorId: nextBehaviorId,
        occurredAt: nextOccurredAt,
        dateKey: BehaviorLog.deriveDateKey(nextOccurredAt),
        durationMinutes: nextDuration,
        intensity: nextIntensity,
        note: nextNote,
        updatedAt: DateTime.now(),
      );

      await _removeLogFromIndexes(existing);
      await box.put(updated.id, updated);
      await _addLogToIndexes(updated);
      if (reasonIds != null) {
        await _replaceReasonAssignments(
          behaviorLogId: updated.id,
          reasonIds: nextReasonIds,
        );
      }
      return updated;
    });
  }

  Future<bool> deleteBehaviorLog(String logId) async {
    return _runIndexMutation(() async {
      await _ensureIndexesReady();
      await _ensureReasonIndexReady();
      final box = await _getLogsBox();
      final existing = box.get(logId);
      if (existing == null) return false;

      await box.delete(logId);
      await _removeLogFromIndexes(existing);
      await _deleteReasonAssignments(logId);
      return true;
    });
  }

  Future<BehaviorLog?> getBehaviorLogById(String logId) async {
    return (await _getLogsBox()).get(logId);
  }

  Future<List<String>> getReasonIdsForLog(String behaviorLogId) async {
    await _ensureReasonIndexReady();
    return _readStringList(
      (await _getReasonByLogIndexBox()).get(behaviorLogId),
    );
  }

  Future<Map<String, List<String>>> getReasonIdsByLogIds(
    Iterable<String> behaviorLogIds,
  ) async {
    await _ensureReasonIndexReady();
    final out = <String, List<String>>{};
    final box = await _getReasonByLogIndexBox();
    for (final logId in behaviorLogIds) {
      final normalized = logId;
      if (normalized.isEmpty) continue;
      out[normalized] = _readStringList(box.get(normalized));
    }
    return out;
  }

  Future<List<BehaviorLog>> getBehaviorLogsByDateKey(String dateKey) async {
    await _ensureIndexesReady();
    if (!_isDateKey(dateKey)) {
      return const <BehaviorLog>[];
    }

    if (_indexMutationInProgress ||
        !_useIndexedReads ||
        !_isDateKeyWithinIndexedRange(dateKey)) {
      final scanned = (await _getLogsBox()).values
          .where((log) => log.dateKey == dateKey)
          .toList();
      scanned.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      return scanned;
    }

    final ids = _readStringList((await _getDateIndexBox()).get(dateKey));
    if (ids.isEmpty) {
      return const <BehaviorLog>[];
    }

    final logsBox = await _getLogsBox();
    final out = <BehaviorLog>[];
    for (final id in ids) {
      final log = logsBox.get(id);
      if (log == null) continue;
      if (log.dateKey != dateKey) continue;
      out.add(log);
    }
    out.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return out;
  }

  Future<List<BehaviorLog>> getBehaviorLogsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _ensureIndexesReady();
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) {
      return const <BehaviorLog>[];
    }

    if (_indexMutationInProgress || !_useIndexedReads) {
      return _scanLogsInRange((await _getLogsBox()).values, start, end);
    }

    if (_isRangeFullyIndexed(start, end)) {
      return _readIndexedRange(start, end);
    }

    final indexedFrom = _indexedFromDate;
    if (indexedFrom == null) {
      return _scanLogsInRange((await _getLogsBox()).values, start, end);
    }

    final out = <BehaviorLog>[];
    if (start.isBefore(indexedFrom)) {
      final olderEnd =
          end.isBefore(indexedFrom.subtract(const Duration(days: 1)))
          ? end
          : indexedFrom.subtract(const Duration(days: 1));
      out.addAll(
        _scanLogsInRange((await _getLogsBox()).values, start, olderEnd),
      );
    }

    if (!end.isBefore(indexedFrom)) {
      final indexedStart = start.isBefore(indexedFrom) ? indexedFrom : start;
      out.addAll(await _readIndexedRange(indexedStart, end));
    }

    out.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return out;
  }

  // ---------------------------------------------------------------------------
  // Daily summary access
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getDailySummaryForBehaviorByDate(
    String behaviorId,
    DateTime date,
  ) async {
    await _ensureIndexesReady();
    final day = _dateOnly(date);
    final dayKey = _dateKey(day);
    if (_indexMutationInProgress ||
        !_useIndexedReads ||
        !_isDateWithinIndexedRange(day)) {
      return _computeSummaryForBehaviorDay(
        behaviorId: behaviorId,
        dayKey: dayKey,
      );
    }
    final key = _summaryKey(behaviorId, dayKey);
    return _readSummaryMap(
      (await _getDailySummaryBox()).get(key),
      behaviorId: behaviorId,
      dateKey: dayKey,
    );
  }

  Future<Map<String, Map<String, dynamic>>> getDailySummaryMapInRange(
    DateTime startDate,
    DateTime endDate, {
    List<String>? behaviorIds,
  }) async {
    await _ensureIndexesReady();
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) {
      return const <String, Map<String, dynamic>>{};
    }
    final ids = behaviorIds ?? await _allBehaviorIds();
    if (ids.isEmpty) {
      return const <String, Map<String, dynamic>>{};
    }
    if (_indexMutationInProgress || !_useIndexedReads) {
      return _scanSummaryMapForRange(ids, start, end);
    }

    if (_isRangeFullyIndexed(start, end)) {
      return _readSummaryMapFromBox(ids, start, end);
    }

    final indexedFrom = _indexedFromDate;
    if (indexedFrom == null) {
      return _scanSummaryMapForRange(ids, start, end);
    }

    final out = <String, Map<String, dynamic>>{};
    if (start.isBefore(indexedFrom)) {
      final olderEnd =
          end.isBefore(indexedFrom.subtract(const Duration(days: 1)))
          ? end
          : indexedFrom.subtract(const Duration(days: 1));
      out.addAll(await _scanSummaryMapForRange(ids, start, olderEnd));
    }
    if (!end.isBefore(indexedFrom)) {
      final indexedStart = start.isBefore(indexedFrom) ? indexedFrom : start;
      out.addAll(await _readSummaryMapFromBox(ids, indexedStart, end));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // History optimization and index maintenance
  // ---------------------------------------------------------------------------

  Future<void> setBackfillPaused(bool paused) async {
    await _ensureIndexesReady();
    await (await _getMetaBox()).put(_backfillPausedMetaKey, paused);
  }

  Future<ModuleHistoryOptimizationStatus> getHistoryOptimizationStatus() async {
    await _ensureIndexesReady();
    final meta = await _getMetaBox();
    return ModuleHistoryOptimizationStatus(
      moduleId: 'behavior_tracker',
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
    return _runIndexMutation(() async {
      await _ensureIndexesReady();
      if (!_useIndexedReads) return false;

      final meta = await _getMetaBox();
      if (meta.get(_backfillPausedMetaKey) == true) return false;
      if (meta.get(_backfillCompleteMetaKey) == true) return false;

      final indexedFrom = _parseDateKey('${meta.get(_indexedFromMetaKey)}');
      final oldestData = _parseDateKey('${meta.get(_oldestDataMetaKey)}');
      if (indexedFrom == null || oldestData == null) {
        await meta.put(_rebuildNeededMetaKey, true);
        return false;
      }
      if (!indexedFrom.isAfter(oldestData)) {
        await meta.put(_backfillCompleteMetaKey, true);
        return false;
      }

      final chunkEnd = indexedFrom.subtract(const Duration(days: 1));
      final chunkStartCandidate = chunkEnd.subtract(
        Duration(days: chunkDays - 1),
      );
      final chunkStart = chunkStartCandidate.isBefore(oldestData)
          ? oldestData
          : chunkStartCandidate;

      final logs = await _scanChunkLogs(chunkStart, chunkEnd);
      final dateIndexDelta = <String, Set<String>>{};
      final behaviorDateDelta = <String, Set<String>>{};
      final summaryDelta = <String, Map<String, dynamic>>{};
      for (final log in logs) {
        final dateKey = log.dateKey;
        dateIndexDelta.putIfAbsent(dateKey, () => <String>{}).add(log.id);
        final behaviorDateKey = _behaviorDateKey(log.behaviorId, dateKey);
        behaviorDateDelta
            .putIfAbsent(behaviorDateKey, () => <String>{})
            .add(log.id);
        final summaryKey = _summaryKey(log.behaviorId, dateKey);
        final summary = summaryDelta.putIfAbsent(
          summaryKey,
          () => _newSummary(log.behaviorId, dateKey),
        );
        _applyLogDelta(summary, log, 1);
      }

      await _mergeDateIndexMap(dateIndexDelta);
      await _mergeBehaviorDateIndexMap(behaviorDateDelta);
      await _mergeSummaryMap(summaryDelta);

      final newIndexedFrom = chunkStart;
      final isComplete = !newIndexedFrom.isAfter(oldestData);
      await meta.put(_indexedFromMetaKey, _dateKey(newIndexedFrom));
      await meta.put(_lastIndexedMetaKey, _dateKey(newIndexedFrom));
      await meta.put(_backfillCompleteMetaKey, isComplete);
      _indexedFromDate = newIndexedFrom;
      return true;
    });
  }

  Future<void> rebuildIndexesFromScratch() async {
    await _runIndexMutation(() async {
      _indexesReady = false;
      _integrityChecked = false;
      await _bootstrapRecentWindowIndexes();
      _indexesReady = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Backup helpers
  // ---------------------------------------------------------------------------

  Future<List<Behavior>> getAllBehaviors() async {
    final list = (await _getBehaviorsBox()).values.toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<List<BehaviorReason>> getAllReasons() async {
    final list = (await _getReasonsBox()).values.toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<List<BehaviorLog>> getAllLogs() async {
    final list = (await _getLogsBox()).values.toList();
    list.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return list;
  }

  Future<List<BehaviorLogReason>> getAllLogReasons() async {
    final list = (await _getLogReasonsBox()).values.toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<Map<String, Map<String, dynamic>>> getAllDailySummaryEntries() async {
    await _ensureIndexesReady();
    final out = <String, Map<String, dynamic>>{};
    final box = await _getDailySummaryBox();
    for (final key in box.keys) {
      final summaryKey = '$key';
      final parsed = _parseSummaryKey(summaryKey);
      if (parsed == null) continue;
      final summary = _readSummaryMap(
        box.get(summaryKey),
        behaviorId: parsed.$1,
        dateKey: parsed.$2,
      );
      if (_asInt(summary['totalCount']) <= 0) continue;
      out[summaryKey] = summary;
    }
    return out;
  }

  Future<void> putBehavior(Behavior behavior) async {
    await (await _getBehaviorsBox()).put(behavior.id, behavior);
  }

  Future<void> putReason(BehaviorReason reason) async {
    await (await _getReasonsBox()).put(reason.id, reason);
  }

  Future<void> putLog(BehaviorLog log) async {
    await (await _getLogsBox()).put(log.id, log);
  }

  Future<void> replaceReasonAssignments(
    String behaviorLogId,
    List<String> reasonIds, {
    DateTime? createdAt,
  }) async {
    await _ensureReasonIndexReady();
    await _replaceReasonAssignments(
      behaviorLogId: behaviorLogId,
      reasonIds: _normalizeReasonIds(reasonIds),
      createdAt: createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal indexing
  // ---------------------------------------------------------------------------

  Future<void> _ensureIndexesReady() async {
    if (_indexesReady) return;
    await _ensureReasonIndexReady();
    final meta = await _getMetaBox();
    final version = _asInt(meta.get('version'));
    final rebuildNeeded = meta.get(_rebuildNeededMetaKey) == true;
    final hasBootstrapWindow =
        meta.get(_indexedFromMetaKey) is String &&
        meta.get(_oldestDataMetaKey) is String;
    var attemptedRebuild = false;

    if (version != _indexVersion || rebuildNeeded || !hasBootstrapWindow) {
      await _bootstrapRecentWindowIndexes();
      await meta.put('version', _indexVersion);
      attemptedRebuild = true;
    }

    if (!_integrityChecked) {
      var valid = await _hasValidIndexes();
      if (!valid && !attemptedRebuild) {
        await _bootstrapRecentWindowIndexes();
        await meta.put('version', _indexVersion);
        valid = await _hasValidIndexes();
      }

      if (!valid) {
        _useIndexedReads = false;
        await meta.put(_rebuildNeededMetaKey, true);
      } else {
        _useIndexedReads = true;
        await meta.delete(_rebuildNeededMetaKey);
      }

      _indexedFromDate = _parseDateKey('${meta.get(_indexedFromMetaKey)}');
      _integrityChecked = true;
    }
    _indexesReady = true;
  }

  Future<void> _ensureReasonIndexReady() async {
    if (_reasonIndexReady) return;
    final joins = await _getLogReasonsBox();
    final index = await _getReasonByLogIndexBox();
    await index.clear();

    final map = <String, Set<String>>{};
    for (final item in joins.values) {
      if (item.behaviorLogId.isEmpty || item.reasonId.isEmpty) continue;
      map.putIfAbsent(item.behaviorLogId, () => <String>{}).add(item.reasonId);
    }

    if (map.isNotEmpty) {
      final write = <String, List<String>>{};
      for (final entry in map.entries) {
        final list = entry.value.toList()..sort();
        write[entry.key] = list;
      }
      await index.putAll(write);
    }
    _reasonIndexReady = true;
  }

  Future<void> _bootstrapRecentWindowIndexes() async {
    final logsBox = await _getLogsBox();
    final dateIndexBox = await _getDateIndexBox();
    final behaviorDateIndexBox = await _getBehaviorDateIndexBox();
    final summaryBox = await _getDailySummaryBox();
    final meta = await _getMetaBox();

    await dateIndexBox.clear();
    await behaviorDateIndexBox.clear();
    await summaryBox.clear();

    final now = DateTime.now();
    final today = _dateOnly(now);
    final bootstrapFrom = today.subtract(
      const Duration(days: _bootstrapWindowDays - 1),
    );

    DateTime? oldestData;
    final dateIndexMap = <String, Set<String>>{};
    final behaviorDateMap = <String, Set<String>>{};
    final summaryMap = <String, Map<String, dynamic>>{};

    var scanned = 0;
    for (final log in logsBox.values) {
      scanned++;
      if (scanned % _scanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      final day = _parseDateKey(log.dateKey) ?? _dateOnly(log.occurredAt);
      if (oldestData == null || day.isBefore(oldestData)) {
        oldestData = day;
      }
      if (day.isBefore(bootstrapFrom)) {
        continue;
      }

      final dateKey = _dateKey(day);
      dateIndexMap.putIfAbsent(dateKey, () => <String>{}).add(log.id);
      final behaviorDateKey = _behaviorDateKey(log.behaviorId, dateKey);
      behaviorDateMap
          .putIfAbsent(behaviorDateKey, () => <String>{})
          .add(log.id);

      final summaryKey = _summaryKey(log.behaviorId, dateKey);
      final summary = summaryMap.putIfAbsent(
        summaryKey,
        () => _newSummary(log.behaviorId, dateKey),
      );
      _applyLogDelta(summary, log, 1);
    }

    await _writeDateIndexMap(dateIndexMap);
    await _writeBehaviorDateIndexMap(behaviorDateMap);
    if (summaryMap.isNotEmpty) {
      await summaryBox.putAll(summaryMap);
    }

    final indexedFrom = oldestData == null || oldestData.isAfter(bootstrapFrom)
        ? (oldestData ?? today)
        : bootstrapFrom;
    final backfillComplete =
        oldestData == null || !indexedFrom.isAfter(oldestData);

    await meta.put('version', _indexVersion);
    await meta.put(_indexedFromMetaKey, _dateKey(indexedFrom));
    await meta.put(_oldestDataMetaKey, _dateKey(oldestData ?? indexedFrom));
    await meta.put(_lastIndexedMetaKey, _dateKey(indexedFrom));
    await meta.put(_backfillCompleteMetaKey, backfillComplete);
    await meta.put(_backfillPausedMetaKey, false);
    await meta.delete(_rebuildNeededMetaKey);

    _indexedFromDate = indexedFrom;
    _useIndexedReads = true;
  }

  Future<bool> _hasValidIndexes() async {
    final logs = await _getLogsBox();
    if (logs.isEmpty) return true;

    final indexedFrom =
        _indexedFromDate ??
        _parseDateKey('${(await _getMetaBox()).get(_indexedFromMetaKey)}');
    if (indexedFrom == null) return false;

    final expectedDate = <String, Set<String>>{};
    final expectedBehaviorDate = <String, Set<String>>{};
    final expectedSummary = <String, Map<String, dynamic>>{};
    for (final log in logs.values) {
      final day = _parseDateKey(log.dateKey) ?? _dateOnly(log.occurredAt);
      if (day.isBefore(indexedFrom)) continue;

      final dateKey = _dateKey(day);
      expectedDate.putIfAbsent(dateKey, () => <String>{}).add(log.id);
      final behaviorDateKey = _behaviorDateKey(log.behaviorId, dateKey);
      expectedBehaviorDate
          .putIfAbsent(behaviorDateKey, () => <String>{})
          .add(log.id);
      final summaryKey = _summaryKey(log.behaviorId, dateKey);
      final summary = expectedSummary.putIfAbsent(
        summaryKey,
        () => _newSummary(log.behaviorId, dateKey),
      );
      _applyLogDelta(summary, log, 1);
    }

    if (!await _compareStringListMap(await _getDateIndexBox(), expectedDate)) {
      return false;
    }
    if (!await _compareStringListMap(
      await _getBehaviorDateIndexBox(),
      expectedBehaviorDate,
    )) {
      return false;
    }

    final summaryBox = await _getDailySummaryBox();
    if (summaryBox.length != expectedSummary.length) return false;
    for (final entry in expectedSummary.entries) {
      final parsed = _parseSummaryKey(entry.key);
      if (parsed == null) return false;
      final actual = _readSummaryMap(
        summaryBox.get(entry.key),
        behaviorId: parsed.$1,
        dateKey: parsed.$2,
      );
      if (_asInt(actual['totalCount']) != _asInt(entry.value['totalCount'])) {
        return false;
      }
      if (_asInt(actual['totalDurationMinutes']) !=
          _asInt(entry.value['totalDurationMinutes'])) {
        return false;
      }
      if (_asInt(actual['intensitySum']) !=
          _asInt(entry.value['intensitySum'])) {
        return false;
      }
      if (_asInt(actual['intensityCount']) !=
          _asInt(entry.value['intensityCount'])) {
        return false;
      }
    }
    return true;
  }

  Future<void> _addLogToIndexes(BehaviorLog log) async {
    if (!_useIndexedReads || !_isDateKeyWithinIndexedRange(log.dateKey)) {
      await _markBackfillNeededForDateKey(log.dateKey);
      return;
    }
    await _addToStringListIndex(await _getDateIndexBox(), log.dateKey, log.id);
    await _addToStringListIndex(
      await _getBehaviorDateIndexBox(),
      _behaviorDateKey(log.behaviorId, log.dateKey),
      log.id,
    );

    final summaryBox = await _getDailySummaryBox();
    final key = _summaryKey(log.behaviorId, log.dateKey);
    final summary = _readSummaryMap(
      summaryBox.get(key),
      behaviorId: log.behaviorId,
      dateKey: log.dateKey,
    );
    _applyLogDelta(summary, log, 1);
    await summaryBox.put(key, summary);
  }

  Future<void> _removeLogFromIndexes(BehaviorLog log) async {
    if (!_useIndexedReads || !_isDateKeyWithinIndexedRange(log.dateKey)) {
      return;
    }
    await _removeFromStringListIndex(
      await _getDateIndexBox(),
      log.dateKey,
      log.id,
    );
    await _removeFromStringListIndex(
      await _getBehaviorDateIndexBox(),
      _behaviorDateKey(log.behaviorId, log.dateKey),
      log.id,
    );

    final summaryBox = await _getDailySummaryBox();
    final key = _summaryKey(log.behaviorId, log.dateKey);
    final summary = _readSummaryMap(
      summaryBox.get(key),
      behaviorId: log.behaviorId,
      dateKey: log.dateKey,
    );
    _applyLogDelta(summary, log, -1);
    if (_asInt(summary['totalCount']) <= 0) {
      await summaryBox.delete(key);
    } else {
      await summaryBox.put(key, summary);
    }
  }

  Future<void> _replaceReasonAssignments({
    required String behaviorLogId,
    required List<String> reasonIds,
    DateTime? createdAt,
  }) async {
    final joins = await _getLogReasonsBox();
    final index = await _getReasonByLogIndexBox();
    final target = reasonIds.toSet();
    final current = _readStringList(index.get(behaviorLogId)).toSet();

    final toRemove = current.difference(target);
    final toAdd = target.difference(current);
    for (final reasonId in toRemove) {
      await joins.delete(_logReasonJoinId(behaviorLogId, reasonId));
    }
    for (final reasonId in toAdd) {
      final now = createdAt ?? DateTime.now();
      final joinId = _logReasonJoinId(behaviorLogId, reasonId);
      await joins.put(
        joinId,
        BehaviorLogReason(
          id: joinId,
          behaviorLogId: behaviorLogId,
          reasonId: reasonId,
          createdAt: now,
        ),
      );
    }

    if (target.isEmpty) {
      await index.delete(behaviorLogId);
    } else {
      final list = target.toList()..sort();
      await index.put(behaviorLogId, list);
    }
  }

  Future<void> _deleteReasonAssignments(String behaviorLogId) async {
    final joins = await _getLogReasonsBox();
    final index = await _getReasonByLogIndexBox();
    final current = _readStringList(index.get(behaviorLogId));
    for (final reasonId in current) {
      await joins.delete(_logReasonJoinId(behaviorLogId, reasonId));
    }
    await index.delete(behaviorLogId);
  }

  Future<void> _mergeDateIndexMap(Map<String, Set<String>> delta) async {
    if (delta.isEmpty) return;
    final box = await _getDateIndexBox();
    for (final entry in delta.entries) {
      final merged = <String>{
        ..._readStringList(box.get(entry.key)),
        ...entry.value,
      }.toList()..sort();
      await box.put(entry.key, merged);
    }
  }

  Future<void> _mergeBehaviorDateIndexMap(
    Map<String, Set<String>> delta,
  ) async {
    if (delta.isEmpty) return;
    final box = await _getBehaviorDateIndexBox();
    for (final entry in delta.entries) {
      final merged = <String>{
        ..._readStringList(box.get(entry.key)),
        ...entry.value,
      }.toList()..sort();
      await box.put(entry.key, merged);
    }
  }

  Future<void> _mergeSummaryMap(Map<String, Map<String, dynamic>> delta) async {
    if (delta.isEmpty) return;
    final box = await _getDailySummaryBox();
    for (final entry in delta.entries) {
      final parsed = _parseSummaryKey(entry.key);
      if (parsed == null) continue;
      final merged = _readSummaryMap(
        box.get(entry.key),
        behaviorId: parsed.$1,
        dateKey: parsed.$2,
      );
      merged['totalCount'] =
          _asInt(merged['totalCount']) + _asInt(entry.value['totalCount']);
      merged['totalDurationMinutes'] =
          _asInt(merged['totalDurationMinutes']) +
          _asInt(entry.value['totalDurationMinutes']);
      merged['intensitySum'] =
          _asInt(merged['intensitySum']) + _asInt(entry.value['intensitySum']);
      merged['intensityCount'] =
          _asInt(merged['intensityCount']) +
          _asInt(entry.value['intensityCount']);
      merged['updatedAt'] = DateTime.now();
      if (_asInt(merged['totalCount']) <= 0) {
        await box.delete(entry.key);
      } else {
        await box.put(entry.key, merged);
      }
    }
  }

  Future<void> _writeDateIndexMap(Map<String, Set<String>> map) async {
    if (map.isEmpty) return;
    final box = await _getDateIndexBox();
    final write = <String, List<String>>{};
    for (final entry in map.entries) {
      final list = entry.value.toList()..sort();
      write[entry.key] = list;
    }
    await box.putAll(write);
  }

  Future<void> _writeBehaviorDateIndexMap(Map<String, Set<String>> map) async {
    if (map.isEmpty) return;
    final box = await _getBehaviorDateIndexBox();
    final write = <String, List<String>>{};
    for (final entry in map.entries) {
      final list = entry.value.toList()..sort();
      write[entry.key] = list;
    }
    await box.putAll(write);
  }

  Future<void> _addToStringListIndex(
    Box<dynamic> box,
    String key,
    String value,
  ) async {
    final current = _readStringList(box.get(key)).toSet();
    if (!current.add(value)) return;
    final list = current.toList()..sort();
    await box.put(key, list);
  }

  Future<void> _removeFromStringListIndex(
    Box<dynamic> box,
    String key,
    String value,
  ) async {
    final current = _readStringList(box.get(key)).toSet();
    if (!current.remove(value)) return;
    if (current.isEmpty) {
      await box.delete(key);
      return;
    }
    final list = current.toList()..sort();
    await box.put(key, list);
  }

  Future<List<BehaviorLog>> _readIndexedRange(
    DateTime start,
    DateTime end,
  ) async {
    final out = <BehaviorLog>[];
    final dateIndexBox = await _getDateIndexBox();
    final logsBox = await _getLogsBox();
    var day = _dateOnly(start);
    final endOnly = _dateOnly(end);
    while (!day.isAfter(endOnly)) {
      final dayKey = _dateKey(day);
      final ids = _readStringList(dateIndexBox.get(dayKey));
      for (final id in ids) {
        final log = logsBox.get(id);
        if (log == null) continue;
        if (log.dateKey != dayKey) continue;
        out.add(log);
      }
      day = day.add(const Duration(days: 1));
    }
    out.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return out;
  }

  List<BehaviorLog> _scanLogsInRange(
    Iterable<BehaviorLog> logs,
    DateTime start,
    DateTime end,
  ) {
    final startKey = _dateKey(start);
    final endKey = _dateKey(end);
    final out = <BehaviorLog>[];
    for (final log in logs) {
      if (log.dateKey.compareTo(startKey) < 0) continue;
      if (log.dateKey.compareTo(endKey) > 0) continue;
      out.add(log);
    }
    out.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return out;
  }

  Future<List<BehaviorLog>> _scanChunkLogs(DateTime start, DateTime end) async {
    final logs = <BehaviorLog>[];
    final startKey = _dateKey(start);
    final endKey = _dateKey(end);
    var scanned = 0;
    for (final log in (await _getLogsBox()).values) {
      scanned++;
      if (scanned % _scanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      if (log.dateKey.compareTo(startKey) < 0) continue;
      if (log.dateKey.compareTo(endKey) > 0) continue;
      logs.add(log);
    }
    return logs;
  }

  Future<void> _markBackfillNeededForDateKey(String dateKey) async {
    final meta = await _getMetaBox();
    final day = _parseDateKey(dateKey);
    if (day == null) return;
    final existingOldest = _parseDateKey('${meta.get(_oldestDataMetaKey)}');
    if (existingOldest == null || day.isBefore(existingOldest)) {
      await meta.put(_oldestDataMetaKey, _dateKey(day));
    }
    final indexedFrom =
        _indexedFromDate ?? _parseDateKey('${meta.get(_indexedFromMetaKey)}');
    if (indexedFrom != null && day.isBefore(indexedFrom)) {
      await meta.put(_backfillCompleteMetaKey, false);
    }
  }

  Future<Map<String, dynamic>> _computeSummaryForBehaviorDay({
    required String behaviorId,
    required String dayKey,
  }) async {
    final summary = _newSummary(behaviorId, dayKey);
    for (final log in (await _getLogsBox()).values) {
      if (log.behaviorId != behaviorId) continue;
      if (log.dateKey != dayKey) continue;
      _applyLogDelta(summary, log, 1);
    }
    return summary;
  }

  Future<Map<String, Map<String, dynamic>>> _readSummaryMapFromBox(
    List<String> behaviorIds,
    DateTime start,
    DateTime end,
  ) async {
    final dateKeys = _dateKeysInRange(start, end);
    final summaryBox = await _getDailySummaryBox();
    final out = <String, Map<String, dynamic>>{};
    for (final behaviorId in behaviorIds) {
      for (final dateKey in dateKeys) {
        final key = _summaryKey(behaviorId, dateKey);
        final summary = _readSummaryMap(
          summaryBox.get(key),
          behaviorId: behaviorId,
          dateKey: dateKey,
        );
        if (_asInt(summary['totalCount']) <= 0) continue;
        out[key] = summary;
      }
    }
    return out;
  }

  Future<Map<String, Map<String, dynamic>>> _scanSummaryMapForRange(
    List<String> behaviorIds,
    DateTime start,
    DateTime end,
  ) async {
    if (end.isBefore(start)) {
      return const <String, Map<String, dynamic>>{};
    }
    final behaviorSet = behaviorIds.toSet();
    final logs = _scanLogsInRange((await _getLogsBox()).values, start, end);
    final out = <String, Map<String, dynamic>>{};
    for (final log in logs) {
      if (!behaviorSet.contains(log.behaviorId)) continue;
      final key = _summaryKey(log.behaviorId, log.dateKey);
      final summary = out.putIfAbsent(
        key,
        () => _newSummary(log.behaviorId, log.dateKey),
      );
      _applyLogDelta(summary, log, 1);
    }
    return out;
  }

  void _applyLogDelta(
    Map<String, dynamic> summary,
    BehaviorLog log,
    int delta,
  ) {
    summary['totalCount'] = (_asInt(summary['totalCount']) + delta).clamp(
      0,
      2147483647,
    );
    summary['totalDurationMinutes'] =
        (_asInt(summary['totalDurationMinutes']) +
                ((log.durationMinutes ?? 0) * delta))
            .clamp(0, 2147483647);

    final intensity = log.intensity;
    if (intensity != null) {
      summary['intensitySum'] =
          (_asInt(summary['intensitySum']) + (intensity * delta)).clamp(
            0,
            2147483647,
          );
      summary['intensityCount'] = (_asInt(summary['intensityCount']) + delta)
          .clamp(0, 2147483647);
    }
    summary['updatedAt'] = DateTime.now();
  }

  Map<String, dynamic> _newSummary(String behaviorId, String dateKey) {
    final now = DateTime.now();
    return <String, dynamic>{
      'behaviorId': behaviorId,
      'dateKey': dateKey,
      'totalCount': 0,
      'totalDurationMinutes': 0,
      'intensitySum': 0,
      'intensityCount': 0,
      'createdAt': now,
      'updatedAt': now,
    };
  }

  Map<String, dynamic> _readSummaryMap(
    dynamic raw, {
    required String behaviorId,
    required String dateKey,
  }) {
    if (raw is! Map) {
      return _newSummary(behaviorId, dateKey);
    }
    return <String, dynamic>{
      'behaviorId': '${raw['behaviorId'] ?? behaviorId}',
      'dateKey': '${raw['dateKey'] ?? dateKey}',
      'totalCount': _asInt(raw['totalCount']),
      'totalDurationMinutes': _asInt(raw['totalDurationMinutes']),
      'intensitySum': _asInt(raw['intensitySum']),
      'intensityCount': _asInt(raw['intensityCount']),
      'createdAt': raw['createdAt'] is DateTime
          ? raw['createdAt'] as DateTime
          : DateTime.now(),
      'updatedAt': raw['updatedAt'] is DateTime
          ? raw['updatedAt'] as DateTime
          : DateTime.now(),
    };
  }

  String _summaryKey(String behaviorId, String dateKey) {
    return '$behaviorId|$dateKey';
  }

  String _behaviorDateKey(String behaviorId, String dateKey) {
    return '$behaviorId|$dateKey';
  }

  (String, String)? _parseSummaryKey(String key) {
    final i = key.lastIndexOf('|');
    if (i <= 0 || i >= key.length - 1) return null;
    final behaviorId = key.substring(0, i);
    final dateKey = key.substring(i + 1);
    if (!_isDateKey(dateKey)) return null;
    return (behaviorId, dateKey);
  }

  String _logReasonJoinId(String behaviorLogId, String reasonId) {
    return '$behaviorLogId|$reasonId';
  }

  // ---------------------------------------------------------------------------
  // Validation and helpers
  // ---------------------------------------------------------------------------

  Future<Behavior> _requireBehaviorForLog(
    String behaviorId, {
    required bool allowInactiveOrDeleted,
  }) async {
    final behavior = await getBehaviorById(behaviorId);
    if (behavior == null) {
      throw StateError('Behavior not found: $behaviorId');
    }
    if (!allowInactiveOrDeleted && (behavior.isDeleted || !behavior.isActive)) {
      throw StateError('Behavior is missing or inactive: $behaviorId');
    }
    return behavior;
  }

  Future<void> _validateReasonAssignments({
    required Behavior behavior,
    required List<String> reasonIds,
    required bool enforceActive,
  }) async {
    if (behavior.reasonRequired && reasonIds.isEmpty) {
      throw const FormatException(
        'This behavior requires at least one reason.',
      );
    }
    if (reasonIds.isEmpty) return;
    for (final reasonId in reasonIds) {
      final reason = await getReasonById(reasonId);
      if (reason == null) {
        throw StateError('Reason not found: $reasonId');
      }
      if (reason.type != behavior.type) {
        throw FormatException(
          'Reason type (${reason.type}) must match behavior type (${behavior.type}).',
        );
      }
      if (enforceActive && (reason.isDeleted || !reason.isActive)) {
        throw StateError('Reason is missing or inactive: $reasonId');
      }
    }
  }

  void _validateLogFields({int? durationMinutes, int? intensity}) {
    if (durationMinutes != null && durationMinutes < 0) {
      throw const FormatException('duration_minutes must be >= 0.');
    }
    if (intensity != null && (intensity < 1 || intensity > 5)) {
      throw const FormatException('intensity must be between 1 and 5.');
    }
  }

  void _validateBehaviorType(String value, {required String fieldName}) {
    if (!BehaviorType.isValid(value)) {
      throw FormatException('Invalid $fieldName: $value');
    }
  }

  Future<void> _assertBehaviorNameUnique(
    String name, {
    String? excludeBehaviorId,
  }) async {
    final normalized = _normalizeSpaces(name).toLowerCase();
    if (normalized.isEmpty) {
      throw const FormatException('Behavior name is required.');
    }
    for (final behavior in (await _getBehaviorsBox()).values) {
      if (excludeBehaviorId != null && behavior.id == excludeBehaviorId) {
        continue;
      }
      if (behavior.isDeleted) continue;
      if (_normalizeSpaces(behavior.name).toLowerCase() == normalized) {
        throw StateError('Behavior name already exists: ${behavior.name}');
      }
    }
  }

  String _normalizeSpaces(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _normalizeNullableNote(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> _normalizeReasonIds(List<String> reasonIds) {
    final out = <String>[];
    final seen = <String>{};
    for (final value in reasonIds) {
      final normalized = value.trim();
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized)) continue;
      out.add(normalized);
    }
    return out;
  }

  Future<List<String>> _allBehaviorIds() async {
    return (await _getBehaviorsBox()).values.map((b) => b.id).toList();
  }

  Future<bool> _compareStringListMap(
    Box<dynamic> actualBox,
    Map<String, Set<String>> expected,
  ) async {
    if (actualBox.length != expected.length) {
      return false;
    }
    for (final entry in expected.entries) {
      final actual = _readStringList(actualBox.get(entry.key)).toSet();
      if (actual.length != entry.value.length) return false;
      if (!actual.containsAll(entry.value)) return false;
    }
    return true;
  }

  List<String> _readStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) => '$item')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  bool _isDateWithinIndexedRange(DateTime date) {
    final indexedFrom = _indexedFromDate;
    if (!_useIndexedReads || indexedFrom == null) return false;
    return !_dateOnly(date).isBefore(_dateOnly(indexedFrom));
  }

  bool _isDateKeyWithinIndexedRange(String dateKey) {
    final day = _parseDateKey(dateKey);
    if (day == null) return false;
    return _isDateWithinIndexedRange(day);
  }

  bool _isRangeFullyIndexed(DateTime start, DateTime end) {
    final indexedFrom = _indexedFromDate;
    if (indexedFrom == null) return false;
    return !_dateOnly(start).isBefore(_dateOnly(indexedFrom));
  }

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _dateKey(DateTime date) {
    final day = _dateOnly(date);
    final yyyy = day.year.toString().padLeft(4, '0');
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return '$yyyy$mm$dd';
  }

  bool _isDateKey(String key) {
    return RegExp(r'^\d{8}$').hasMatch(key);
  }

  DateTime? _parseDateKey(String key) {
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(key);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  List<String> _dateKeysInRange(DateTime start, DateTime end) {
    final out = <String>[];
    var day = _dateOnly(start);
    final endOnly = _dateOnly(end);
    while (!day.isAfter(endOnly)) {
      out.add(_dateKey(day));
      day = day.add(const Duration(days: 1));
    }
    return out;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  Future<T> _runIndexMutation<T>(Future<T> Function() action) {
    final run = _indexMutationQueue
        .catchError((Object error, StackTrace stackTrace) {})
        .then((_) async {
          _indexMutationInProgress = true;
          try {
            return await action();
          } finally {
            _indexMutationInProgress = false;
          }
        });

    _indexMutationQueue = run.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return run;
  }

  void debugLog(String message) {
    if (!(kDebugMode || kProfileMode)) return;
    debugPrint('[BehaviorRepository] $message');
  }
}

const Object _unset = Object();
