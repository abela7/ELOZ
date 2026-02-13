import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/models/transaction.dart';
import 'package:life_manager/features/finance/utils/expense_range_utils.dart';

void main() {
  group('ExpenseRangeUtils', () {
    test('week range uses Monday to Sunday around selected day', () {
      final anchor = DateTime(2026, 2, 11); // Wednesday
      final range = ExpenseRangeUtils.rangeFor(anchor, ExpenseRangeView.week);

      expect(range.start, DateTime(2026, 2, 9)); // Monday
      expect(range.end, DateTime(2026, 2, 15)); // Sunday
      expect(range.totalDays, 7);
    });

    test(
      'filters only expense transactions in selected day/week/month range',
      () {
        final transactions = [
          Transaction(
            title: 'Monday expense',
            amount: 100,
            type: 'expense',
            transactionDate: DateTime(2026, 2, 9, 9, 0),
            currency: 'GBP',
          ),
          Transaction(
            title: 'Friday expense',
            amount: 50,
            type: 'expense',
            transactionDate: DateTime(2026, 2, 13, 13, 0),
            currency: 'GBP',
          ),
          Transaction(
            title: 'Income ignored',
            amount: 200,
            type: 'income',
            transactionDate: DateTime(2026, 2, 13, 15, 0),
            currency: 'GBP',
          ),
          Transaction(
            title: 'Balance correction ignored',
            amount: 10,
            type: 'expense',
            transactionDate: DateTime(2026, 2, 13, 18, 0),
            currency: 'GBP',
            isBalanceAdjustment: true,
          ),
        ];

        final weekRange = ExpenseRangeUtils.rangeFor(
          DateTime(2026, 2, 13),
          ExpenseRangeView.week,
        );
        final weekExpenses = ExpenseRangeUtils.filterExpensesForRange(
          transactions,
          range: weekRange,
        );

        expect(weekExpenses.length, 2);

        final totals = ExpenseRangeUtils.totalsByCurrency(
          weekExpenses,
          defaultCurrency: 'GBP',
        );
        expect(totals['GBP'], 150);
      },
    );

    test('builds daily totals without shifting values across days', () {
      final weekRange = ExpenseRangeUtils.rangeFor(
        DateTime(2026, 2, 13),
        ExpenseRangeView.week,
      );

      final weekExpenses = [
        Transaction(
          title: 'Monday',
          amount: 100,
          type: 'expense',
          transactionDate: DateTime(2026, 2, 9, 9, 0),
          currency: 'GBP',
        ),
        Transaction(
          title: 'Friday GBP',
          amount: 50,
          type: 'expense',
          transactionDate: DateTime(2026, 2, 13, 14, 0),
          currency: 'GBP',
        ),
        Transaction(
          title: 'Friday USD',
          amount: 20,
          type: 'expense',
          transactionDate: DateTime(2026, 2, 13, 16, 0),
          currency: 'USD',
        ),
      ];

      final daily = ExpenseRangeUtils.dailyTotals(
        weekExpenses,
        range: weekRange,
        defaultCurrency: 'GBP',
      );

      expect(daily.length, 7);

      final monday = daily.firstWhere(
        (entry) => entry.date == DateTime(2026, 2, 9),
      );
      final friday = daily.firstWhere(
        (entry) => entry.date == DateTime(2026, 2, 13),
      );
      final thursday = daily.firstWhere(
        (entry) => entry.date == DateTime(2026, 2, 12),
      );

      expect(monday.totalsByCurrency['GBP'], 100);
      expect(monday.transactionCount, 1);

      expect(thursday.totalsByCurrency['GBP'] ?? 0, 0);
      expect(thursday.transactionCount, 0);

      expect(friday.totalsByCurrency['GBP'], 50);
      expect(friday.totalsByCurrency['USD'], 20);
      expect(friday.transactionCount, 2);
    });
  });
}
