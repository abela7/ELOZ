import 'package:hive_flutter/hive_flutter.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../models/transaction.dart';

/// Repository for transaction CRUD operations using Hive
class TransactionRepository {
  static const String boxName = 'transactionsBox';

  /// Cached box reference for performance
  Box<Transaction>? _cachedBox;

  /// Get the transactions box (lazy initialization with caching)
  Future<Box<Transaction>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<Transaction>(boxName);
    return _cachedBox!;
  }

  /// Create a new transaction
  Future<void> createTransaction(Transaction transaction) async {
    final box = await _getBox();
    await box.put(transaction.id, transaction);
  }

  /// Get all transactions
  Future<List<Transaction>> getAllTransactions() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get transaction by ID
  Future<Transaction?> getTransactionById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing transaction
  Future<void> updateTransaction(Transaction transaction) async {
    final box = await _getBox();
    transaction.updatedAt = DateTime.now();
    await box.put(transaction.id, transaction);
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Get transactions by type (income, expense, transfer)
  Future<List<Transaction>> getTransactionsByType(String type) async {
    final allTransactions = await getAllTransactions();
    return allTransactions.where((t) => t.type == type).toList();
  }

  /// Get transactions for a specific date
  Future<List<Transaction>> getTransactionsForDate(DateTime date) async {
    final allTransactions = await getAllTransactions();
    final targetDate = date.toLocal();
    return allTransactions.where((t) {
      final txDate = t.transactionDate.toLocal();
      return txDate.year == targetDate.year &&
          txDate.month == targetDate.month &&
          txDate.day == targetDate.day;
    }).toList();
  }

  /// Get transactions in date range (inclusive of both start and end dates)
  Future<List<Transaction>> getTransactionsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final allTransactions = await getAllTransactions();
    // Normalize dates to start of day for accurate comparison
    final localStart = startDate.toLocal();
    final localEnd = endDate.toLocal();
    final normalizedStart = DateTime(
      localStart.year,
      localStart.month,
      localStart.day,
    );
    final normalizedEnd = DateTime(
      localEnd.year,
      localEnd.month,
      localEnd.day,
      23,
      59,
      59,
      999,
    );

    return allTransactions.where((t) {
      final txDate = t.transactionDate.toLocal();
      // Check if transaction date is within range (inclusive)
      // Compare dates at day level to ensure we capture all transactions on boundary dates
      final txDayStart = DateTime(txDate.year, txDate.month, txDate.day);
      final txDayEnd = DateTime(
        txDate.year,
        txDate.month,
        txDate.day,
        23,
        59,
        59,
        999,
      );

      return txDayStart.isBefore(
            normalizedEnd.add(const Duration(milliseconds: 1)),
          ) &&
          txDayEnd.isAfter(
            normalizedStart.subtract(const Duration(milliseconds: 1)),
          );
    }).toList();
  }

  /// Get transactions up to a specific date (inclusive)
  Future<List<Transaction>> getTransactionsUpToDate(DateTime date) async {
    final allTransactions = await getAllTransactions();
    final localDate = date.toLocal();
    final endOfDay = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
      23,
      59,
      59,
      999,
    );
    return allTransactions
        .where((t) => !t.transactionDate.toLocal().isAfter(endOfDay))
        .toList();
  }

  /// Get transactions by category
  Future<List<Transaction>> getTransactionsByCategory(String categoryId) async {
    final allTransactions = await getAllTransactions();
    return allTransactions.where((t) => t.categoryId == categoryId).toList();
  }

  /// Get transactions by account
  Future<List<Transaction>> getTransactionsByAccount(String accountId) async {
    final allTransactions = await getAllTransactions();
    return allTransactions
        .where((t) => t.accountId == accountId || t.toAccountId == accountId)
        .toList();
  }

  /// Search transactions by title or description
  Future<List<Transaction>> searchTransactions(String query) async {
    final allTransactions = await getAllTransactions();
    final lowerQuery = query.toLowerCase();
    return allTransactions.where((t) {
      return t.title.toLowerCase().contains(lowerQuery) ||
          (t.description != null &&
              t.description!.toLowerCase().contains(lowerQuery)) ||
          (t.notes != null && t.notes!.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Get transactions that need review
  Future<List<Transaction>> getTransactionsNeedingReview() async {
    final allTransactions = await getAllTransactions();
    return allTransactions.where((t) => t.needsReview).toList();
  }

  /// Get uncleared transactions
  Future<List<Transaction>> getUnclearedTransactions() async {
    final allTransactions = await getAllTransactions();
    return allTransactions.where((t) => !t.isCleared).toList();
  }

  /// Get transaction statistics
  /// Returns statistics grouped by currency to avoid mixing currencies
  Future<Map<String, dynamic>> getTransactionStatistics({
    required String defaultCurrency,
  }) async {
    final allTransactions = await getAllTransactions();
    final income = allTransactions.where(
      (t) => t.isIncome && !t.isBalanceAdjustment,
    );
    final expenses = allTransactions.where(
      (t) => t.isExpense && !t.isBalanceAdjustment,
    );

    // Group amounts by currency to avoid mixing currencies
    final Map<String, double> totalIncomeByCurrency = {};
    final Map<String, double> totalExpenseByCurrency = {};

    for (final t in income) {
      final currency = t.currency ?? defaultCurrency;
      totalIncomeByCurrency[currency] =
          (totalIncomeByCurrency[currency] ?? 0) + t.amount;
    }

    for (final t in expenses) {
      final currency = t.currency ?? defaultCurrency;
      totalExpenseByCurrency[currency] =
          (totalExpenseByCurrency[currency] ?? 0) + t.amount;
    }

    return {
      'total': allTransactions.length,
      'income': income.length,
      'expense': expenses.length,
      'transfer': allTransactions.where((t) => t.isTransfer).length,
      'totalIncomeByCurrency': totalIncomeByCurrency,
      'totalExpenseByCurrency': totalExpenseByCurrency,
      'needsReview': allTransactions.where((t) => t.needsReview).length,
      'uncleared': allTransactions.where((t) => !t.isCleared).length,
    };
  }

  /// Delete all transactions (for reset functionality)
  Future<void> deleteAllTransactions() async {
    final box = await _getBox();
    await box.clear();
  }
}
