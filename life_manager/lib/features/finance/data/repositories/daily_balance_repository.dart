import 'package:hive_flutter/hive_flutter.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../models/daily_balance.dart';

/// Repository for daily balance snapshots using Hive
class DailyBalanceRepository {
  static const String boxName = 'dailyBalancesBox';

  /// Cached box reference for performance
  Box<DailyBalance>? _cachedBox;

  /// Get the daily balances box (lazy initialization with caching)
  Future<Box<DailyBalance>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<DailyBalance>(boxName);
    return _cachedBox!;
  }

  /// Get all balances stored for a specific date
  Future<List<DailyBalance>> getBalancesForDate(DateTime date) async {
    final box = await _getBox();
    final normalized = _normalizeDate(date);
    return box.values.where((b) => _isSameDay(b.date, normalized)).toList();
  }

  /// Get balance map (currency -> amount) for a specific date
  Future<Map<String, double>> getBalanceMapForDate(DateTime date) async {
    final entries = await getBalancesForDate(date);
    final Map<String, double> balances = {};
    for (final entry in entries) {
      balances[entry.currency] = entry.totalBalance;
    }
    return balances;
  }

  /// Save or update balances for a specific date
  Future<void> saveBalancesForDate(
    DateTime date,
    Map<String, double> balances,
  ) async {
    final box = await _getBox();
    final normalized = _normalizeDate(date);

    // Remove old currency entries for this date that no longer exist
    final existing = await getBalancesForDate(normalized);
    final existingCurrencies = existing.map((e) => e.currency).toSet();
    for (final currency in existingCurrencies) {
      if (!balances.containsKey(currency)) {
        final id = DailyBalance(
          date: normalized,
          currency: currency,
          totalBalance: 0,
        ).id;
        await box.delete(id);
      }
    }

    // Save current balances
    for (final entry in balances.entries) {
      final dailyBalance = DailyBalance(
        date: normalized,
        currency: entry.key,
        totalBalance: entry.value,
      );
      await box.put(dailyBalance.id, dailyBalance);
    }
  }

  /// Delete all snapshots on or after a specific date
  Future<void> deleteSnapshotsFromDate(DateTime date) async {
    final box = await _getBox();
    final target = _normalizeDate(date);

    final keysToDelete = <String>[];
    for (final entry in box.values) {
      final entryDate = _normalizeDate(entry.date);
      if (entryDate.isAtSameMomentAs(target) || entryDate.isAfter(target)) {
        keysToDelete.add(entry.id);
      }
    }

    if (keysToDelete.isEmpty) return;
    await box.deleteAll(keysToDelete);
  }

  /// Delete all stored daily balance snapshots
  Future<void> deleteAllSnapshots() async {
    final box = await _getBox();
    await box.clear();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
