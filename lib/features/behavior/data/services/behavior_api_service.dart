import 'package:flutter/material.dart';

import '../models/behavior.dart';
import '../models/behavior_log.dart';
import '../models/behavior_log_reason.dart';
import '../models/behavior_reason.dart';
import '../models/behavior_type.dart';
import '../repositories/behavior_repository.dart';
import '../../notifications/behavior_notification_service.dart';

class BehaviorSummaryItem {
  const BehaviorSummaryItem({
    required this.behaviorId,
    required this.behaviorName,
    required this.type,
    required this.totalCount,
    required this.totalDurationMinutes,
    required this.averageIntensity,
  });

  final String behaviorId;
  final String behaviorName;
  final String type;
  final int totalCount;
  final int totalDurationMinutes;
  final double averageIntensity;
}

class BehaviorSummaryResponse {
  const BehaviorSummaryResponse({
    required this.from,
    required this.to,
    required this.items,
  });

  final DateTime from;
  final DateTime to;
  final List<BehaviorSummaryItem> items;
}

class BehaviorTopReasonItem {
  const BehaviorTopReasonItem({
    required this.reasonId,
    required this.reasonName,
    required this.type,
    required this.usageCount,
  });

  final String reasonId;
  final String reasonName;
  final String type;
  final int usageCount;
}

class BehaviorLogWithReasons {
  const BehaviorLogWithReasons({required this.log, required this.reasonIds});

  final BehaviorLog log;
  final List<String> reasonIds;
}

class BehaviorBackupRestoreResult {
  const BehaviorBackupRestoreResult({
    required this.behaviorsCreated,
    required this.behaviorsMerged,
    required this.reasonsCreated,
    required this.reasonsMerged,
    required this.logsCreated,
    required this.logsMatched,
    required this.reasonLinksAdded,
  });

  final int behaviorsCreated;
  final int behaviorsMerged;
  final int reasonsCreated;
  final int reasonsMerged;
  final int logsCreated;
  final int logsMatched;
  final int reasonLinksAdded;
}

/// Local API-style facade for Behavior Tracker.
///
/// Method names intentionally mirror endpoint semantics:
/// - Behaviors: post/put/delete/get
/// - Reasons: post/put/delete/get
/// - Logs: post/put/delete/get by date/range
/// - Analytics: summary + top reasons
class BehaviorApiService {
  BehaviorApiService({
    BehaviorRepository? repository,
    BehaviorNotificationService? notificationService,
  }) : _repository = repository ?? BehaviorRepository(),
       _notificationService =
           notificationService ?? BehaviorNotificationService();

  final BehaviorRepository _repository;
  final BehaviorNotificationService _notificationService;

  // ---------------------------------------------------------------------------
  // Behaviors (POST/PUT/DELETE/GET)
  // ---------------------------------------------------------------------------

  Future<Behavior> postBehavior({
    required String name,
    required String type,
    required int iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    required int colorValue,
    bool reasonRequired = false,
    bool isActive = true,
  }) async {
    final normalizedName = _normalizeSpaces(name);
    if (normalizedName.isEmpty) {
      throw const FormatException('Behavior name is required.');
    }
    _validateType(type, fieldName: 'behavior.type');
    return _repository.createBehavior(
      Behavior(
        name: normalizedName,
        type: type,
        iconCodePoint: iconCodePoint,
        iconFontFamily: iconFontFamily ?? 'MaterialIcons',
        iconFontPackage: iconFontPackage,
        colorValue: colorValue,
        reasonRequired: reasonRequired,
        isActive: isActive,
      ),
    );
  }

  Future<Behavior> putBehavior(
    String behaviorId, {
    String? name,
    String? type,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    bool? reasonRequired,
    bool? isActive,
  }) async {
    final existing = await _repository.getBehaviorById(behaviorId);
    if (existing == null) {
      throw StateError('Behavior not found: $behaviorId');
    }

    final nextType = type ?? existing.type;
    _validateType(nextType, fieldName: 'behavior.type');

    final nextName = name == null ? existing.name : _normalizeSpaces(name);
    if (nextName.isEmpty) {
      throw const FormatException('Behavior name is required.');
    }

    return _repository.updateBehavior(
      existing.copyWith(
        name: nextName,
        type: nextType,
        iconCodePoint: iconCodePoint ?? existing.iconCodePoint,
        iconFontFamily: iconFontFamily ?? existing.iconFontFamily,
        iconFontPackage: iconFontPackage ?? existing.iconFontPackage,
        colorValue: colorValue ?? existing.colorValue,
        reasonRequired: reasonRequired ?? existing.reasonRequired,
        isActive: isActive ?? existing.isActive,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteBehavior(String behaviorId) async {
    await _repository.softDeleteBehavior(behaviorId);
  }

  Future<List<Behavior>> getBehaviors({bool includeInactive = false}) async {
    return _repository.getBehaviors(
      includeInactive: includeInactive,
      includeDeleted: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Reasons (POST/PUT/DELETE/GET)
  // ---------------------------------------------------------------------------

  Future<BehaviorReason> postBehaviorReason({
    required String name,
    required String type,
    bool isActive = true,
  }) async {
    final normalizedName = _normalizeSpaces(name);
    if (normalizedName.isEmpty) {
      throw const FormatException('Reason name is required.');
    }
    _validateType(type, fieldName: 'reason.type');
    return _repository.createReason(
      BehaviorReason(name: normalizedName, type: type, isActive: isActive),
    );
  }

  Future<BehaviorReason> putBehaviorReason(
    String reasonId, {
    String? name,
    String? type,
    bool? isActive,
  }) async {
    final existing = await _repository.getReasonById(reasonId);
    if (existing == null) {
      throw StateError('Reason not found: $reasonId');
    }

    final nextType = type ?? existing.type;
    _validateType(nextType, fieldName: 'reason.type');
    final nextName = name == null ? existing.name : _normalizeSpaces(name);
    if (nextName.isEmpty) {
      throw const FormatException('Reason name is required.');
    }

    return _repository.updateReason(
      existing.copyWith(
        name: nextName,
        type: nextType,
        isActive: isActive ?? existing.isActive,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteBehaviorReason(String reasonId) async {
    await _repository.softDeleteReason(reasonId);
  }

  Future<List<BehaviorReason>> getBehaviorReasons({
    String? type,
    bool includeInactive = false,
  }) async {
    if (type != null) {
      _validateType(type, fieldName: 'reason.type');
    }
    return _repository.getReasons(
      type: type,
      includeInactive: includeInactive,
      includeDeleted: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Logging (POST/PUT/DELETE/GET)
  // ---------------------------------------------------------------------------

  Future<BehaviorLog> postBehaviorLog({
    required String behaviorId,
    required DateTime occurredAt,
    List<String> reasonIds = const <String>[],
    int? durationMinutes,
    int? intensity,
    String? note,
  }) async {
    return _repository.createBehaviorLog(
      behaviorId: behaviorId,
      occurredAt: occurredAt,
      reasonIds: reasonIds,
      durationMinutes: durationMinutes,
      intensity: intensity,
      note: note,
    );
  }

  Future<BehaviorLog> putBehaviorLog(
    String logId, {
    String? behaviorId,
    DateTime? occurredAt,
    Object? durationMinutes = _unset,
    Object? intensity = _unset,
    Object? note = _unset,
    List<String>? reasonIds,
  }) async {
    return _repository.updateBehaviorLog(
      logId,
      behaviorId: behaviorId,
      occurredAt: occurredAt,
      durationMinutes: durationMinutes,
      intensity: intensity,
      note: note,
      reasonIds: reasonIds,
    );
  }

  Future<bool> deleteBehaviorLog(String logId) async {
    return _repository.deleteBehaviorLog(logId);
  }

  Future<List<BehaviorLogWithReasons>> getBehaviorLogsByDateKey(
    String dateKey,
  ) async {
    final logs = await _repository.getBehaviorLogsByDateKey(dateKey);
    return _attachReasons(logs);
  }

  Future<List<BehaviorLogWithReasons>> getBehaviorLogsByDate(
    DateTime date,
  ) async {
    final dateKey = _dateKey(date);
    return getBehaviorLogsByDateKey(dateKey);
  }

  Future<List<BehaviorLogWithReasons>> getBehaviorLogsByRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final logs = await _repository.getBehaviorLogsInRange(from, to);
    return _attachReasons(logs);
  }

  // ---------------------------------------------------------------------------
  // Analytics (GET /behavior/summary + /behavior/top-reasons)
  // ---------------------------------------------------------------------------

  Future<BehaviorSummaryResponse> getBehaviorSummary({
    required DateTime from,
    required DateTime to,
    String? type,
  }) async {
    if (type != null) {
      _validateType(type, fieldName: 'behavior.type');
    }
    final fromDate = _dateOnly(from);
    final toDate = _dateOnly(to);
    if (toDate.isBefore(fromDate)) {
      throw const FormatException('Range end cannot be before range start.');
    }

    final behaviors = await _repository.getBehaviors(
      includeInactive: true,
      includeDeleted: true,
    );
    final filteredBehaviors = type == null
        ? behaviors
        : behaviors.where((b) => b.type == type).toList();
    final behaviorIds = filteredBehaviors.map((b) => b.id).toList();
    final summaryMap = await _repository.getDailySummaryMapInRange(
      fromDate,
      toDate,
      behaviorIds: behaviorIds,
    );

    final totalsByBehavior = <String, _BehaviorSummaryAccumulator>{};
    for (final summary in summaryMap.values) {
      final behaviorId = '${summary['behaviorId'] ?? ''}';
      if (behaviorId.isEmpty) continue;
      final acc = totalsByBehavior.putIfAbsent(
        behaviorId,
        () => _BehaviorSummaryAccumulator(),
      );
      acc.totalCount += _asInt(summary['totalCount']);
      acc.totalDuration += _asInt(summary['totalDurationMinutes']);
      acc.intensitySum += _asInt(summary['intensitySum']);
      acc.intensityCount += _asInt(summary['intensityCount']);
    }

    final behaviorLookup = <String, Behavior>{
      for (final behavior in behaviors) behavior.id: behavior,
    };

    final items = <BehaviorSummaryItem>[];
    for (final entry in totalsByBehavior.entries) {
      final behavior = behaviorLookup[entry.key];
      if (behavior == null) continue;
      final acc = entry.value;
      items.add(
        BehaviorSummaryItem(
          behaviorId: behavior.id,
          behaviorName: behavior.name,
          type: behavior.type,
          totalCount: acc.totalCount,
          totalDurationMinutes: acc.totalDuration,
          averageIntensity: acc.intensityCount == 0
              ? 0
              : acc.intensitySum / acc.intensityCount,
        ),
      );
    }

    items.sort((a, b) {
      final countCompare = b.totalCount.compareTo(a.totalCount);
      if (countCompare != 0) return countCompare;
      return a.behaviorName.toLowerCase().compareTo(
        b.behaviorName.toLowerCase(),
      );
    });

    return BehaviorSummaryResponse(from: fromDate, to: toDate, items: items);
  }

  Future<List<BehaviorTopReasonItem>> getBehaviorTopReasons({
    required DateTime from,
    required DateTime to,
    String? type,
  }) async {
    if (type != null) {
      _validateType(type, fieldName: 'reason.type');
    }
    final fromDate = _dateOnly(from);
    final toDate = _dateOnly(to);
    if (toDate.isBefore(fromDate)) {
      throw const FormatException('Range end cannot be before range start.');
    }

    final logs = await _repository.getBehaviorLogsInRange(fromDate, toDate);
    if (logs.isEmpty) {
      return const <BehaviorTopReasonItem>[];
    }

    final reasonById = <String, BehaviorReason>{
      for (final reason in await _repository.getReasons(
        includeInactive: true,
        includeDeleted: true,
      ))
        reason.id: reason,
    };
    final reasonIdsByLog = await _repository.getReasonIdsByLogIds(
      logs.map((log) => log.id),
    );

    final counts = <String, int>{};
    for (final log in logs) {
      final reasonIds = reasonIdsByLog[log.id] ?? const <String>[];
      for (final reasonId in reasonIds) {
        final reason = reasonById[reasonId];
        if (reason == null) continue;
        if (type != null && reason.type != type) continue;
        counts[reasonId] = (counts[reasonId] ?? 0) + 1;
      }
    }

    final out = <BehaviorTopReasonItem>[];
    for (final entry in counts.entries) {
      final reason = reasonById[entry.key];
      if (reason == null) continue;
      out.add(
        BehaviorTopReasonItem(
          reasonId: reason.id,
          reasonName: reason.name,
          type: reason.type,
          usageCount: entry.value,
        ),
      );
    }

    out.sort((a, b) {
      final countCompare = b.usageCount.compareTo(a.usageCount);
      if (countCompare != 0) return countCompare;
      return a.reasonName.toLowerCase().compareTo(b.reasonName.toLowerCase());
    });
    return out;
  }

  // ---------------------------------------------------------------------------
  // Notification settings passthrough
  // ---------------------------------------------------------------------------

  Future<BehaviorReminderSettings> loadReminderSettings() async {
    return _notificationService.loadSettings();
  }

  Future<void> setDailyReminder({
    required bool enabled,
    required TimeOfDay time,
    Set<int>? daysOfWeek,
    bool triggerResync = true,
  }) async {
    await _notificationService.setDailyReminder(
      enabled: enabled,
      time: time,
      daysOfWeek: daysOfWeek,
      triggerResync: triggerResync,
    );
  }

  // ---------------------------------------------------------------------------
  // Backup / restore merge support
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> exportBackupPayload() async {
    final behaviors = await _repository.getAllBehaviors();
    final reasons = await _repository.getAllReasons();
    final logs = await _repository.getAllLogs();
    final links = await _repository.getAllLogReasons();
    final summaries = await _repository.getAllDailySummaryEntries();

    return <String, dynamic>{
      'version': 1,
      'behaviors': behaviors.map(_behaviorToJson).toList(),
      'reasons': reasons.map(_reasonToJson).toList(),
      'behavior_logs': logs.map(_logToJson).toList(),
      'behavior_log_reasons': links.map(_logReasonToJson).toList(),
      'behavior_daily_summary': summaries,
    };
  }

  Future<BehaviorBackupRestoreResult> restoreFromBackupPayload(
    Map<String, dynamic> payload,
  ) async {
    final behaviorsRaw = _asMapList(payload['behaviors']);
    final reasonsRaw = _asMapList(payload['reasons']);
    final logsRaw = _asMapList(payload['behavior_logs']);
    final linksRaw = _asMapList(payload['behavior_log_reasons']);

    var behaviorsCreated = 0;
    var behaviorsMerged = 0;
    var reasonsCreated = 0;
    var reasonsMerged = 0;
    var logsCreated = 0;
    var logsMatched = 0;
    var reasonLinksAdded = 0;

    final existingBehaviors = await _repository.getAllBehaviors();
    final behaviorKeyMap = <String, Behavior>{
      for (final behavior in existingBehaviors)
        _behaviorRestoreKey(behavior.name, behavior.type): behavior,
    };
    final behaviorIdMap = <String, String>{};

    for (final row in behaviorsRaw) {
      final incoming = _behaviorFromJson(row);
      final key = _behaviorRestoreKey(incoming.name, incoming.type);
      final existing = behaviorKeyMap[key];
      if (existing == null) {
        final inserted = _withNonConflictingBehaviorId(
          incoming,
          existingBehaviors,
        );
        await _repository.putBehavior(inserted);
        existingBehaviors.add(inserted);
        behaviorKeyMap[key] = inserted;
        behaviorIdMap[incoming.id] = inserted.id;
        behaviorsCreated++;
      } else {
        final merged = _mergeBehavior(existing, incoming);
        await _repository.putBehavior(merged);
        behaviorIdMap[incoming.id] = existing.id;
        behaviorKeyMap[key] = merged;
        behaviorsMerged++;
      }
    }

    final existingReasons = await _repository.getAllReasons();
    final reasonKeyMap = <String, BehaviorReason>{
      for (final reason in existingReasons)
        _reasonRestoreKey(reason.name, reason.type): reason,
    };
    final reasonIdMap = <String, String>{};

    for (final row in reasonsRaw) {
      final incoming = _reasonFromJson(row);
      final key = _reasonRestoreKey(incoming.name, incoming.type);
      final existing = reasonKeyMap[key];
      if (existing == null) {
        final inserted = _withNonConflictingReasonId(incoming, existingReasons);
        await _repository.putReason(inserted);
        existingReasons.add(inserted);
        reasonKeyMap[key] = inserted;
        reasonIdMap[incoming.id] = inserted.id;
        reasonsCreated++;
      } else {
        final merged = _mergeReason(existing, incoming);
        await _repository.putReason(merged);
        reasonIdMap[incoming.id] = existing.id;
        reasonKeyMap[key] = merged;
        reasonsMerged++;
      }
    }

    final existingLogs = await _repository.getAllLogs();
    final logFingerprints = <String, BehaviorLog>{
      for (final log in existingLogs) _logFingerprint(log): log,
    };
    final existingLogIds = existingLogs.map((log) => log.id).toSet();
    final logIdMap = <String, String>{};

    for (final row in logsRaw) {
      final incoming = _logFromJson(row);
      final mappedBehaviorId =
          behaviorIdMap[incoming.behaviorId] ?? incoming.behaviorId;
      if (await _repository.getBehaviorById(mappedBehaviorId) == null) {
        continue;
      }

      final normalizedLog = incoming.copyWith(
        behaviorId: mappedBehaviorId,
        dateKey: incoming.dateKey,
      );
      final fingerprint = _logFingerprint(normalizedLog);
      final existing = logFingerprints[fingerprint];
      if (existing != null) {
        logIdMap[incoming.id] = existing.id;
        logsMatched++;
        continue;
      }

      final inserted = _withNonConflictingLogId(normalizedLog, existingLogIds);
      await _repository.putLog(inserted);
      existingLogIds.add(inserted.id);
      existingLogs.add(inserted);
      logFingerprints[fingerprint] = inserted;
      logIdMap[incoming.id] = inserted.id;
      logsCreated++;
    }

    final pendingReasonAdds = <String, Set<String>>{};
    for (final row in linksRaw) {
      final incoming = _logReasonFromJson(row);
      final mappedLogId =
          logIdMap[incoming.behaviorLogId] ?? incoming.behaviorLogId;
      final mappedReasonId =
          reasonIdMap[incoming.reasonId] ?? incoming.reasonId;
      if (await _repository.getBehaviorLogById(mappedLogId) == null) continue;
      if (await _repository.getReasonById(mappedReasonId) == null) continue;
      pendingReasonAdds
          .putIfAbsent(mappedLogId, () => <String>{})
          .add(mappedReasonId);
    }

    for (final entry in pendingReasonAdds.entries) {
      final existing = await _repository.getReasonIdsForLog(entry.key);
      final merged = <String>{...existing, ...entry.value};
      reasonLinksAdded += merged.length - existing.length;
      await _repository.replaceReasonAssignments(entry.key, merged.toList());
    }

    await _repository.rebuildIndexesFromScratch();
    var safety = 0;
    while (safety < 2048) {
      final progressed = await _repository.backfillNextChunk(chunkDays: 90);
      if (!progressed) break;
      safety++;
    }

    return BehaviorBackupRestoreResult(
      behaviorsCreated: behaviorsCreated,
      behaviorsMerged: behaviorsMerged,
      reasonsCreated: reasonsCreated,
      reasonsMerged: reasonsMerged,
      logsCreated: logsCreated,
      logsMatched: logsMatched,
      reasonLinksAdded: reasonLinksAdded,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<List<BehaviorLogWithReasons>> _attachReasons(
    List<BehaviorLog> logs,
  ) async {
    if (logs.isEmpty) return const <BehaviorLogWithReasons>[];
    final reasonMap = await _repository.getReasonIdsByLogIds(
      logs.map((log) => log.id),
    );
    return logs
        .map(
          (log) => BehaviorLogWithReasons(
            log: log,
            reasonIds: reasonMap[log.id] ?? const <String>[],
          ),
        )
        .toList();
  }

  Behavior _withNonConflictingBehaviorId(
    Behavior incoming,
    List<Behavior> existing,
  ) {
    if (existing.every((item) => item.id != incoming.id)) {
      return incoming;
    }
    return Behavior(
      name: incoming.name,
      type: incoming.type,
      iconCodePoint: incoming.iconCodePoint,
      iconFontFamily: incoming.iconFontFamily,
      iconFontPackage: incoming.iconFontPackage,
      colorValue: incoming.colorValue,
      reasonRequired: incoming.reasonRequired,
      isActive: incoming.isActive,
      createdAt: incoming.createdAt,
      updatedAt: incoming.updatedAt,
      deletedAt: incoming.deletedAt,
    );
  }

  BehaviorReason _withNonConflictingReasonId(
    BehaviorReason incoming,
    List<BehaviorReason> existing,
  ) {
    if (existing.every((item) => item.id != incoming.id)) {
      return incoming;
    }
    return BehaviorReason(
      name: incoming.name,
      type: incoming.type,
      isActive: incoming.isActive,
      createdAt: incoming.createdAt,
      updatedAt: incoming.updatedAt,
      deletedAt: incoming.deletedAt,
    );
  }

  BehaviorLog _withNonConflictingLogId(
    BehaviorLog incoming,
    Set<String> existingIds,
  ) {
    if (!existingIds.contains(incoming.id)) {
      return incoming;
    }
    return BehaviorLog(
      behaviorId: incoming.behaviorId,
      occurredAt: incoming.occurredAt,
      dateKey: incoming.dateKey,
      durationMinutes: incoming.durationMinutes,
      intensity: incoming.intensity,
      note: incoming.note,
      createdAt: incoming.createdAt,
      updatedAt: incoming.updatedAt,
    );
  }

  Behavior _mergeBehavior(Behavior existing, Behavior incoming) {
    final incomingNewer = _isIncomingNewer(
      incomingUpdatedAt: incoming.updatedAt,
      incomingCreatedAt: incoming.createdAt,
      existingUpdatedAt: existing.updatedAt,
      existingCreatedAt: existing.createdAt,
    );
    final base = incomingNewer ? incoming : existing;
    final shouldRemainDeleted =
        existing.deletedAt != null || incoming.deletedAt != null;
    final deletedAt = shouldRemainDeleted
        ? _earliestNonNull(existing.deletedAt, incoming.deletedAt) ??
              DateTime.now()
        : null;

    return base.copyWith(
      id: existing.id,
      createdAt: existing.createdAt,
      isActive: deletedAt == null ? base.isActive : false,
      deletedAt: deletedAt,
      updatedAt: DateTime.now(),
    );
  }

  BehaviorReason _mergeReason(
    BehaviorReason existing,
    BehaviorReason incoming,
  ) {
    final incomingNewer = _isIncomingNewer(
      incomingUpdatedAt: incoming.updatedAt,
      incomingCreatedAt: incoming.createdAt,
      existingUpdatedAt: existing.updatedAt,
      existingCreatedAt: existing.createdAt,
    );
    final base = incomingNewer ? incoming : existing;
    final shouldRemainDeleted =
        existing.deletedAt != null || incoming.deletedAt != null;
    final deletedAt = shouldRemainDeleted
        ? _earliestNonNull(existing.deletedAt, incoming.deletedAt) ??
              DateTime.now()
        : null;

    return base.copyWith(
      id: existing.id,
      createdAt: existing.createdAt,
      isActive: deletedAt == null ? base.isActive : false,
      deletedAt: deletedAt,
      updatedAt: DateTime.now(),
    );
  }

  bool _isIncomingNewer({
    required DateTime? incomingUpdatedAt,
    required DateTime incomingCreatedAt,
    required DateTime? existingUpdatedAt,
    required DateTime existingCreatedAt,
  }) {
    final incomingTime = incomingUpdatedAt ?? incomingCreatedAt;
    final existingTime = existingUpdatedAt ?? existingCreatedAt;
    return incomingTime.isAfter(existingTime);
  }

  DateTime? _earliestNonNull(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  String _behaviorRestoreKey(String name, String type) {
    return '${_normalizeForRestore(name)}|$type';
  }

  String _reasonRestoreKey(String name, String type) {
    return '${_normalizeForRestore(name)}|$type';
  }

  String _normalizeForRestore(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _logFingerprint(BehaviorLog log) {
    final note = (log.note ?? '').trim();
    return [
      log.behaviorId,
      log.occurredAt.toUtc().toIso8601String(),
      log.dateKey,
      '${log.durationMinutes ?? ''}',
      '${log.intensity ?? ''}',
      note.toLowerCase(),
    ].join('|');
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

  String _normalizeSpaces(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _validateType(String type, {required String fieldName}) {
    if (!BehaviorType.isValid(type)) {
      throw FormatException('Invalid $fieldName: $type');
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  DateTime _asDateTime(dynamic value, {DateTime? fallback}) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback ?? DateTime.now();
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return fallback;
  }

  Behavior _behaviorFromJson(Map<String, dynamic> map) {
    final createdAt = _asDateTime(map['created_at']);
    final updatedAt = map['updated_at'] == null
        ? null
        : _asDateTime(map['updated_at']);
    final deletedAt = map['deleted_at'] == null
        ? null
        : _asDateTime(map['deleted_at']);
    return Behavior(
      id: '${map['id'] ?? ''}'.trim().isEmpty ? null : '${map['id']}',
      name: _normalizeSpaces('${map['name'] ?? ''}'),
      type: '${map['type'] ?? BehaviorType.good}',
      iconCodePoint: _asInt(map['icon_code_point']),
      iconFontFamily: map['icon_font_family'] as String? ?? 'MaterialIcons',
      iconFontPackage: map['icon_font_package'] as String?,
      colorValue: _asInt(map['color_value']),
      reasonRequired: _asBool(map['reason_required']),
      isActive: _asBool(map['is_active'], fallback: true),
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  BehaviorReason _reasonFromJson(Map<String, dynamic> map) {
    final createdAt = _asDateTime(map['created_at']);
    final updatedAt = map['updated_at'] == null
        ? null
        : _asDateTime(map['updated_at']);
    final deletedAt = map['deleted_at'] == null
        ? null
        : _asDateTime(map['deleted_at']);
    return BehaviorReason(
      id: '${map['id'] ?? ''}'.trim().isEmpty ? null : '${map['id']}',
      name: _normalizeSpaces('${map['name'] ?? ''}'),
      type: '${map['type'] ?? BehaviorType.good}',
      isActive: _asBool(map['is_active'], fallback: true),
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  BehaviorLog _logFromJson(Map<String, dynamic> map) {
    final occurredAt = _asDateTime(map['occurred_at']);
    final rawDateKey = '${map['date_key'] ?? ''}'.trim();
    final dateKey = rawDateKey.isEmpty ? _dateKey(occurredAt) : rawDateKey;
    return BehaviorLog(
      id: '${map['id'] ?? ''}'.trim().isEmpty ? null : '${map['id']}',
      behaviorId: '${map['behavior_id'] ?? ''}',
      occurredAt: occurredAt,
      dateKey: dateKey,
      durationMinutes: map['duration_minutes'] == null
          ? null
          : _asInt(map['duration_minutes']),
      intensity: map['intensity'] == null ? null : _asInt(map['intensity']),
      note: map['note'] as String?,
      createdAt: _asDateTime(map['created_at']),
      updatedAt: map['updated_at'] == null
          ? null
          : _asDateTime(map['updated_at']),
    );
  }

  BehaviorLogReason _logReasonFromJson(Map<String, dynamic> map) {
    return BehaviorLogReason(
      id: '${map['id'] ?? ''}'.trim().isEmpty ? null : '${map['id']}',
      behaviorLogId: '${map['behavior_log_id'] ?? ''}',
      reasonId: '${map['reason_id'] ?? ''}',
      createdAt: _asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> _behaviorToJson(Behavior item) {
    return <String, dynamic>{
      'id': item.id,
      'name': item.name,
      'type': item.type,
      'icon_code_point': item.iconCodePoint,
      'icon_font_family': item.iconFontFamily,
      'icon_font_package': item.iconFontPackage,
      'color_value': item.colorValue,
      'reason_required': item.reasonRequired,
      'is_active': item.isActive,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt?.toIso8601String(),
      'deleted_at': item.deletedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> _reasonToJson(BehaviorReason item) {
    return <String, dynamic>{
      'id': item.id,
      'name': item.name,
      'type': item.type,
      'is_active': item.isActive,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt?.toIso8601String(),
      'deleted_at': item.deletedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> _logToJson(BehaviorLog item) {
    return <String, dynamic>{
      'id': item.id,
      'behavior_id': item.behaviorId,
      'occurred_at': item.occurredAt.toIso8601String(),
      'date_key': item.dateKey,
      'duration_minutes': item.durationMinutes,
      'intensity': item.intensity,
      'note': item.note,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> _logReasonToJson(BehaviorLogReason item) {
    return <String, dynamic>{
      'id': item.id,
      'behavior_log_id': item.behaviorLogId,
      'reason_id': item.reasonId,
      'created_at': item.createdAt.toIso8601String(),
    };
  }
}

class _BehaviorSummaryAccumulator {
  int totalCount = 0;
  int totalDuration = 0;
  int intensitySum = 0;
  int intensityCount = 0;
}

const Object _unset = Object();
