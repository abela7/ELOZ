import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:life_manager/features/finance/data/models/transaction.dart';
import 'package:life_manager/features/finance/data/repositories/transaction_repository.dart';
import 'package:life_manager/features/finance/data/services/finance_statistics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('finance_stats_parity_');
    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(TransactionAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  test('month-range stats and daily trend match raw scan outputs', () async {
    final repository = TransactionRepository(
      transactionBoxOpener: () =>
          Hive.openBox<Transaction>(TransactionRepository.boxName),
      dynamicBoxOpener: (boxName) => Hive.openBox<dynamic>(boxName),
    );
    final service = FinanceStatisticsService(repository);

    final start = DateTime(2026, 1, 1);
    final end = DateTime(2026, 1, 31);

    final inRange = <Transaction>[
      Transaction(
        id: 'jan_income_usd',
        title: 'Salary',
        amount: 1000,
        type: 'income',
        transactionDate: DateTime(2026, 1, 2, 9),
        currency: 'USD',
      ),
      Transaction(
        id: 'jan_income_eur',
        title: 'Bonus',
        amount: 300,
        type: 'income',
        transactionDate: DateTime(2026, 1, 12, 10),
        currency: 'EUR',
      ),
      Transaction(
        id: 'jan_expense_usd',
        title: 'Rent',
        amount: 600,
        type: 'expense',
        transactionDate: DateTime(2026, 1, 5, 15),
        currency: 'USD',
      ),
      Transaction(
        id: 'jan_expense_eur',
        title: 'Utilities',
        amount: 80,
        type: 'expense',
        transactionDate: DateTime(2026, 1, 5, 18),
        currency: 'EUR',
      ),
      Transaction(
        id: 'jan_expense_null_currency',
        title: 'Taxi',
        amount: 40,
        type: 'expense',
        transactionDate: DateTime(2026, 1, 20, 8),
        currency: null,
      ),
      Transaction(
        id: 'jan_transfer',
        title: 'Wallet transfer',
        amount: 200,
        type: 'transfer',
        transactionDate: DateTime(2026, 1, 11, 13),
        currency: 'USD',
      ),
      Transaction(
        id: 'jan_balance_adjustment',
        title: 'Balance correction',
        amount: 999,
        type: 'income',
        transactionDate: DateTime(2026, 1, 21, 11),
        currency: 'USD',
        isBalanceAdjustment: true,
      ),
    ];

    final outOfRange = <Transaction>[
      Transaction(
        id: 'dec_expense',
        title: 'December expense',
        amount: 50,
        type: 'expense',
        transactionDate: DateTime(2025, 12, 31, 20),
        currency: 'USD',
      ),
      Transaction(
        id: 'feb_income',
        title: 'February income',
        amount: 400,
        type: 'income',
        transactionDate: DateTime(2026, 2, 1, 9),
        currency: 'USD',
      ),
    ];

    for (final tx in [...inRange, ...outOfRange]) {
      await repository.createTransaction(tx);
    }

    final stats = await service.getIncomeExpenseStats(
      startDate: start,
      endDate: end,
      defaultCurrency: 'USD',
    );
    final trend = await service.getDailySpendingTrend(
      startDate: start,
      endDate: end,
    );

    final all = await repository.getAllTransactions();
    final rawInRange = _rawRangeScan(all, start, end);
    final rawStats = _rawIncomeExpenseStats(rawInRange, defaultCurrency: 'USD');
    final rawTrend = _rawDailySpendingTrend(rawInRange);

    expect(stats['totalIncomeByCurrency'], rawStats['totalIncomeByCurrency']);
    expect(stats['totalExpenseByCurrency'], rawStats['totalExpenseByCurrency']);
    expect(stats['incomeCount'], rawStats['incomeCount']);
    expect(stats['expenseCount'], rawStats['expenseCount']);
    expect(stats['totalIncome'], rawStats['totalIncome']);
    expect(stats['totalExpense'], rawStats['totalExpense']);
    expect(trend, rawTrend);
  });
}

List<Transaction> _rawRangeScan(
  Iterable<Transaction> all,
  DateTime startDate,
  DateTime endDate,
) {
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

  return all.where((tx) {
    final txDate = tx.transactionDate.toLocal();
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

Map<String, dynamic> _rawIncomeExpenseStats(
  Iterable<Transaction> inRange, {
  required String defaultCurrency,
}) {
  final income = inRange.where((t) => t.isIncome && !t.isBalanceAdjustment);
  final expense = inRange.where((t) => t.isExpense && !t.isBalanceAdjustment);

  final totalIncomeByCurrency = <String, double>{};
  final totalExpenseByCurrency = <String, double>{};

  for (final tx in income) {
    final cur = tx.currency ?? defaultCurrency;
    totalIncomeByCurrency[cur] = (totalIncomeByCurrency[cur] ?? 0) + tx.amount;
  }
  for (final tx in expense) {
    final cur = tx.currency ?? defaultCurrency;
    totalExpenseByCurrency[cur] =
        (totalExpenseByCurrency[cur] ?? 0) + tx.amount;
  }

  final currencies = {
    ...totalIncomeByCurrency.keys,
    ...totalExpenseByCurrency.keys,
  };
  double totalIncome = 0;
  double totalExpense = 0;
  if (currencies.length == 1) {
    final single = currencies.first;
    totalIncome = totalIncomeByCurrency[single] ?? 0;
    totalExpense = totalExpenseByCurrency[single] ?? 0;
  }

  return <String, dynamic>{
    'totalIncomeByCurrency': totalIncomeByCurrency,
    'totalExpenseByCurrency': totalExpenseByCurrency,
    'incomeCount': income.length,
    'expenseCount': expense.length,
    'totalIncome': totalIncome,
    'totalExpense': totalExpense,
  };
}

Map<DateTime, double> _rawDailySpendingTrend(Iterable<Transaction> inRange) {
  final expenses = inRange.where((t) => t.isExpense && !t.isBalanceAdjustment);
  final daily = <DateTime, double>{};
  for (final expense in expenses) {
    final day = DateTime(
      expense.transactionDate.year,
      expense.transactionDate.month,
      expense.transactionDate.day,
    );
    daily[day] = (daily[day] ?? 0) + expense.amount;
  }
  return daily;
}
