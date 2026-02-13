import 'package:hive_flutter/hive_flutter.dart';
import '../models/temptation_log.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../services/quit_habit_secure_storage_service.dart';

/// Repository for temptation log CRUD operations using Hive
class TemptationLogRepository {
  static const String legacyBoxName = 'temptationLogsBox';
  static const String boxName =
      QuitHabitSecureStorageService.secureTemptationsBoxName;

  /// Cached box reference for performance
  Box<TemptationLog>? _cachedBox;
  final QuitHabitSecureStorageService _secureStorage;

  TemptationLogRepository({QuitHabitSecureStorageService? secureStorage})
    : _secureStorage = secureStorage ?? QuitHabitSecureStorageService();

  Future<Box<TemptationLog>?> _getBoxOrNull() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    if (!_secureStorage.isSessionUnlocked) {
      return null;
    }
    _cachedBox = await _secureStorage.openSecureBox<TemptationLog>(boxName);
    return _cachedBox!;
  }

  /// Get the temptation logs box (lazy initialization with caching)
  Future<Box<TemptationLog>> _getBox() async {
    final box = await _getBoxOrNull();
    if (box == null) {
      throw StateError('Quit secure storage is locked.');
    }
    return box;
  }

  /// Get the legacy (pre-secure) temptation logs box.
  /// Used only for migration/reset paths.
  Future<Box<TemptationLog>> getLegacyBox() async {
    return HiveService.getBox<TemptationLog>(legacyBoxName);
  }

  /// Create a new temptation log
  Future<void> createLog(TemptationLog log) async {
    final box = await _getBox();
    await box.put(log.id, log);
  }

  /// Get all temptation logs
  Future<List<TemptationLog>> getAllLogs() async {
    final box = await _getBoxOrNull();
    if (box == null) return const <TemptationLog>[];
    return box.values.toList()..sort(
      (a, b) => b.occurredAt.compareTo(a.occurredAt),
    ); // Most recent first
  }

  /// Get temptation logs for a specific habit
  Future<List<TemptationLog>> getLogsForHabit(
    String habitId, {
    bool sortDescending = true,
  }) async {
    final box = await _getBoxOrNull();
    if (box == null) return const <TemptationLog>[];
    final logs = box.values.where((log) => log.habitId == habitId).toList();
    if (sortDescending) {
      logs.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    }
    return logs;
  }

  /// Get temptation logs for a habit on a specific date
  Future<List<TemptationLog>> getLogsForHabitOnDate(
    String habitId,
    DateTime date, {
    bool sortDescending = true,
  }) async {
    final box = await _getBoxOrNull();
    if (box == null) return const <TemptationLog>[];
    final dateOnly = DateTime(date.year, date.month, date.day);
    final logs = box.values.where((log) {
      final logDate = DateTime(
        log.occurredAt.year,
        log.occurredAt.month,
        log.occurredAt.day,
      );
      return log.habitId == habitId && logDate == dateOnly;
    }).toList();
    if (sortDescending) {
      logs.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    }
    return logs;
  }

  /// Get temptation logs for a habit in a date range
  Future<List<TemptationLog>> getLogsForHabitInRange(
    String habitId,
    DateTime start,
    DateTime end,
    {bool sortDescending = true}
  ) async {
    final box = await _getBoxOrNull();
    if (box == null) return const <TemptationLog>[];
    final logs = box.values.where((log) {
      return log.habitId == habitId &&
          log.occurredAt.isAfter(start.subtract(const Duration(days: 1))) &&
          log.occurredAt.isBefore(end.add(const Duration(days: 1)));
    }).toList();
    if (sortDescending) {
      logs.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    }
    return logs;
  }

  /// Get total temptation count for a habit
  Future<int> getTotalCountForHabit(String habitId) async {
    final logs = await getLogsForHabit(habitId, sortDescending: false);
    return logs.fold<int>(0, (sum, log) => sum + log.count);
  }

  /// Get temptation count for today
  Future<int> getTodayCountForHabit(String habitId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logs = await getLogsForHabitOnDate(
      habitId,
      today,
      sortDescending: false,
    );
    return logs.fold<int>(0, (sum, log) => sum + log.count);
  }

  /// Get most common temptation reasons for a habit
  Future<Map<String, int>> getReasonStats(String habitId) async {
    final logs = await getLogsForHabit(habitId, sortDescending: false);
    final reasonCounts = <String, int>{};
    for (final log in logs) {
      final reason = log.reasonText ?? 'Unknown';
      reasonCounts[reason] = (reasonCounts[reason] ?? 0) + log.count;
    }
    return reasonCounts;
  }

  /// Get intensity distribution for a habit
  Future<Map<int, int>> getIntensityStats(String habitId) async {
    final logs = await getLogsForHabit(habitId, sortDescending: false);
    final intensityCounts = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
    for (final log in logs) {
      intensityCounts[log.intensityIndex] =
          (intensityCounts[log.intensityIndex] ?? 0) + log.count;
    }
    return intensityCounts;
  }

  /// Get a single log by ID
  Future<TemptationLog?> getLogById(String id) async {
    final box = await _getBoxOrNull();
    if (box == null) return null;
    return box.get(id);
  }

  /// Update an existing log
  Future<void> updateLog(TemptationLog log) async {
    final box = await _getBox();
    await box.put(log.id, log);
  }

  /// Delete a log
  Future<void> deleteLog(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Delete all logs for a habit
  Future<void> deleteLogsForHabit(String habitId) async {
    final box = await _getBox();
    final logsToDelete = box.values
        .where((log) => log.habitId == habitId)
        .toList();
    for (final log in logsToDelete) {
      await box.delete(log.id);
    }
  }

  /// Delete all temptation logs
  Future<void> clearAllLogs() async {
    final box = await _getBoxOrNull();
    if (box == null) return;
    await box.clear();
  }

  /// Delete all legacy (non-secure) temptation logs
  Future<void> clearLegacyLogs() async {
    final box = await getLegacyBox();
    await box.clear();
  }

  /// Get streak data - days without temptation
  Future<int> getDaysWithoutTemptation(String habitId) async {
    final logs = await getLogsForHabit(habitId);
    if (logs.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastLog = logs.first; // Already sorted by most recent
    final lastLogDate = DateTime(
      lastLog.occurredAt.year,
      lastLog.occurredAt.month,
      lastLog.occurredAt.day,
    );

    return today.difference(lastLogDate).inDays;
  }
}
