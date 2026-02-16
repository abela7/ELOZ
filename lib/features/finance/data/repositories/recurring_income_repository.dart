import 'package:hive/hive.dart';

import '../../../../data/local/hive/hive_service.dart';
import '../models/recurring_income.dart';

/// Repository for managing recurring income sources.
class RecurringIncomeRepository {
  static const String _boxName = 'recurring_incomes';
  Box<RecurringIncome>? _box;

  Future<void> init() async {
    _box = await HiveService.getBox<RecurringIncome>(_boxName);
  }

  Box<RecurringIncome> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('RecurringIncomeRepository not initialized');
    }
    return _box!;
  }

  /// Get all recurring incomes.
  List<RecurringIncome> getAll() {
    return _safeBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get all active recurring incomes.
  List<RecurringIncome> getActive() {
    return _safeBox.values.where((income) => income.isActive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get all currently active recurring incomes (within date range).
  List<RecurringIncome> getCurrentlyActive() {
    return _safeBox.values.where((income) => income.isCurrentlyActive).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  /// Get recurring incomes by category.
  List<RecurringIncome> getByCategory(String categoryId) {
    return _safeBox.values
        .where((income) => income.categoryId == categoryId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get recurring incomes by account.
  List<RecurringIncome> getByAccount(String accountId) {
    return _safeBox.values
        .where((income) => income.accountId == accountId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get a recurring income by ID.
  RecurringIncome? getById(String id) {
    return _safeBox.get(id);
  }

  /// Create or update a recurring income.
  Future<void> save(RecurringIncome income) async {
    await _safeBox.put(income.id, income);
  }

  /// Delete a recurring income.
  Future<void> delete(String id) async {
    await _safeBox.delete(id);
  }

  /// Deactivate a recurring income.
  Future<void> deactivate(String id) async {
    final income = getById(id);
    if (income != null) {
      await save(income.copyWith(isActive: false));
    }
  }

  /// Reactivate a recurring income.
  Future<void> reactivate(String id) async {
    final income = getById(id);
    if (income != null) {
      await save(income.copyWith(isActive: true));
    }
  }

  /// Get all recurring incomes that need transaction generation.
  /// Returns incomes where:
  /// - autoCreateTransaction is true
  /// - isCurrentlyActive is true
  /// - lastGeneratedDate is null or before today
  List<RecurringIncome> getPendingGeneration() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _safeBox.values.where((income) {
      if (!income.autoCreateTransaction || !income.isCurrentlyActive) {
        return false;
      }

      if (income.lastGeneratedDate == null) return true;

      final lastGenDate = DateTime(
        income.lastGeneratedDate!.year,
        income.lastGeneratedDate!.month,
        income.lastGeneratedDate!.day,
      );

      return lastGenDate.isBefore(today);
    }).toList();
  }

  /// Get all recurring incomes due for notification.
  List<RecurringIncome> getPendingNotifications() {
    final now = DateTime.now();

    return _safeBox.values.where((income) {
      if (!income.notifyOnDue || !income.isCurrentlyActive) return false;

      final nextOccurrence = income.nextOccurrenceAfter(now);
      if (nextOccurrence == null) return false;

      final daysUntil = nextOccurrence.difference(now).inDays;
      return daysUntil <= income.notifyDaysBefore;
    }).toList();
  }

  /// Update last generated date for an income.
  Future<void> updateLastGenerated(String id, DateTime date) async {
    final income = getById(id);
    if (income != null) {
      await save(income.copyWith(lastGeneratedDate: date));
    }
  }

  /// Get total expected income for a period.
  double getTotalExpectedForPeriod(
    DateTime start,
    DateTime end,
    String currency,
  ) {
    double total = 0.0;

    for (final income in getCurrentlyActive()) {
      if (income.currency != currency) continue;

      final occurrences = income.occurrencesBetween(start, end);
      total += occurrences.length * income.amount;
    }

    return total;
  }

  /// Get count of active recurring incomes.
  int get activeCount => getActive().length;

  /// Get count of currently active recurring incomes.
  int get currentlyActiveCount => getCurrentlyActive().length;

  Future<void> close() async {
    await _box?.close();
  }
}
