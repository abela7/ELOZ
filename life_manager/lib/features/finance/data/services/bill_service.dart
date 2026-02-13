import 'package:flutter/material.dart';

import '../../notifications/finance_notification_scheduler.dart';
import '../models/bill.dart';
import '../models/bill_category.dart';
import '../models/transaction.dart';
import '../repositories/bill_repository.dart';
import '../repositories/bill_category_repository.dart';
import '../repositories/transaction_repository.dart';
import 'transaction_balance_service.dart';

/// Service for managing bills, subscriptions, and their categories
class BillService {
  final BillRepository _billRepository;
  final BillCategoryRepository _categoryRepository;
  final TransactionRepository? _transactionRepository;
  final TransactionBalanceService? _balanceService;

  BillService(
    this._billRepository,
    this._categoryRepository, [
    this._transactionRepository,
    this._balanceService,
  ]);

  /// Initialize default bill categories if none exist
  Future<void> initializeDefaultCategories() async {
    final existing = await _categoryRepository.getAllCategories();
    if (existing.isNotEmpty) return;

    final defaults = [
      BillCategory(
        name: 'Utilities',
        icon: Icons.bolt_rounded,
        color: Colors.amber,
        sortOrder: 0,
      ),
      BillCategory(
        name: 'Internet & Phone',
        icon: Icons.wifi_rounded,
        color: Colors.blue,
        sortOrder: 1,
      ),
      BillCategory(
        name: 'Streaming',
        icon: Icons.play_circle_rounded,
        color: Colors.red,
        sortOrder: 2,
      ),
      BillCategory(
        name: 'Insurance',
        icon: Icons.shield_rounded,
        color: Colors.green,
        sortOrder: 3,
      ),
      BillCategory(
        name: 'Rent & Housing',
        icon: Icons.home_rounded,
        color: Colors.purple,
        sortOrder: 4,
      ),
      BillCategory(
        name: 'Transportation',
        icon: Icons.directions_car_rounded,
        color: Colors.orange,
        sortOrder: 5,
      ),
      BillCategory(
        name: 'Software & Apps',
        icon: Icons.apps_rounded,
        color: Colors.cyan,
        sortOrder: 6,
      ),
      BillCategory(
        name: 'Other',
        icon: Icons.more_horiz_rounded,
        color: Colors.grey,
        sortOrder: 99,
      ),
    ];

    for (final category in defaults) {
      await _categoryRepository.createCategory(category);
    }
  }

  /// Mark a bill as paid and calculate next due date
  Future<void> markBillAsPaid(Bill bill, double paidAmount) async {
    final now = DateTime.now();
    bill.lastPaidDate = now;
    bill.lastPaidAmount = paidAmount;
    bill.occurrenceCount += 1;
    bill.totalPaidAmount += paidAmount;

    // Calculate next due date based on frequency
    if (_hasReachedEndCondition(bill, now)) {
      bill.isActive = false;
      bill.nextDueDate = null;
      await _billRepository.updateBill(bill);
      try {
        await FinanceNotificationScheduler().cancelBillNotifications(bill.id);
      } catch (_) {}
      return;
    }

    final nextDue = _calculateNextDueDate(bill, now);
    if (bill.endCondition == 'on_date' &&
        bill.endDate != null &&
        nextDue != null &&
        nextDue.isAfter(_normalizeDate(bill.endDate!))) {
      bill.isActive = false;
      bill.nextDueDate = null;
    } else {
      bill.nextDueDate = nextDue;
    }
    await _billRepository.updateBill(bill);

    // Keep notification state aligned with updated due/reminder state.
    try {
      final scheduler = FinanceNotificationScheduler();
      if (!bill.reminderEnabled || bill.nextDueDate == null) {
        await scheduler.cancelBillNotifications(bill.id);
      } else {
        await scheduler.syncBill(bill);
      }
    } catch (_) {}
  }

  /// Pay a bill - creates a transaction and updates bill status
  Future<Transaction?> payBill(
    Bill bill,
    double paidAmount,
    String accountId,
  ) async {
    if (_transactionRepository == null || _balanceService == null) {
      // Just mark as paid without creating transaction
      await markBillAsPaid(bill, paidAmount);
      return null;
    }

    final now = DateTime.now();

    // Create a transaction for this bill payment
    final transaction = Transaction(
      title: '${bill.name} Payment',
      amount: paidAmount,
      type: 'expense',
      categoryId: bill.categoryId,
      accountId: accountId,
      transactionDate: now,
      transactionTime: TimeOfDay(hour: now.hour, minute: now.minute),
      description: bill.providerName != null
          ? 'Payment to ${bill.providerName}'
          : 'Bill payment for ${bill.name}',
      isRecurring: false,
      currency: bill.currency,
      billId: bill.id, // Link transaction to bill
    );

    // Apply transaction impact to account balance
    await _balanceService.applyTransactionImpact(transaction);

    // Save the transaction
    await _transactionRepository.createTransaction(transaction);

    // Mark bill as paid and update next due date
    await markBillAsPaid(bill, paidAmount);

    return transaction;
  }

  /// Get bills grouped by category
  Future<Map<String, List<Bill>>> getBillsGroupedByCategory() async {
    final bills = await _billRepository.getActiveBills();
    final categories = await _categoryRepository.getAllCategories();
    final Map<String, List<Bill>> grouped = {};

    for (final category in categories) {
      final categoryBills = bills
          .where((b) => b.categoryId == category.id)
          .toList();
      if (categoryBills.isNotEmpty) {
        grouped[category.name] = categoryBills;
      }
    }

    // Add uncategorized
    final uncategorized = bills
        .where((b) => !categories.any((c) => c.id == b.categoryId))
        .toList();
    if (uncategorized.isNotEmpty) {
      grouped['Other'] = uncategorized;
    }

    return grouped;
  }

  /// Get total monthly spend summary
  Future<Map<String, dynamic>> getMonthlySummary() async {
    final bills = await _billRepository.getActiveBills();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final monthlyTotals = _calculateCommitmentByCurrency(
      bills,
      monthStart,
      monthEnd,
    );
    final upcoming = await _billRepository.getUpcomingBills(days: 7);
    final overdue = await _billRepository.getOverdueBills();

    return {
      'totalBills': bills.length,
      'subscriptions': bills.where((b) => b.isSubscription).length,
      'bills': bills.where((b) => b.isBill).length,
      'monthlyTotals': monthlyTotals,
      'upcomingCount': upcoming.length,
      'overdueCount': overdue.length,
      'overdueBills': overdue,
      'upcomingBills': upcoming,
    };
  }

  bool _hasReachedEndCondition(Bill bill, DateTime reference) {
    switch (bill.endCondition) {
      case 'after_occurrences':
        if (bill.endOccurrences == null) return false;
        return bill.occurrenceCount >= (bill.endOccurrences ?? 0);
      case 'after_amount':
        if (bill.endAmount == null) return false;
        return bill.totalPaidAmount >= (bill.endAmount ?? 0);
      case 'on_date':
        if (bill.endDate == null) return false;
        return reference.isAfter(_normalizeDate(bill.endDate!));
      case 'indefinite':
      default:
        return false;
    }
  }

  DateTime? _calculateNextDueDate(Bill bill, DateTime fromDate) {
    final now = _normalizeDate(fromDate);
    switch (bill.frequency) {
      case 'weekly':
        return now.add(const Duration(days: 7));
      case 'monthly':
        final dueDay = bill.dueDay ?? bill.startDate.day;
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final day = _clampDay(dueDay, nextMonth.year, nextMonth.month);
        return DateTime(nextMonth.year, nextMonth.month, day);
      case 'yearly':
        final source = bill.nextDueDate ?? bill.startDate;
        final day = _clampDay(source.day, now.year + 1, source.month);
        return DateTime(now.year + 1, source.month, day);
      case 'custom':
        if (bill.recurrence != null) {
          return bill.recurrence!.getNextOccurrence(now);
        }
        return null;
      default:
        return null;
    }
  }

  int _clampDay(int day, int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    if (day < 1) return 1;
    if (day > lastDay) return lastDay;
    return day;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Map<String, double> _calculateCommitmentByCurrency(
    List<Bill> bills,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final totals = <String, double>{};
    for (final bill in bills.where((b) => b.isActive)) {
      final occurrences = _getBillOccurrencesInRange(bill, rangeStart, rangeEnd);
      if (occurrences.isEmpty) continue;
      totals[bill.currency] =
          (totals[bill.currency] ?? 0) + bill.defaultAmount * occurrences.length;
    }
    return totals;
  }

  List<DateTime> _getBillOccurrencesInRange(
    Bill bill,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final start = _normalizeDate(rangeStart);
    final end = _normalizeDate(rangeEnd);
    final recurrenceStart = _normalizeDate(bill.startDate);
    final baseStart = recurrenceStart.isBefore(start) ? recurrenceStart : start;

    List<DateTime> occurrences;
    if (bill.recurrence != null) {
      occurrences = bill.recurrence!.getOccurrencesInRange(baseStart, end);
    } else {
      switch (bill.frequency) {
        case 'weekly':
          occurrences = _getWeeklyOccurrences(bill, baseStart, end);
          break;
        case 'yearly':
          occurrences = _getYearlyOccurrences(bill, baseStart, end);
          break;
        case 'monthly':
        default:
          occurrences = _getMonthlyOccurrences(bill, baseStart, end);
      }
    }

    occurrences = occurrences.where((d) => !d.isBefore(recurrenceStart)).toList();

    final trimmed = _applyEndConditionToOccurrences(bill, occurrences);
    return trimmed.where((d) => !d.isBefore(start) && !d.isAfter(end)).toList();
  }

  List<DateTime> _applyEndConditionToOccurrences(
    Bill bill,
    List<DateTime> occurrences,
  ) {
    if (occurrences.isEmpty) return occurrences;

    switch (bill.endCondition) {
      case 'on_date':
        if (bill.endDate == null) return occurrences;
        final endDate = _normalizeDate(bill.endDate!);
        return occurrences.where((d) => !d.isAfter(endDate)).toList();
      case 'after_occurrences':
        if (bill.endOccurrences == null || bill.endOccurrences! <= 0) {
          return [];
        }
        final startIndex = bill.occurrenceCount.clamp(0, occurrences.length);
        final remaining =
            (bill.endOccurrences! - bill.occurrenceCount).clamp(0, occurrences.length);
        return occurrences
            .skip(startIndex)
            .take(remaining)
            .toList();
      case 'after_amount':
        if (bill.endAmount == null || bill.endAmount! <= 0) return [];
        final remainingAmount = bill.endAmount! - bill.totalPaidAmount;
        if (remainingAmount <= 0) return [];
        final amount = bill.defaultAmount;
        if (amount <= 0) return [];
        final paidOccurrences = (bill.totalPaidAmount / amount).floor();
        final maxFuture = (remainingAmount / amount).ceil();
        return occurrences
            .skip(paidOccurrences.clamp(0, occurrences.length))
            .take(maxFuture)
            .toList();
      case 'indefinite':
      default:
        return occurrences;
    }
  }

  List<DateTime> _getWeeklyOccurrences(
    Bill bill,
    DateTime start,
    DateTime end,
  ) {
    final weekday = (bill.nextDueDate ?? bill.startDate).weekday;
    final startDay = _normalizeDate(start);
    final offset = (weekday - startDay.weekday + 7) % 7;
    var current = startDay.add(Duration(days: offset));
    final results = <DateTime>[];
    while (!current.isAfter(end)) {
      results.add(current);
      current = current.add(const Duration(days: 7));
    }
    return results;
  }

  List<DateTime> _getMonthlyOccurrences(
    Bill bill,
    DateTime start,
    DateTime end,
  ) {
    final dueDay = bill.dueDay ?? bill.startDate.day;
    var cursor = DateTime(start.year, start.month, 1);
    final lastMonth = DateTime(end.year, end.month, 1);
    final results = <DateTime>[];
    while (!cursor.isAfter(lastMonth)) {
      final day = _clampDay(dueDay, cursor.year, cursor.month);
      final dueDate = DateTime(cursor.year, cursor.month, day);
      if (!dueDate.isBefore(start) && !dueDate.isAfter(end)) {
        results.add(dueDate);
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return results;
  }

  List<DateTime> _getYearlyOccurrences(
    Bill bill,
    DateTime start,
    DateTime end,
  ) {
    final sourceDate = bill.nextDueDate ?? bill.startDate;
    final month = sourceDate.month;
    final day = sourceDate.day;
    final results = <DateTime>[];
    for (var year = start.year; year <= end.year; year++) {
      final clampedDay = _clampDay(day, year, month);
      final dueDate = DateTime(year, month, clampedDay);
      if (!dueDate.isBefore(start) && !dueDate.isAfter(end)) {
        results.add(dueDate);
      }
    }
    return results;
  }
}
