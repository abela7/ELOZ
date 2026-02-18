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
/// - Daily mood entry CRUD with one-primary-entry-per-day enforcement
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

  /// Upserts the one primary mood entry for a date.
  ///
  /// If an active entry already exists on that day, it is updated in place.
  Future<MoodEntry> upsertMoodEntryForDate({
    required DateTime loggedAt,
    required String moodId,
    List<String>? reasonIds,
    String? customNote,
    String source = 'manual',
  }) async {
    return _runIndexMutation(() async {
      await _ensureIndexesReady();

      final existing = await getMoodEntryForDate(loggedAt);
      final now = DateTime.now();
      final box = await _getEntriesBox();

      if (existing == null) {
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
      }

      final updated = existing.copyWith(
        moodId: moodId,
        reasonIds: reasonIds ?? const [],
        customNote: customNote,
        loggedAt: loggedAt,
        source: source,
        updatedAt: now,
        deletedAt: null,
      );
      await _removeEntryFromIndexes(existing);
      await box.put(updated.id, updated);
      await _addEntryToIndexes(updated);
      return updated;
    });
  }

  Future<MoodEntry?> getMoodEntryById(String entryId) async {
    return (await _getEntriesBox()).get(entryId);
  }

  Future<MoodEntry?> getMoodEntryForDate(
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
      final indexedId = (await _getDateIndexBox()).get(dayKey);
      if (indexedId is! String || indexedId.isEmpty) {
        return null;
      }
      final indexedEntry = entriesBox.get(indexedId);
      if (indexedEntry == null) return null;
      if (!_isSameDate(indexedEntry.loggedAt, day)) return null;
      if (indexedEntry.isDeleted) return null;
      return indexedEntry;
    }

    MoodEntry? winner;
    for (final entry in entriesBox.values) {
      if (!_isSameDate(entry.loggedAt, day)) continue;
      if (!includeDeleted && entry.isDeleted) continue;
      if (winner == null || _isPreferredEntry(entry, winner)) {
        winner = entry;
      }
    }
    return winner;
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
      final entry = await getMoodEntryForDate(day);
      return _buildSummaryForEntry(
        entry: entry,
        moodLookup: await _moodLookup(),
      );
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
    for (final entry in entries) {
      summaries[_dateKey(entry.loggedAt)] = _buildSummaryForEntry(
        entry: entry,
        moodLookup: moodLookup,
      );
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
      final chunkWinners = <String, MoodEntry>{};
      for (final entry in entries) {
        final dateKey = _dateKey(entry.loggedAt);
        final current = chunkWinners[dateKey];
        if (current == null || _isPreferredEntry(entry, current)) {
          chunkWinners[dateKey] = entry;
        }
      }

      final chunkIndex = <String, String>{};
      final chunkSummary = <String, Map<String, dynamic>>{};
      for (final winner in chunkWinners.values) {
        final dateKey = _dateKey(winner.loggedAt);
        chunkIndex[dateKey] = winner.id;
        chunkSummary[dateKey] = _buildSummaryForEntry(
          entry: winner,
          moodLookup: moodLookup,
        );
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
    await _dedupeActiveEntriesByDate();

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
    final winnersByDay = <String, MoodEntry>{};

    var scanned = 0;
    for (final entry in entriesBox.values) {
      scanned++;
      if (scanned % _scanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      if (entry.isDeleted) {
        continue;
      }
      final day = _dateOnly(entry.loggedAt);
      if (oldestData == null || day.isBefore(oldestData)) {
        oldestData = day;
      }
      if (day.isBefore(bootstrapFrom)) {
        continue;
      }
      final dayKey = _dateKey(day);
      final current = winnersByDay[dayKey];
      if (current == null || _isPreferredEntry(entry, current)) {
        winnersByDay[dayKey] = entry;
      }
    }

    final indexMap = <String, String>{};
    final summaryMap = <String, Map<String, dynamic>>{};
    for (final entry in winnersByDay.values) {
      final dayKey = _dateKey(entry.loggedAt);
      indexMap[dayKey] = entry.id;
      summaryMap[dayKey] = _buildSummaryForEntry(
        entry: entry,
        moodLookup: moodLookup,
      );
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

  Future<void> _dedupeActiveEntriesByDate() async {
    final box = await _getEntriesBox();
    final winnerByDate = <String, MoodEntry>{};
    final toSoftDelete = <MoodEntry>[];
    for (final entry in box.values) {
      if (entry.isDeleted) continue;
      final dateKey = _dateKey(entry.loggedAt);
      final current = winnerByDate[dateKey];
      if (current == null) {
        winnerByDate[dateKey] = entry;
        continue;
      }
      if (_isPreferredEntry(entry, current)) {
        toSoftDelete.add(current);
        winnerByDate[dateKey] = entry;
      } else {
        toSoftDelete.add(entry);
      }
    }

    if (toSoftDelete.isEmpty) return;
    final now = DateTime.now();
    for (final duplicate in toSoftDelete) {
      await box.put(
        duplicate.id,
        duplicate.copyWith(updatedAt: now, deletedAt: now),
      );
    }
  }

  Future<bool> _hasValidIndexes() async {
    final entriesBox = await _getEntriesBox();
    if (entriesBox.isEmpty) return true;

    final indexedFrom =
        _indexedFromDate ??
        _parseDateKey('${(await _getMetaBox()).get(_indexedFromMetaKey)}');
    if (indexedFrom == null) return false;

    final expected = <String, MoodEntry>{};
    for (final entry in entriesBox.values) {
      if (entry.isDeleted) continue;
      final day = _dateOnly(entry.loggedAt);
      if (day.isBefore(indexedFrom)) continue;
      final dateKey = _dateKey(day);
      final current = expected[dateKey];
      if (current == null || _isPreferredEntry(entry, current)) {
        expected[dateKey] = entry;
      }
    }

    final indexBox = await _getDateIndexBox();
    var indexedCount = 0;
    for (final value in indexBox.values) {
      if (value is String && value.isNotEmpty) {
        indexedCount++;
      }
    }
    if (indexedCount != expected.length) return false;

    for (final entry in expected.entries) {
      final indexedId = indexBox.get(entry.key);
      if (indexedId is! String || indexedId != entry.value.id) {
        return false;
      }
    }

    final summaryBox = await _getDailySummaryBox();
    if (summaryBox.length != expected.length) return false;
    return true;
  }

  Future<void> _addEntryToIndexes(MoodEntry entry) async {
    if (entry.isDeleted) return;
    if (!_useIndexedReads || !_isDateWithinIndexedRange(entry.loggedAt)) {
      await _markBackfillNeededForDate(entry.loggedAt);
      return;
    }
    final dayKey = _dateKey(entry.loggedAt);
    await (await _getDateIndexBox()).put(dayKey, entry.id);
    await _writeSummaryForDate(dayKey, entry);
  }

  Future<void> _removeEntryFromIndexes(MoodEntry entry) async {
    if (!_useIndexedReads || !_isDateWithinIndexedRange(entry.loggedAt)) {
      return;
    }
    final day = _dateOnly(entry.loggedAt);
    final dayKey = _dateKey(day);
    final nextWinner = await _findWinnerForDateExcluding(
      day,
      excludeId: entry.id,
    );
    final indexBox = await _getDateIndexBox();
    final summaryBox = await _getDailySummaryBox();
    if (nextWinner == null) {
      await indexBox.delete(dayKey);
      await summaryBox.delete(dayKey);
      return;
    }
    await indexBox.put(dayKey, nextWinner.id);
    final summary = _buildSummaryForEntry(
      entry: nextWinner,
      moodLookup: await _moodLookup(),
    );
    await summaryBox.put(dayKey, summary);
  }

  Future<void> _writeSummaryForDate(String dayKey, MoodEntry entry) async {
    final summary = _buildSummaryForEntry(
      entry: entry,
      moodLookup: await _moodLookup(),
    );
    await (await _getDailySummaryBox()).put(dayKey, summary);
  }

  Future<void> _rebuildSummaryForMood(String moodId) async {
    await _ensureIndexesReady();
    final indexBox = await _getDateIndexBox();
    final entriesBox = await _getEntriesBox();
    final summaryBox = await _getDailySummaryBox();
    final moodLookup = await _moodLookup();
    for (final dateKey in indexBox.keys.map((k) => '$k')) {
      final entryId = indexBox.get(dateKey);
      if (entryId is! String || entryId.isEmpty) continue;
      final entry = entriesBox.get(entryId);
      if (entry == null || entry.moodId != moodId) continue;
      await summaryBox.put(
        dateKey,
        _buildSummaryForEntry(entry: entry, moodLookup: moodLookup),
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
      final entryId = indexBox.get(dayKey);
      if (entryId is String && entryId.isNotEmpty) {
        final entry = entriesBox.get(entryId);
        if (entry != null &&
            !entry.isDeleted &&
            _isSameDate(entry.loggedAt, day)) {
          out.add(entry);
        }
      }
      day = day.add(const Duration(days: 1));
    }
    return out;
  }

  List<MoodEntry> _scanEntriesInRange(
    Iterable<MoodEntry> entries,
    DateTime start,
    DateTime end, {
    required bool includeDeleted,
  }) {
    final winners = <String, MoodEntry>{};
    for (final entry in entries) {
      if (!includeDeleted && entry.isDeleted) continue;
      final day = _dateOnly(entry.loggedAt);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      final dayKey = _dateKey(day);
      final current = winners[dayKey];
      if (current == null || _isPreferredEntry(entry, current)) {
        winners[dayKey] = entry;
      }
    }
    final out = winners.values.toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
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

  Future<MoodEntry?> _findWinnerForDateExcluding(
    DateTime day, {
    String? excludeId,
  }) async {
    MoodEntry? winner;
    for (final entry in (await _getEntriesBox()).values) {
      if (entry.isDeleted) continue;
      if (excludeId != null && entry.id == excludeId) continue;
      if (!_isSameDate(entry.loggedAt, day)) continue;
      if (winner == null || _isPreferredEntry(entry, winner)) {
        winner = entry;
      }
    }
    return winner;
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

  Map<String, dynamic> _buildSummaryForEntry({
    required MoodEntry? entry,
    required Map<String, Mood> moodLookup,
  }) {
    if (entry == null || entry.isDeleted) {
      return _emptySummary();
    }
    final mood = moodLookup[entry.moodId];
    final polarity = mood?.polarity ?? '';
    final score = mood?.pointValue ?? 0;
    return <String, dynamic>{
      'entryCount': 1,
      'score': score,
      'positiveCount': polarity == MoodPolarity.good ? 1 : 0,
      'negativeCount': polarity == MoodPolarity.bad ? 1 : 0,
      'moodId': entry.moodId,
      // Store multi-reason list; keep legacy 'reasonId' for old cache compat.
      'reasonIds': entry.reasonIds,
      'reasonId': entry.reasonId ?? '',
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

  bool _isPreferredEntry(MoodEntry candidate, MoodEntry current) {
    final candidateLogged = candidate.loggedAt.millisecondsSinceEpoch;
    final currentLogged = current.loggedAt.millisecondsSinceEpoch;
    if (candidateLogged != currentLogged) {
      return candidateLogged > currentLogged;
    }
    final candidateUpdated =
        (candidate.updatedAt ?? candidate.createdAt).millisecondsSinceEpoch;
    final currentUpdated =
        (current.updatedAt ?? current.createdAt).millisecondsSinceEpoch;
    if (candidateUpdated != currentUpdated) {
      return candidateUpdated > currentUpdated;
    }
    return candidate.id.compareTo(current.id) > 0;
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
