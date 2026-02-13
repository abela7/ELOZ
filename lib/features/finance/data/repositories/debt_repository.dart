import 'package:hive_flutter/hive_flutter.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../models/debt.dart';

/// Repository for debt CRUD operations using Hive
class DebtRepository {
  static const String boxName = 'debtsBox';

  /// Cached box reference for performance
  Box<Debt>? _cachedBox;

  /// Get the debts box (lazy initialization with caching)
  Future<Box<Debt>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<Debt>(boxName);
    return _cachedBox!;
  }

  /// Create a new debt
  Future<void> createDebt(Debt debt) async {
    final box = await _getBox();
    await box.put(debt.id, debt);
  }

  /// Get all debts
  Future<List<Debt>> getAllDebtRecords() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get debts by direction (owed or lent)
  Future<List<Debt>> getAllDebts({
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final all = await getAllDebtRecords();
    return all.where((d) => d.debtDirection == direction).toList();
  }

  /// Get debt by ID
  Future<Debt?> getDebtById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing debt
  Future<void> updateDebt(Debt debt) async {
    final box = await _getBox();
    debt.updatedAt = DateTime.now();
    await box.put(debt.id, debt);
    if (debt.isInBox) {
      await debt.save();
    }
  }

  /// Delete a debt
  Future<void> deleteDebt(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Get active debts (not paid off)
  Future<List<Debt>> getActiveDebts({
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final all = await getAllDebts(direction: direction);
    return all.where((d) => d.isActive).toList();
  }

  /// Get paid off debts
  Future<List<Debt>> getPaidOffDebts({
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final all = await getAllDebts(direction: direction);
    return all.where((d) => d.isPaidOff).toList();
  }

  /// Get debts by category
  Future<List<Debt>> getDebtsByCategory(
    String categoryId, {
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final all = await getAllDebts(direction: direction);
    return all.where((d) => d.categoryId == categoryId).toList();
  }

  /// Get debts by currency
  Future<List<Debt>> getDebtsByCurrency(
    String currency, {
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final all = await getAllDebts(direction: direction);
    return all.where((d) => d.currency == currency).toList();
  }

  /// Get overdue debts
  Future<List<Debt>> getOverdueDebts({
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final all = await getAllDebts(direction: direction);
    return all.where((d) => d.isOverdue).toList();
  }

  /// Get debts due within N days
  Future<List<Debt>> getDebtsDueSoon({
    int days = 7,
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final all = await getAllDebts(direction: direction);
    return all.where((d) {
      if (!d.isActive || d.daysUntilDue == null) return false;
      return d.daysUntilDue! >= 0 && d.daysUntilDue! <= days;
    }).toList();
  }

  /// Get total debt balance by currency
  Future<Map<String, double>> getTotalDebtByCurrency({
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final activeDebts = await getActiveDebts(direction: direction);
    final Map<String, double> totals = {};

    for (final debt in activeDebts) {
      totals[debt.currency] =
          (totals[debt.currency] ?? 0) + debt.currentBalance;
    }

    return totals;
  }

  /// Get total debt balance by currency as-of end of a specific day.
  Future<Map<String, double>> getTotalDebtByCurrencyAsOf(
    DateTime asOfDate, {
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final debts = await getAllDebts(direction: direction);
    final Map<String, double> totals = {};

    for (final debt in debts) {
      final balance = debt.balanceAsOfDate(asOfDate);
      if (balance <= 0) continue;

      totals[debt.currency] = (totals[debt.currency] ?? 0) + balance;
    }

    return totals;
  }

  /// Get total debt balance (single currency)
  Future<double> getTotalDebt({
    String? currency,
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final activeDebts = await getActiveDebts(direction: direction);

    if (currency != null) {
      return activeDebts
          .where((d) => d.currency == currency)
          .fold<double>(0, (sum, d) => sum + d.currentBalance);
    }

    return activeDebts.fold<double>(0, (sum, d) => sum + d.currentBalance);
  }

  /// Record a payment on a debt
  Future<void> recordPayment(String debtId, double amount) async {
    final debt = await getDebtById(debtId);
    if (debt != null) {
      debt.recordPayment(amount);
      await updateDebt(debt);
    }
  }

  /// Undo a specific payment from debt payment history.
  Future<bool> undoPayment({
    required String debtId,
    required String paymentId,
  }) async {
    final debt = await getDebtById(debtId);
    if (debt == null) return false;

    final didUndo = debt.undoPayment(paymentId);
    if (!didUndo) return false;

    await updateDebt(debt);
    return true;
  }

  /// Edit/update a specific payment amount.
  Future<bool> updatePayment({
    required String debtId,
    required String paymentId,
    required double amount,
  }) async {
    final debt = await getDebtById(debtId);
    if (debt == null) return false;

    final didUpdate = debt.updatePayment(paymentId, amount);
    if (!didUpdate) return false;

    await updateDebt(debt);
    return true;
  }

  /// Delete all debts
  Future<void> deleteAllDebts() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Get debt statistics
  Future<Map<String, dynamic>> getDebtStatistics({
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final all = await getAllDebts(direction: direction);
    final active = all.where((d) => d.isActive);
    final paidOff = all.where((d) => d.isPaidOff);
    final overdue = all.where((d) => d.isOverdue);

    final totalOwed = active.fold<double>(
      0,
      (sum, d) => sum + d.currentBalance,
    );
    final totalOriginal = active.fold<double>(
      0,
      (sum, d) => sum + d.originalAmount,
    );
    final totalPaid = active.fold<double>(0, (sum, d) => sum + d.amountPaid);

    return {
      'totalDebts': all.length,
      'activeDebts': active.length,
      'paidOffDebts': paidOff.length,
      'overdueDebts': overdue.length,
      'totalOwed': totalOwed,
      'totalOriginal': totalOriginal,
      'totalPaid': totalPaid,
      'overallProgress': totalOriginal > 0
          ? (totalPaid / totalOriginal * 100)
          : 0,
    };
  }
}
