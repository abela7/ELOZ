import '../repositories/transaction_repository.dart';
import '../../../../core/utils/perf_trace.dart';

/// Service for calculating financial statistics and insights
class FinanceStatisticsService {
  final TransactionRepository _transactionRepository;

  FinanceStatisticsService(this._transactionRepository);

  /// Get income vs expense statistics for a date range
  Future<Map<String, dynamic>> getIncomeExpenseStats({
    required DateTime startDate,
    required DateTime endDate,
    required String defaultCurrency,
  }) async {
    final trace = PerfTrace('FinanceStats.getIncomeExpenseStats');
    final transactions = await _transactionRepository.getTransactionsInRange(
      startDate,
      endDate,
    );
    trace.step('transactions_loaded', details: {'count': transactions.length});

    final income = transactions.where(
      (t) => t.isIncome && !t.isBalanceAdjustment,
    );
    final expenses = transactions.where(
      (t) => t.isExpense && !t.isBalanceAdjustment,
    );

    final Map<String, double> totalIncomeByCurrency = {};
    final Map<String, double> totalExpenseByCurrency = {};

    for (final t in income) {
      final cur = t.currency ?? defaultCurrency;
      totalIncomeByCurrency[cur] = (totalIncomeByCurrency[cur] ?? 0) + t.amount;
    }

    for (final t in expenses) {
      final cur = t.currency ?? defaultCurrency;
      totalExpenseByCurrency[cur] =
          (totalExpenseByCurrency[cur] ?? 0) + t.amount;
    }
    trace.step(
      'grouped',
      details: {
        'incomeCurrencies': totalIncomeByCurrency.length,
        'expenseCurrencies': totalExpenseByCurrency.length,
      },
    );

    // CRITICAL: Do NOT sum different currencies together - it's mathematically incorrect!
    // Instead, calculate net income per currency and return currency breakdown
    // For backward compatibility, we'll calculate totals only if there's a single currency
    // Otherwise, return 0 for totals and rely on currency breakdown
    final currencies = {
      ...totalIncomeByCurrency.keys,
      ...totalExpenseByCurrency.keys,
    };
    double totalIncome = 0;
    double totalExpense = 0;

    if (currencies.length == 1) {
      // Single currency - safe to sum
      final currency = currencies.first;
      totalIncome = totalIncomeByCurrency[currency] ?? 0;
      totalExpense = totalExpenseByCurrency[currency] ?? 0;
    } else {
      // Multiple currencies - cannot sum, set to 0 and rely on currency breakdown
      totalIncome = 0;
      totalExpense = 0;
    }

    final netIncome = totalIncome - totalExpense;

    final output = {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'totalIncomeByCurrency': totalIncomeByCurrency,
      'totalExpenseByCurrency': totalExpenseByCurrency,
      'netIncome': netIncome,
      'incomeCount': income.length,
      'expenseCount': expenses.length,
      'savingsRate': totalIncome > 0 ? (netIncome / totalIncome * 100) : 0,
    };
    trace.end('done');
    return output;
  }

  /// Get spending by category for a date range
  Future<Map<String, double>> getSpendingByCategory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final transactions = await _transactionRepository.getTransactionsInRange(
      startDate,
      endDate,
    );

    final expenses = transactions.where(
      (t) => t.isExpense && !t.isBalanceAdjustment && t.categoryId != null,
    );
    final Map<String, double> categorySpending = {};

    for (final expense in expenses) {
      final categoryId = expense.categoryId!;
      categorySpending[categoryId] =
          (categorySpending[categoryId] ?? 0) + expense.amount;
    }

    return categorySpending;
  }

  /// Get income by category for a date range
  Future<Map<String, double>> getIncomeByCategory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final transactions = await _transactionRepository.getTransactionsInRange(
      startDate,
      endDate,
    );

    final income = transactions.where(
      (t) => t.isIncome && !t.isBalanceAdjustment && t.categoryId != null,
    );
    final Map<String, double> categoryIncome = {};

    for (final incomeTransaction in income) {
      final categoryId = incomeTransaction.categoryId!;
      categoryIncome[categoryId] =
          (categoryIncome[categoryId] ?? 0) + incomeTransaction.amount;
    }

    return categoryIncome;
  }

  /// Get daily spending trend for a date range
  Future<Map<DateTime, double>> getDailySpendingTrend({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final transactions = await _transactionRepository.getTransactionsInRange(
      startDate,
      endDate,
    );

    final expenses = transactions.where(
      (t) => t.isExpense && !t.isBalanceAdjustment,
    );
    final Map<DateTime, double> dailySpending = {};

    for (final expense in expenses) {
      final date = DateTime(
        expense.transactionDate.year,
        expense.transactionDate.month,
        expense.transactionDate.day,
      );
      dailySpending[date] = (dailySpending[date] ?? 0) + expense.amount;
    }

    return dailySpending;
  }

  /// Get monthly statistics for current month
  Future<Map<String, dynamic>> getMonthlyStatistics({
    required String defaultCurrency,
  }) async {
    final trace = PerfTrace('FinanceStats.getMonthlyStatistics');
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    trace.step(
      'range_ready',
      details: {
        'start': startOfMonth.toIso8601String().split('T').first,
        'end': endOfMonth.toIso8601String().split('T').first,
      },
    );
    final stats = await getIncomeExpenseStats(
      startDate: startOfMonth,
      endDate: endOfMonth,
      defaultCurrency: defaultCurrency,
    );
    trace.end('done');
    return stats;
  }

  /// Get yearly statistics for current year
  Future<Map<String, dynamic>> getYearlyStatistics({
    required String defaultCurrency,
  }) async {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year, 12, 31);

    return await getIncomeExpenseStats(
      startDate: startOfYear,
      endDate: endOfYear,
      defaultCurrency: defaultCurrency,
    );
  }

  /// Get top spending categories for a period
  Future<List<Map<String, dynamic>>> getTopSpendingCategories({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 5,
  }) async {
    final categorySpending = await getSpendingByCategory(
      startDate: startDate,
      endDate: endDate,
    );

    final sortedCategories = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCategories
        .take(limit)
        .map((e) => {'categoryId': e.key, 'amount': e.value})
        .toList();
  }

  /// Calculate average daily spending for a period
  Future<double> getAverageDailySpending({
    required DateTime startDate,
    required DateTime endDate,
    required String defaultCurrency,
  }) async {
    final stats = await getIncomeExpenseStats(
      startDate: startDate,
      endDate: endDate,
      defaultCurrency: defaultCurrency,
    );

    final days = endDate.difference(startDate).inDays + 1;
    return days > 0 ? stats['totalExpense'] / days : 0;
  }

  /// Get spending comparison between two periods
  Future<Map<String, dynamic>> compareSpendingPeriods({
    required DateTime period1Start,
    required DateTime period1End,
    required DateTime period2Start,
    required DateTime period2End,
    required String defaultCurrency,
  }) async {
    final period1Stats = await getIncomeExpenseStats(
      startDate: period1Start,
      endDate: period1End,
      defaultCurrency: defaultCurrency,
    );

    final period2Stats = await getIncomeExpenseStats(
      startDate: period2Start,
      endDate: period2End,
      defaultCurrency: defaultCurrency,
    );

    final expenseDiff =
        period2Stats['totalExpense'] - period1Stats['totalExpense'];
    final incomeDiff =
        period2Stats['totalIncome'] - period1Stats['totalIncome'];

    return {
      'period1': period1Stats,
      'period2': period2Stats,
      'expenseDifference': expenseDiff,
      'incomeDifference': incomeDiff,
      'expenseChange': period1Stats['totalExpense'] > 0
          ? (expenseDiff / period1Stats['totalExpense'] * 100)
          : 0,
      'incomeChange': period1Stats['totalIncome'] > 0
          ? (incomeDiff / period1Stats['totalIncome'] * 100)
          : 0,
    };
  }
}
