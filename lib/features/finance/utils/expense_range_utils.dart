import '../data/models/transaction.dart';
import '../data/services/finance_settings_service.dart';

/// Supported range filters for expense insights.
enum ExpenseRangeView { day, week, month, sixMonths, year }

/// Inclusive date range with day-level precision.
class ExpenseRange {
  final DateTime start;
  final DateTime end;

  const ExpenseRange({required this.start, required this.end});

  int get totalDays => end.difference(start).inDays + 1;
}

/// Daily expense aggregate for a specific day in a range.
class ExpenseDailyTotal {
  final DateTime date;
  final Map<String, double> totalsByCurrency;
  final int transactionCount;

  const ExpenseDailyTotal({
    required this.date,
    required this.totalsByCurrency,
    required this.transactionCount,
  });
}

/// Deterministic helpers for range and per-day expense calculations.
class ExpenseRangeUtils {
  static DateTime normalizeDate(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static ExpenseRange rangeFor(DateTime anchorDate, ExpenseRangeView view) {
    final anchor = normalizeDate(anchorDate);
    switch (view) {
      case ExpenseRangeView.day:
        return ExpenseRange(start: anchor, end: anchor);
      case ExpenseRangeView.week:
        final start = startOfWeek(anchor);
        return ExpenseRange(
          start: start,
          end: start.add(const Duration(days: 6)),
        );
      case ExpenseRangeView.month:
        final start = DateTime(anchor.year, anchor.month, 1);
        final end = endOfMonth(anchor);
        return ExpenseRange(start: start, end: end);
      case ExpenseRangeView.sixMonths:
        // Last 6 months from anchor date
        final start = DateTime(anchor.year, anchor.month - 5, 1);
        final end = endOfMonth(anchor);
        return ExpenseRange(start: start, end: end);
      case ExpenseRangeView.year:
        // Last 12 months from anchor date
        final start = DateTime(anchor.year, anchor.month - 11, 1);
        final end = endOfMonth(anchor);
        return ExpenseRange(start: start, end: end);
    }
  }

  static DateTime startOfWeek(DateTime date) {
    final normalized = normalizeDate(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  static DateTime endOfMonth(DateTime date) {
    final normalized = normalizeDate(date);
    return DateTime(normalized.year, normalized.month + 1, 0);
  }

  static List<Transaction> filterExpensesForRange(
    List<Transaction> transactions, {
    required ExpenseRange range,
  }) {
    return transactions.where((transaction) {
      if (!transaction.isExpense || transaction.isBalanceAdjustment) {
        return false;
      }
      final txDate = normalizeDate(transaction.transactionDate);
      return !txDate.isBefore(range.start) && !txDate.isAfter(range.end);
    }).toList();
  }

  static List<Transaction> filterIncomesForRange(
    List<Transaction> transactions, {
    required ExpenseRange range,
  }) {
    return transactions.where((transaction) {
      if (!transaction.isIncome || transaction.isBalanceAdjustment) {
        return false;
      }
      final txDate = normalizeDate(transaction.transactionDate);
      return !txDate.isBefore(range.start) && !txDate.isAfter(range.end);
    }).toList();
  }

  static Map<String, double> totalsByCurrency(
    Iterable<Transaction> transactions, {
    String? defaultCurrency,
  }) {
    final fallback = defaultCurrency ?? FinanceSettingsService.fallbackCurrency;
    final totals = <String, double>{};

    for (final transaction in transactions) {
      final currency = transaction.currency ?? fallback;
      totals[currency] = (totals[currency] ?? 0) + transaction.amount;
    }

    return totals;
  }

  static List<ExpenseDailyTotal> dailyTotals(
    List<Transaction> periodExpenses, {
    required ExpenseRange range,
    String? defaultCurrency,
  }) {
    final fallback = defaultCurrency ?? FinanceSettingsService.fallbackCurrency;
    final totalsByDay = <DateTime, Map<String, double>>{};
    final countsByDay = <DateTime, int>{};

    for (var i = 0; i < range.totalDays; i++) {
      final day = range.start.add(Duration(days: i));
      totalsByDay[day] = <String, double>{};
      countsByDay[day] = 0;
    }

    for (final transaction in periodExpenses) {
      final day = normalizeDate(transaction.transactionDate);
      if (day.isBefore(range.start) || day.isAfter(range.end)) {
        continue;
      }
      final currency = transaction.currency ?? fallback;
      final dayTotals = totalsByDay[day]!;
      dayTotals[currency] = (dayTotals[currency] ?? 0) + transaction.amount;
      countsByDay[day] = (countsByDay[day] ?? 0) + 1;
    }

    return totalsByDay.entries.map((entry) {
      return ExpenseDailyTotal(
        date: entry.key,
        totalsByCurrency: entry.value,
        transactionCount: countsByDay[entry.key] ?? 0,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }
}
