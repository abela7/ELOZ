import '../models/account.dart';
import '../models/transaction.dart';
import '../repositories/account_repository.dart';
import '../repositories/daily_balance_repository.dart';
import '../repositories/transaction_repository.dart';

/// Service for calculating and storing daily total balances
class DailyBalanceService {
  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;
  final DailyBalanceRepository _dailyBalanceRepository;

  DailyBalanceService(
    this._accountRepository,
    this._transactionRepository,
    this._dailyBalanceRepository,
  );

  /// Get total balance by currency for a specific date.
  /// Uses bank-style closing balance: initial balances + all transactions
  /// up to end of that day. Results are cached per day except for today
  /// (which is always recomputed for real-time accuracy).
  Future<Map<String, double>> getTotalBalanceByCurrencyForDate(
    DateTime date,
  ) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final isToday = dateOnly.isAtSameMomentAs(today);

    if (!isToday) {
      final cached =
          await _dailyBalanceRepository.getBalanceMapForDate(dateOnly);
      if (cached.isNotEmpty) {
        return cached;
      }
    }

    final computed = await _calculateBalancesForDate(dateOnly);
    if (computed.isNotEmpty && !isToday) {
      await _dailyBalanceRepository.saveBalancesForDate(dateOnly, computed);
    }

    return computed;
  }

  /// Invalidate cached snapshots from a specific date onward
  Future<void> invalidateFromDate(DateTime date) async {
    await _dailyBalanceRepository.deleteSnapshotsFromDate(date);
  }

  /// Invalidate all cached snapshots
  Future<void> invalidateAll() async {
    await _dailyBalanceRepository.deleteAllSnapshots();
  }

  Future<Map<String, double>> _calculateBalancesForDate(DateTime date) async {
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    final accounts = await _accountRepository.getAccountsInTotal();

    // Only include accounts that existed on or before the date
    final relevantAccounts = accounts
        .where((a) => !a.createdAt.isAfter(endOfDay))
        .toList();

    if (relevantAccounts.isEmpty) {
      return {};
    }

    final Map<String, Account> accountMap = {
      for (final account in relevantAccounts) account.id: account,
    };

    // Start with initial balances (bank opening balance)
    final Map<String, double> balancesByAccount = {
      for (final account in relevantAccounts)
        account.id: account.initialBalance,
    };

    // Get all transactions up to end of day and sort chronologically
    // (bank-style processing order: date, then time)
    final rawTransactions =
        await _transactionRepository.getTransactionsUpToDate(endOfDay);
    final transactions = List<Transaction>.from(rawTransactions)
      ..sort((a, b) {
        final dateCompare = a.transactionDate.compareTo(b.transactionDate);
        if (dateCompare != 0) return dateCompare;
        final hourA = a.transactionTimeHour ?? 0;
        final hourB = b.transactionTimeHour ?? 0;
        if (hourA != hourB) return hourA.compareTo(hourB);
        final minA = a.transactionTimeMinute ?? 0;
        final minB = b.transactionTimeMinute ?? 0;
        return minA.compareTo(minB);
      });

    for (final tx in transactions) {
      final amount = tx.amount;
      final accountId = tx.accountId;
      final toAccountId = tx.toAccountId;

      switch (tx.type) {
        case 'income':
          if (accountId != null && balancesByAccount.containsKey(accountId)) {
            balancesByAccount[accountId] =
                (balancesByAccount[accountId] ?? 0) + amount;
          }
          break;
        case 'expense':
          if (accountId != null && balancesByAccount.containsKey(accountId)) {
            balancesByAccount[accountId] =
                (balancesByAccount[accountId] ?? 0) - amount;
          }
          break;
        case 'transfer':
          if (accountId != null && balancesByAccount.containsKey(accountId)) {
            balancesByAccount[accountId] =
                (balancesByAccount[accountId] ?? 0) - amount;
          }
          if (toAccountId != null &&
              balancesByAccount.containsKey(toAccountId)) {
            balancesByAccount[toAccountId] =
                (balancesByAccount[toAccountId] ?? 0) + amount;
          }
          break;
      }
    }

    // Aggregate totals by currency
    final Map<String, double> totalsByCurrency = {};
    for (final entry in balancesByAccount.entries) {
      final account = accountMap[entry.key];
      if (account == null) continue;
      final currency = account.currency;
      totalsByCurrency[currency] =
          (totalsByCurrency[currency] ?? 0) + entry.value;
    }

    return totalsByCurrency;
  }
}
