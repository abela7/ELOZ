import 'package:hive/hive.dart';
import '../models/sleep_record.dart';
import '../../sleep_module.dart';
import '../../../../data/local/hive/hive_service.dart';

/// Repository for Sleep Record CRUD operations
class SleepRecordRepository {
  /// Get the Hive box for sleep records
  Future<Box<SleepRecord>> _getBox() async {
    return await HiveService.getBox<SleepRecord>(SleepModule.sleepRecordsBoxName);
  }

  /// Create a new sleep record
  Future<void> create(SleepRecord record) async {
    final box = await _getBox();
    await box.put(record.id, record);
    await box.flush(); // Ensure data is written to disk
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
    final box = await _getBox();
    record.updatedAt = DateTime.now();
    await box.put(record.id, record);
    await box.flush(); // Ensure data is written to disk
  }

  /// Delete a sleep record
  Future<void> delete(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Get sleep records for a specific date
  Future<List<SleepRecord>> getByDate(DateTime date) async {
    final box = await _getBox();
    final targetDate = DateTime(date.year, date.month, date.day);

    return box.values.where((record) {
      final recordDate = DateTime(
        record.bedTime.year,
        record.bedTime.month,
        record.bedTime.day,
      );
      return recordDate == targetDate;
    }).toList()
      ..sort((a, b) => b.bedTime.compareTo(a.bedTime));
  }

  /// Get sleep records within a date range
  Future<List<SleepRecord>> getByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final box = await _getBox();

    return box.values.where((record) {
      final bedDate = DateTime(
        record.bedTime.year,
        record.bedTime.month,
        record.bedTime.day,
      );
      return bedDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          bedDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => b.bedTime.compareTo(a.bedTime));
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
    }).toList()
      ..sort((a, b) => b.bedTime.compareTo(a.bedTime));
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
    final records = await getByDate(date);
    return records.isNotEmpty;
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
    final box = await _getBox();
    await box.clear();
  }

  /// Watch sleep records stream
  Stream<List<SleepRecord>> watchAll() async* {
    final box = await _getBox();
    yield box.values.toList()
      ..sort((a, b) => b.bedTime.compareTo(a.bedTime));

    await for (final _ in box.watch()) {
      yield box.values.toList()
        ..sort((a, b) => b.bedTime.compareTo(a.bedTime));
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
    final box = await _getBox();
    final map = {for (var record in records) record.id: record};
    await box.putAll(map);
  }

  /// Batch delete multiple sleep records
  Future<void> deleteBatch(List<String> ids) async {
    final box = await _getBox();
    await box.deleteAll(ids);
  }
}
