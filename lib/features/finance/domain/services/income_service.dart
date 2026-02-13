import '../../data/models/recurring_income.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/recurring_income_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../../../core/notifications/notification_hub.dart';
import '../../notifications/finance_notification_scheduler.dart';

/// Service for managing income operations, including recurring income generation.
class IncomeService {
  final RecurringIncomeRepository _recurringIncomeRepo;
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;
  final NotificationHub _notificationHub;

  IncomeService({
    required RecurringIncomeRepository recurringIncomeRepo,
    required TransactionRepository transactionRepo,
    required AccountRepository accountRepo,
    required NotificationHub notificationHub,
  }) : _recurringIncomeRepo = recurringIncomeRepo,
       _transactionRepo = transactionRepo,
       _accountRepo = accountRepo,
       _notificationHub = notificationHub;

  /// Process all pending recurring income transactions.
  /// This should be called daily (e.g., on app startup or via background task).
  Future<int> processPendingRecurringIncome() async {
    final pending = _recurringIncomeRepo.getPendingGeneration();
    int generated = 0;

    for (final income in pending) {
      final now = DateTime.now();
      final nextOccurrence = income.nextOccurrenceAfter(
        income.lastGeneratedDate ??
            income.startDate.subtract(const Duration(days: 1)),
      );

      if (nextOccurrence == null) continue;

      // Only generate if the occurrence date has arrived
      final today = DateTime(now.year, now.month, now.day);
      final occurrenceDate = DateTime(
        nextOccurrence.year,
        nextOccurrence.month,
        nextOccurrence.day,
      );

      if (occurrenceDate.isAfter(today)) continue;

      // Create transaction
      await _createTransactionFromRecurring(income, nextOccurrence);

      // Update last generated date
      await _recurringIncomeRepo.updateLastGenerated(income.id, nextOccurrence);

      generated++;
    }

    return generated;
  }

  /// Create a transaction from a recurring income.
  Future<Transaction> _createTransactionFromRecurring(
    RecurringIncome income,
    DateTime date,
  ) async {
    final transaction = Transaction(
      title: income.title,
      type: 'income',
      amount: income.amount,
      currency: income.currency,
      categoryId: income.categoryId,
      accountId: income.accountId,
      transactionDate: date,
      description: '${income.title} (Auto-generated)',
      notes: income.notes,
      isRecurring: true,
      recurringGroupId: income.id,
    );

    await _transactionRepo.createTransaction(transaction);

    // Update account balance if account is specified
    if (income.accountId != null) {
      final account = await _accountRepo.getAccountById(income.accountId!);
      if (account != null && account.currency == income.currency) {
        final updatedAccount = account.copyWith(
          balance: account.balance + income.amount,
        );
        await _accountRepo.updateAccount(updatedAccount);
      }
    }

    return transaction;
  }

  /// Schedule notifications for upcoming recurring income for the next 6 months.
  /// This schedules all notifications in advance and should be called periodically
  /// to ensure the 6-month window is always maintained.
  Future<void> scheduleRecurringIncomeNotifications() async {
    final scheduler = FinanceNotificationScheduler(
      notificationHub: _notificationHub,
      recurringIncomeRepository: _recurringIncomeRepo,
    );
    await scheduler.syncSchedules();
  }

  /// Check if notification scheduling needs to be extended.
  /// Should be called periodically (e.g., weekly) to ensure we always have
  /// 6 months of notifications scheduled in advance.
  ///
  /// This method can be enhanced to track the last scheduled date per income
  /// source and only return true when we're within 3 months of the end.
  Future<bool> shouldExtendNotificationSchedule() async {
    // For now, always return true to ensure notifications are up-to-date
    // In a production system, you might track the last scheduled date
    // and only extend when needed
    return true;
  }

  /// Cancel notifications for a recurring income.
  Future<void> cancelNotifications(String incomeId) async {
    await scheduleRecurringIncomeNotifications();
  }

  /// Get income statistics for a period.
  Future<IncomeStatistics> getStatistics(
    DateTime start,
    DateTime end,
    String currency,
  ) async {
    // Get actual income transactions
    final allTransactions = await _transactionRepo.getAllTransactions();
    final transactions = allTransactions
        .where(
          (t) =>
              t.type == 'income' &&
              t.currency == currency &&
              t.transactionDate.isAfter(
                start.subtract(const Duration(days: 1)),
              ) &&
              t.transactionDate.isBefore(end.add(const Duration(days: 1))),
        )
        .toList();

    final actualIncome = transactions.fold<double>(
      0.0,
      (sum, t) => sum + t.amount,
    );

    // Get expected income from recurring sources
    final expectedIncome = _recurringIncomeRepo.getTotalExpectedForPeriod(
      start,
      end,
      currency,
    );

    // Calculate by category
    final byCategory = <String, double>{};
    for (final tx in transactions) {
      final catId = tx.categoryId ?? 'uncategorized';
      byCategory[catId] = (byCategory[catId] ?? 0.0) + tx.amount;
    }

    return IncomeStatistics(
      actualIncome: actualIncome,
      expectedIncome: expectedIncome,
      transactionCount: transactions.length,
      byCategory: byCategory,
      currency: currency,
      startDate: start,
      endDate: end,
    );
  }

  /// Compare two periods.
  Future<IncomeComparison> comparePeriods(
    DateTime period1Start,
    DateTime period1End,
    DateTime period2Start,
    DateTime period2End,
    String currency,
  ) async {
    final stats1 = await getStatistics(period1Start, period1End, currency);
    final stats2 = await getStatistics(period2Start, period2End, currency);

    final difference = stats2.actualIncome - stats1.actualIncome;
    final percentChange = stats1.actualIncome > 0
        ? (difference / stats1.actualIncome) * 100
        : 0.0;

    return IncomeComparison(
      previousPeriod: stats1,
      currentPeriod: stats2,
      difference: difference,
      percentChange: percentChange,
    );
  }
}

/// Income statistics for a period.
class IncomeStatistics {
  final double actualIncome;
  final double expectedIncome;
  final int transactionCount;
  final Map<String, double> byCategory;
  final String currency;
  final DateTime startDate;
  final DateTime endDate;

  IncomeStatistics({
    required this.actualIncome,
    required this.expectedIncome,
    required this.transactionCount,
    required this.byCategory,
    required this.currency,
    required this.startDate,
    required this.endDate,
  });

  double get variance => actualIncome - expectedIncome;
  double get variancePercent =>
      expectedIncome > 0 ? (variance / expectedIncome) * 100 : 0.0;

  double get dailyAverage {
    final days = endDate.difference(startDate).inDays + 1;
    return days > 0 ? actualIncome / days : 0.0;
  }
}

/// Comparison between two income periods.
class IncomeComparison {
  final IncomeStatistics previousPeriod;
  final IncomeStatistics currentPeriod;
  final double difference;
  final double percentChange;

  IncomeComparison({
    required this.previousPeriod,
    required this.currentPeriod,
    required this.difference,
    required this.percentChange,
  });

  bool get isIncrease => difference > 0;
  bool get isDecrease => difference < 0;
  bool get isStable => difference == 0;
}
