import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/data/history_optimization_models.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../../mbt_module.dart';
import '../models/mood.dart';
import '../models/mood_entry.dart';
import '../models/mood_polarity.dart';
import '../models/mood_reason.dart';

/// Repository for MBT Mood module.
///
/// Includes:
/// - Config CRUD (moods, reasons)
/// - Mood entry CRUD with multi-entry-per-day support (full timestamps)
/// - Date index + daily summary + resumable backfill metadata
class MoodRepository {
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

  MoodRepository({
    Future<Box<Mood>> Function()? moodsBoxOpener,
    Future<Box<MoodReason>> Function()? reasonsBoxOpener,
    Future<Box<MoodEntry>> Function()? entriesBoxOpener,
    Future<Box<dynamic>> Function(String boxName)? dynamicBoxOpener,
  }) : _moodsBoxOpener = moodsBoxOpener,
       _reasonsBoxOpener = reasonsBoxOpener,
       _entriesBoxOpener = entriesBoxOpener,
       _dynamicBoxOpener = dynamicBoxOpener;

  final Future<Box<Mood>> Function()? _moodsBoxOpener;
  final Future<Box<MoodReason>> Function()? _reasonsBoxOpener;
  final Future<Box<MoodEntry>> Function()? _entriesBoxOpener;
  final Future<Box<dynamic>> Function(String boxName)? _dynamicBoxOpener;

  Box<Mood>? _moodsBox;
  Box<MoodReason>? _reasonsBox;
  Box<MoodEntry>? _entriesBox;
  Box<dynamic>? _dateIndexBox;
  Box<dynamic>? _dailySummaryBox;
  Box<dynamic>? _metaBox;

  bool _indexesReady = false;
  bool _integrityChecked = false;
  bool _useIndexedReads = true;
  DateTime? _indexedFromDate;
  Future<void> _indexMutationQueue = Future<void>.value();
  bool _indexMutationInProgress = false;

  Future<Box<Mood>> _getMoodsBox() async {
    if (_moodsBox != null && _moodsBox!.isOpen) {
      return _moodsBox!;
    }
    final opener = _moodsBoxOpener;
    if (opener != null) {
      _moodsBox = await opener();
      return _moodsBox!;
    }
    _moodsBox = await HiveService.getBox<Mood>(MbtModule.moodsBoxName);
    return _moodsBox!;
  }

  Future<Box<MoodReason>> _getReasonsBox() async {
    if (_reasonsBox != null && _reasonsBox!.isOpen) {
      return _reasonsBox!;
    }
    final opener = _reasonsBoxOpener;
    if (opener != null) {
      _reasonsBox = await opener();
      return _reasonsBox!;
    }
    _reasonsBox = await HiveService.getBox<MoodReason>(
      MbtModule.moodReasonsBoxName,
    );
    return _reasonsBox!;
  }

  Future<Box<MoodEntry>> _getEntriesBox() async {
    if (_entriesBox != null && _entriesBox!.isOpen) {
      return _entriesBox!;
    }
    final opener = _entriesBoxOpener;
    if (opener != null) {
      _entriesBox = await opener();
      return _entriesBox!;
    }
    _entriesBox = await HiveService.getBox<MoodEntry>(
      MbtModule.moodEntriesBoxName,
    );
    return _entriesBox!;
  }

  Future<Box<dynamic>> _getDateIndexBox() async {
    if (_dateIndexBox != null && _dateIndexBox!.isOpen) {
      return _dateIndexBox!;
    }
    _dateIndexBox = await _openDynamicBox(MbtModule.moodEntryDateIndexBoxName);
    return _dateIndexBox!;
  }

  Future<Box<dynamic>> _getDailySummaryBox() async {
    if (_dailySummaryBox != null && _dailySummaryBox!.isOpen) {
      return _dailySummaryBox!;
    }
    _dailySummaryBox = await _openDynamicBox(MbtModule.moodDailySummaryBoxName);
    return _dailySummaryBox!;
  }

  Future<Box<dynamic>> _getMetaBox() async {
    if (_metaBox != null && _metaBox!.isOpen) {
      return _metaBox!;
    }
    _metaBox = await _openDynamicBox(MbtModule.moodIndexMetaBoxName);
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
  // Mood config CRUD
  // ---------------------------------------------------------------------------

  Future<Mood> createMood(Mood mood) async {
    _validatePolarity(mood.polarity, fieldName: 'mood.polarity');
    await _assertMoodNameUnique(mood.name);

    final now = DateTime.now();
    final stored = mood.copyWith(
      createdAt: mood.createdAt,
      updatedAt: now,
      deletedAt: null,
    );
    await (await _getMoodsBox()).put(stored.id, stored);
    return stored;
  }

  Future<Mood> updateMood(Mood mood) async {
    return _runIndexMutation(() async {
      _validatePolarity(mood.polarity, fieldName: 'mood.polarity');
      await _assertMoodNameUnique(mood.name, excludeMoodId: mood.id);

      final existing = await getMoodById(mood.id);
      if (existing == null) {
        throw StateError('Mood not found: ${mood.id}');
      }

      final stored = mood.copyWith(
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      await (await _getMoodsBox()).put(stored.id, stored);
      await _rebuildSummaryForMood(stored.id);
      return stored;
    });
  }

  Future<void> softDeleteMood(String moodId) async {
    await _runIndexMutation(() async {
      final box = await _getMoodsBox();
      final mood = box.get(moodId);
      if (mood == null || mood.isDeleted) return;
      await box.put(
        mood.id,
        mood.copyWith(
          isActive: false,
          deletedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await _rebuildSummaryForMood(moodId);
    });
  }

  Future<Mood?> getMoodById(String moodId) async {
    return (await _getMoodsBox()).get(moodId);
  }

  Future<List<Mood>> getMoods({
    bool includeInactive = false,
    bool includeDeleted = false,
  }) async {
    final list = (await _getMoodsBox()).values.where((mood) {
      if (!includeDeleted && mood.isDeleted) return false;
      if (!includeInactive && !mood.isActive) return false;
      return true;
    }).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // ---------------------------------------------------------------------------
  // Reason CRUD
  // ---------------------------------------------------------------------------

  Future<MoodReason> createReason(MoodReason reason) async {
    _validatePolarity(reason.type, fieldName: 'reason.type');
    await _assertReasonNameUnique(reason.name, reasonType: reason.type);
    final stored = reason.copyWith(updatedAt: DateTime.now(), deletedAt: null);
    await (await _getReasonsBox()).put(stored.id, stored);
    return stored;
  }

  Future<MoodReason> updateReason(MoodReason reason) async {
    _validatePolarity(reason.type, fieldName: 'reason.type');
    await _assertReasonNameUnique(
      reason.name,
      reasonType: reason.type,
      excludeReasonId: reason.id,
    );

    final existing = await getReasonById(reason.id);
    if (existing == null) {
      throw StateError('Reason not found: ${reason.id}');
    }

    final stored = reason.copyWith(
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await (await _getReasonsBox()).put(stored.id, stored);
    return stored;
  }

  Future<void> softDeleteReason(String reasonId) async {
    final box = await _getReasonsBox();
    final reason = box.get(reasonId);
    if (reason == null || reason.isDeleted) return;
    await box.put(
      reason.id,
      reason.copyWith(
        isActive: false,
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<MoodReason?> getReasonById(String reasonId) async {
    return (await _getReasonsBox()).get(reasonId);
  }

  Future<List<MoodReason>> getReasons({
    String? type,
    bool includeInactive = false,
    bool includeDeleted = false,
  }) async {
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
  // Entry CRUD
  // ---------------------------------------------------------------------------

  /// Adds a new mood entry (always creates; never overwrites).
  ///
  /// Use [loggedAt] with full timestamp. Default to device time when logging.
  Future<MoodEntry> addMoodEntry({
    required DateTime loggedAt,
    required String moodId,
    List<String>? reasonIds,
    String? customNote,
    String source = 'manual',
  }) async {
    return _runIndexMutation(() async {
      await _ensureIndexesReady();

      final now = DateTime.now();
      final box = await _getEntriesBox();
      final created = MoodEntry(
        moodId: moodId,
        reasonIds: reasonIds ?? const [],
        customNote: customNote,
        loggedAt: loggedAt,
        source: source,
        createdAt: now,
        updatedAt: now,
      );
      await box.put(created.id, created);
      await _addEntryToIndexes(created);
      return created;
    });
  }

  /// Updates an existing mood entry in place.
  Future<MoodEntry> updateMoodEntry({
    required String id,
    required DateTime loggedAt,
    required String moodId,
    List<String>? reasonIds,
    String? customNote,
    String source = 'manual',
  }) async {
    return _runIndexMutation(() async {
      await _ensureIndexesReady();

      final box = await _getEntriesBox();
      final existing = box.get(id);
      if (existing == null || existing.isDeleted) {
        throw StateError('Mood entry not found: $id');
      }

      await _removeEntryFromIndexes(existing);

      final now = DateTime.now();
      final updated = existing.copyWith(
        moodId: moodId,
        reasonIds: reasonIds ?? const [],
        customNote: customNote,
        loggedAt: loggedAt,
        source: source,
        updatedAt: now,
        deletedAt: null,
      );
      await box.put(id, updated);
      await _addEntryToIndexes(updated);
      return updated;
    });
  }

  Future<MoodEntry?> getMoodEntryById(String entryId) async {
    return (await _getEntriesBox()).get(entryId);
  }

  /// Returns the most recent entry for the date (for backward compat).
  Future<MoodEntry?> getMoodEntryForDate(
    DateTime date, {
    bool includeDeleted = false,
  }) async {
    final entries = await getMoodEntriesForDate(date, includeDeleted: includeDeleted);
    return entries.isEmpty ? null : entries.last;
  }

  /// Returns all entries for a date, sorted by [loggedAt] ascending.
  Future<List<MoodEntry>> getMoodEntriesForDate(
    DateTime date, {
    bool includeDeleted = false,
  }) async {
    await _ensureIndexesReady();
    final day = _dateOnly(date);
    final dayKey = _dateKey(day);
    final entriesBox = await _getEntriesBox();

    if (!includeDeleted &&
        !_indexMutationInProgress &&
        _useIndexedReads &&
        _isDateWithinIndexedRange(day)) {
      final ids = _getIndexedEntryIds(await _getDateIndexBox(), dayKey);
      final out = <MoodEntry>[];
      for (final id in ids) {
        final entry = entriesBox.get(id);
        if (entry != null &&
            !entry.isDeleted &&
            _isSameDate(entry.loggedAt, day)) {
          out.add(entry);
        }
      }
      out.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
      return out;
    }

    final out = <MoodEntry>[];
    for (final entry in entriesBox.values) {
      if (!_isSameDate(entry.loggedAt, day)) continue;
      if (!includeDeleted && entry.isDeleted) continue;
      out.add(entry);
    }
    out.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return out;
  }

  /// Normalizes index value to List<String> (backward compat: String -> [s]).
  List<String> _getIndexedEntryIds(Box<dynamic> indexBox, String dayKey) {
    final raw = indexBox.get(dayKey);
    if (raw == null) return [];
    if (raw is String) return raw.isEmpty ? [] : [raw];
    if (raw is List) return raw.cast<String>();
    return [];
  }

  Future<List<MoodEntry>> getMoodEntriesInRange(
    DateTime startDate,
    DateTime endDate, {
    bool includeDeleted = false,
  }) async {
    await _ensureIndexesReady();
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) return const <MoodEntry>[];

    if (includeDeleted || !_useIndexedReads || _indexMutationInProgress) {
      return _scanEntriesInRange(
        (await _getEntriesBox()).values,
        start,
        end,
        includeDeleted: includeDeleted,
      );
    }

    if (_isRangeFullyIndexed(start, end)) {
      return _readIndexedRange(start, end);
    }

    final entriesBox = await _getEntriesBox();
    final indexedFrom = _indexedFromDate;
    if (indexedFrom == null) {
      return _scanEntriesInRange(
        entriesBox.values,
        start,
        end,
        includeDeleted: false,
      );
    }

    final out = <MoodEntry>[];
    if (start.isBefore(indexedFrom)) {
      final olderEnd =
          end.isBefore(indexedFrom.subtract(const Duration(days: 1)))
          ? end
          : indexedFrom.subtract(const Duration(days: 1));
      out.addAll(
        _scanEntriesInRange(
          entriesBox.values,
          start,
          olderEnd,
          includeDeleted: false,
        ),
      );
    }

    if (!end.isBefore(indexedFrom)) {
      final indexedStart = start.isBefore(indexedFrom) ? indexedFrom : start;
      out.addAll(await _readIndexedRange(indexedStart, end));
    }

    out.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return out;
  }

  Future<bool> softDeleteMoodEntry(String entryId) async {
    return _runIndexMutation(() async {
      await _ensureIndexesReady();
      final box = await _getEntriesBox();
      final entry = box.get(entryId);
      if (entry == null || entry.isDeleted) return false;

      final deleted = entry.copyWith(
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await box.put(entryId, deleted);
      await _removeEntryFromIndexes(entry);
      return true;
    });
  }

  Future<List<MoodEntry>> getAllMoodEntries({
    bool includeDeleted = false,
  }) async {
    final list = (await _getEntriesBox()).values.where((entry) {
      if (!includeDeleted && entry.isDeleted) return false;
      return true;
    }).toList();
    list.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return list;
  }

  Future<void> deleteAllEntries() async {
    await _runIndexMutation(() async {
      await _ensureIndexesReady();
      await (await _getEntriesBox()).clear();
      await (await _getDateIndexBox()).clear();
      await (await _getDailySummaryBox()).clear();

      final meta = await _getMetaBox();
      final today = _dateOnly(DateTime.now());
      await meta.put('version', _indexVersion);
      await meta.put(_indexedFromMetaKey, _dateKey(today));
      await meta.put(_oldestDataMetaKey, _dateKey(today));
      await meta.put(_lastIndexedMetaKey, _dateKey(today));
      await meta.put(_backfillCompleteMetaKey, true);
      await meta.put(_backfillPausedMetaKey, false);
      await meta.delete(_rebuildNeededMetaKey);

      _indexedFromDate = today;
      _useIndexedReads = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Summary + indexing
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    await _ensureIndexesReady();
    final day = _dateOnly(date);
    if (_indexMutationInProgress ||
        !_useIndexedReads ||
        !_isDateWithinIndexedRange(day)) {
      final dayEntries = await getMoodEntriesForDate(day);
      return _buildAggregatedSummary(dayEntries, await _moodLookup());
    }
    return _readSummaryMap((await _getDailySummaryBox()).get(_dateKey(day)));
  }

  Future<Map<String, Map<String, dynamic>>> getDailySummaryMapInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final summaries = <String, Map<String, dynamic>>{};
    final entries = await getMoodEntriesInRange(startDate, endDate);
    final moodLookup = await _moodLookup();
    final byDay = <String, List<MoodEntry>>{};
    for (final entry in entries) {
      byDay.putIfAbsent(_dateKey(entry.loggedAt), () => []).add(entry);
    }
    for (final e in byDay.entries) {
      summaries[e.key] = _buildAggregatedSummary(e.value, moodLookup);
    }
    return summaries;
  }

  Future<void> setBackfillPaused(bool paused) async {
    await _ensureIndexesReady();
    await (await _getMetaBox()).put(_backfillPausedMetaKey, paused);
  }

  Future<ModuleHistoryOptimizationStatus> getHistoryOptimizationStatus() async {
    await _ensureIndexesReady();
    final meta = await _getMetaBox();
    return ModuleHistoryOptimizationStatus(
      moduleId: 'mbt_mood',
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

      final entries = await _scanChunkEntries(chunkStart, chunkEnd);
      final moodLookup = await _moodLookup();
      final entriesByDay = <String, List<MoodEntry>>{};
      for (final entry in entries) {
        final dateKey = _dateKey(entry.loggedAt);
        entriesByDay.putIfAbsent(dateKey, () => []).add(entry);
      }

      final chunkIndex = <String, List<String>>{};
      final chunkSummary = <String, Map<String, dynamic>>{};
      for (final e in entriesByDay.entries) {
        e.value.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
        chunkIndex[e.key] = e.value.map((x) => x.id).toList();
        chunkSummary[e.key] = _buildAggregatedSummary(e.value, moodLookup);
      }

      if (chunkIndex.isNotEmpty) {
        await (await _getDateIndexBox()).putAll(chunkIndex);
      }
      if (chunkSummary.isNotEmpty) {
        await (await _getDailySummaryBox()).putAll(chunkSummary);
      }

      final newIndexedFrom = chunkStart;
      final isComplete = !newIndexedFrom.isAfter(oldestData);
      await meta.put(_indexedFromMetaKey, _dateKey(newIndexedFrom));
      await meta.put(_lastIndexedMetaKey, _dateKey(newIndexedFrom));
      await meta.put(_backfillCompleteMetaKey, isComplete);
      _indexedFromDate = newIndexedFrom;
      return true;
    });
  }

  Future<void> _ensureIndexesReady() async {
    if (_indexesReady) return;

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

  Future<void> _bootstrapRecentWindowIndexes() async {
    final entriesBox = await _getEntriesBox();
    final indexBox = await _getDateIndexBox();
    final summaryBox = await _getDailySummaryBox();
    final meta = await _getMetaBox();
    await indexBox.clear();
    await summaryBox.clear();

    final now = DateTime.now();
    final today = _dateOnly(now);
    final bootstrapFrom = today.subtract(
      const Duration(days: _bootstrapWindowDays - 1),
    );
    final moodLookup = await _moodLookup();

    DateTime? oldestData;
    final entriesByDay = <String, List<MoodEntry>>{};

    var scanned = 0;
    for (final entry in entriesBox.values) {
      scanned++;
      if (scanned % _scanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      if (entry.isDeleted) continue;
      final day = _dateOnly(entry.loggedAt);
      if (oldestData == null || day.isBefore(oldestData)) {
        oldestData = day;
      }
      if (day.isBefore(bootstrapFrom)) continue;
      final dayKey = _dateKey(day);
      entriesByDay.putIfAbsent(dayKey, () => []).add(entry);
    }

    final indexMap = <String, List<String>>{};
    final summaryMap = <String, Map<String, dynamic>>{};
    for (final e in entriesByDay.entries) {
      e.value.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
      indexMap[e.key] = e.value.map((x) => x.id).toList();
      summaryMap[e.key] = _buildAggregatedSummary(e.value, moodLookup);
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
    final entriesBox = await _getEntriesBox();
    if (entriesBox.isEmpty) return true;

    final indexedFrom =
        _indexedFromDate ??
        _parseDateKey('${(await _getMetaBox()).get(_indexedFromMetaKey)}');
    if (indexedFrom == null) return false;

    final expectedByDay = <String, Set<String>>{};
    for (final entry in entriesBox.values) {
      if (entry.isDeleted) continue;
      final day = _dateOnly(entry.loggedAt);
      if (day.isBefore(indexedFrom)) continue;
      expectedByDay.putIfAbsent(_dateKey(day), () => {}).add(entry.id);
    }

    final indexBox = await _getDateIndexBox();
    for (final e in expectedByDay.entries) {
      final ids = _getIndexedEntryIds(indexBox, e.key);
      if (ids.length != e.value.length) return false;
      for (final id in ids) {
        if (!e.value.contains(id)) return false;
        final entry = entriesBox.get(id);
        if (entry == null || entry.isDeleted) return false;
        if (!_isSameDate(entry.loggedAt, _parseDateKey(e.key)!)) return false;
      }
    }

    final summaryBox = await _getDailySummaryBox();
    if (summaryBox.length != expectedByDay.length) return false;
    return true;
  }

  Future<void> _addEntryToIndexes(MoodEntry entry) async {
    if (entry.isDeleted) return;
    if (!_useIndexedReads || !_isDateWithinIndexedRange(entry.loggedAt)) {
      await _markBackfillNeededForDate(entry.loggedAt);
      return;
    }
    final dayKey = _dateKey(entry.loggedAt);
    final indexBox = await _getDateIndexBox();
    final ids = _getIndexedEntryIds(indexBox, dayKey);
    if (!ids.contains(entry.id)) {
      ids.add(entry.id);
      await indexBox.put(dayKey, ids);
    }
    final entries = await _getEntriesForDay(dayKey);
    await _writeAggregatedSummaryForDate(dayKey, entries);
  }

  Future<void> _removeEntryFromIndexes(MoodEntry entry) async {
    if (!_useIndexedReads || !_isDateWithinIndexedRange(entry.loggedAt)) {
      return;
    }
    final day = _dateOnly(entry.loggedAt);
    final dayKey = _dateKey(day);
    final indexBox = await _getDateIndexBox();
    final ids = _getIndexedEntryIds(indexBox, dayKey);
    ids.remove(entry.id);
    if (ids.isEmpty) {
      await indexBox.delete(dayKey);
      await (await _getDailySummaryBox()).delete(dayKey);
      return;
    }
    await indexBox.put(dayKey, ids);
    final entries = await _getEntriesForDay(dayKey);
    await _writeAggregatedSummaryForDate(dayKey, entries);
  }

  Future<List<MoodEntry>> _getEntriesForDay(String dayKey) async {
    final entriesBox = await _getEntriesBox();
    final indexBox = await _getDateIndexBox();
    final ids = _getIndexedEntryIds(indexBox, dayKey);
    final out = <MoodEntry>[];
    for (final id in ids) {
      final entry = entriesBox.get(id);
      if (entry != null && !entry.isDeleted) out.add(entry);
    }
    out.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return out;
  }

  Future<void> _writeAggregatedSummaryForDate(
    String dayKey,
    List<MoodEntry> entries,
  ) async {
    final summary = _buildAggregatedSummary(
      entries,
      await _moodLookup(),
    );
    await (await _getDailySummaryBox()).put(dayKey, summary);
  }

  Future<void> _rebuildSummaryForMood(String moodId) async {
    await _ensureIndexesReady();
    final indexBox = await _getDateIndexBox();
    final summaryBox = await _getDailySummaryBox();
    final moodLookup = await _moodLookup();
    for (final dateKey in indexBox.keys.map((k) => '$k')) {
      final entries = await _getEntriesForDay(dateKey);
      final hasMood = entries.any((e) => e.moodId == moodId);
      if (!hasMood) continue;
      await summaryBox.put(
        dateKey,
        _buildAggregatedSummary(entries, moodLookup),
      );
    }
  }

  Future<List<MoodEntry>> _readIndexedRange(
    DateTime start,
    DateTime end,
  ) async {
    final out = <MoodEntry>[];
    final indexBox = await _getDateIndexBox();
    final entriesBox = await _getEntriesBox();
    var day = _dateOnly(start);
    final endOnly = _dateOnly(end);
    while (!day.isAfter(endOnly)) {
      final dayKey = _dateKey(day);
      for (final id in _getIndexedEntryIds(indexBox, dayKey)) {
        final entry = entriesBox.get(id);
        if (entry != null &&
            !entry.isDeleted &&
            _isSameDate(entry.loggedAt, day)) {
          out.add(entry);
        }
      }
      day = day.add(const Duration(days: 1));
    }
    out.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return out;
  }

  List<MoodEntry> _scanEntriesInRange(
    Iterable<MoodEntry> entries,
    DateTime start,
    DateTime end, {
    required bool includeDeleted,
  }) {
    final out = <MoodEntry>[];
    for (final entry in entries) {
      if (!includeDeleted && entry.isDeleted) continue;
      final day = _dateOnly(entry.loggedAt);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      out.add(entry);
    }
    out.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return out;
  }

  Future<List<MoodEntry>> _scanChunkEntries(
    DateTime start,
    DateTime end,
  ) async {
    final entries = <MoodEntry>[];
    var scanned = 0;
    for (final entry in (await _getEntriesBox()).values) {
      scanned++;
      if (scanned % _scanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      if (entry.isDeleted) continue;
      final day = _dateOnly(entry.loggedAt);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      entries.add(entry);
    }
    return entries;
  }

  Future<void> _markBackfillNeededForDate(DateTime date) async {
    final meta = await _getMetaBox();
    final day = _dateOnly(date);
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

  Future<Map<String, Mood>> _moodLookup() async {
    final map = <String, Mood>{};
    for (final mood in (await _getMoodsBox()).values) {
      map[mood.id] = mood;
    }
    return map;
  }

  Map<String, dynamic> _buildAggregatedSummary(
    List<MoodEntry> entries,
    Map<String, Mood> moodLookup,
  ) {
    final valid = entries.where((e) => !e.isDeleted).toList();
    if (valid.isEmpty) return _emptySummary();

    var totalScore = 0;
    var positiveCount = 0;
    var negativeCount = 0;
    final moodFrequency = <String, int>{};
    final reasonIds = <String>{};

    for (final entry in valid) {
      final mood = moodLookup[entry.moodId];
      final polarity = mood?.polarity ?? '';
      final score = mood?.pointValue ?? 0;
      totalScore += score;
      if (polarity == MoodPolarity.good) positiveCount++;
      if (polarity == MoodPolarity.bad) negativeCount++;
      moodFrequency[entry.moodId] = (moodFrequency[entry.moodId] ?? 0) + 1;
      reasonIds.addAll(entry.reasonIds);
    }

    final avgScore = valid.isEmpty ? 0 : (totalScore / valid.length).round();
    final topMoodId = moodFrequency.entries.isEmpty
        ? null
        : moodFrequency.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;

    return <String, dynamic>{
      'entryCount': valid.length,
      'score': avgScore,
      'positiveCount': positiveCount,
      'negativeCount': negativeCount,
      'moodId': topMoodId ?? valid.first.moodId,
      'reasonIds': reasonIds.toList(),
      'reasonId': reasonIds.isEmpty ? '' : reasonIds.first,
    };
  }

  Map<String, dynamic> _emptySummary() {
    return <String, dynamic>{
      'entryCount': 0,
      'score': 0,
      'positiveCount': 0,
      'negativeCount': 0,
      'moodId': '',
      'reasonIds': <String>[],
      'reasonId': '',
    };
  }

  Map<String, dynamic> _readSummaryMap(dynamic value) {
    if (value is! Map) {
      return _emptySummary();
    }
    // Read new multi-reason list, falling back to legacy single reasonId.
    final rawIds = value['reasonIds'];
    final List<String> reasonIds;
    if (rawIds is List && rawIds.isNotEmpty) {
      reasonIds = rawIds.cast<String>();
    } else {
      final legacy = '${value['reasonId'] ?? ''}';
      reasonIds = legacy.isNotEmpty ? [legacy] : [];
    }
    return <String, dynamic>{
      'entryCount': _asInt(value['entryCount']),
      'score': _asInt(value['score']),
      'positiveCount': _asInt(value['positiveCount']),
      'negativeCount': _asInt(value['negativeCount']),
      'moodId': '${value['moodId'] ?? ''}',
      'reasonIds': reasonIds,
      'reasonId': reasonIds.isEmpty ? '' : reasonIds.first,
    };
  }

  bool _isDateWithinIndexedRange(DateTime date) {
    final indexedFrom = _indexedFromDate;
    if (!_useIndexedReads || indexedFrom == null) return false;
    return !_dateOnly(date).isBefore(_dateOnly(indexedFrom));
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

  bool _isSameDate(DateTime a, DateTime b) {
    final aOnly = _dateOnly(a);
    final bOnly = _dateOnly(b);
    return aOnly.year == bOnly.year &&
        aOnly.month == bOnly.month &&
        aOnly.day == bOnly.day;
  }

  String _dateKey(DateTime date) {
    final day = _dateOnly(date);
    final yyyy = day.year.toString().padLeft(4, '0');
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return '$yyyy$mm$dd';
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

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  void _validatePolarity(String value, {required String fieldName}) {
    if (!MoodPolarity.isValid(value)) {
      throw FormatException('Invalid $fieldName: $value');
    }
  }

  Future<void> _assertMoodNameUnique(
    String name, {
    String? excludeMoodId,
  }) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const FormatException('Mood name is required.');
    }
    for (final mood in (await _getMoodsBox()).values) {
      if (excludeMoodId != null && mood.id == excludeMoodId) continue;
      if (mood.isDeleted) continue;
      if (mood.name.trim().toLowerCase() == normalized) {
        throw StateError('Mood name already exists: ${mood.name}');
      }
    }
  }

  Future<void> _assertReasonNameUnique(
    String name, {
    required String reasonType,
    String? excludeReasonId,
  }) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const FormatException('Reason name is required.');
    }
    for (final reason in (await _getReasonsBox()).values) {
      if (excludeReasonId != null && reason.id == excludeReasonId) continue;
      if (reason.isDeleted) continue;
      if (reason.type != reasonType) continue;
      if (reason.name.trim().toLowerCase() == normalized) {
        throw StateError('Reason name already exists: ${reason.name}');
      }
    }
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
    debugPrint('[MoodRepository] $message');
  }
}
