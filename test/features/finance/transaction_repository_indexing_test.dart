import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:life_manager/features/finance/data/models/transaction.dart';
import 'package:life_manager/features/finance/data/repositories/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('finance_tx_repo_phase2_');
    Hive.init(hiveDir.path);
    _registerAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  group('TransactionRepository indexing', () {
    test(
      'rebuilds date indexes for existing records and reads by date',
      () async {
        final now = DateTime.now();
        final date = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 3));
        final box = await Hive.openBox<Transaction>(
          TransactionRepository.boxName,
        );
        await box.put(
          'legacy_tx',
          Transaction(
            id: 'legacy_tx',
            title: 'Legacy',
            amount: 12,
            type: 'expense',
            transactionDate: date,
            currency: 'USD',
          ),
        );

        final repository = _buildRepository();
        final transactions = await repository.getTransactionsForDate(date);
        expect(transactions.map((t) => t.id), contains('legacy_tx'));

        final indexBox = await Hive.openBox<dynamic>(
          'finance_tx_date_index_v1',
        );
        final indexedIds =
            (indexBox.get(_dateKey(date)) as List?)?.cast<String>() ??
            const <String>[];
        expect(indexedIds, contains('legacy_tx'));
      },
    );

    test(
      'keeps indexes and summary statistics aligned with write, update, delete',
      () async {
        final now = DateTime.now();
        final dateA = DateTime(now.year, now.month, now.day);
        final dateB = dateA.add(const Duration(days: 1));

        final txIncome = Transaction(
          id: 'tx_income',
          title: 'Salary',
          amount: 100,
          type: 'income',
          transactionDate: dateA,
          currency: 'USD',
          isCleared: false,
        );
        final txExpense = Transaction(
          id: 'tx_expense',
          title: 'Groceries',
          amount: 40,
          type: 'expense',
          transactionDate: dateA,
          currency: 'USD',
          needsReview: true,
          isCleared: false,
        );
        final txTransfer = Transaction(
          id: 'tx_transfer',
          title: 'Move money',
          amount: 25,
          type: 'transfer',
          transactionDate: dateA,
          currency: 'USD',
          isCleared: true,
        );
        final txBalanceAdjustment = Transaction(
          id: 'tx_adjustment',
          title: 'Adjustment',
          amount: 500,
          type: 'income',
          transactionDate: dateA,
          currency: null,
          isBalanceAdjustment: true,
          isCleared: false,
        );
        final txNullCurrencyExpense = Transaction(
          id: 'tx_null_currency',
          title: 'Null currency expense',
          amount: 15,
          type: 'expense',
          transactionDate: dateA,
          currency: null,
          isCleared: false,
        );

        final repository = _buildRepository();
        await repository.createTransaction(txIncome);
        await repository.createTransaction(txExpense);
        await repository.createTransaction(txTransfer);
        await repository.createTransaction(txBalanceAdjustment);
        await repository.createTransaction(txNullCurrencyExpense);

        await repository.updateTransaction(
          txIncome.copyWith(
            amount: 60,
            type: 'expense',
            transactionDate: dateB,
          ),
        );
        await repository.deleteTransaction(txTransfer.id);

        final dateATransactions = await repository.getTransactionsForDate(
          dateA,
        );
        final dateBTransactions = await repository.getTransactionsForDate(
          dateB,
        );
        expect(dateATransactions.map((t) => t.id).toSet(), {
          'tx_expense',
          'tx_adjustment',
          'tx_null_currency',
        });
        expect(dateBTransactions.map((t) => t.id).toSet(), {'tx_income'});

        final all = await repository.getAllTransactions();
        final stats = await repository.getTransactionStatistics(
          defaultCurrency: 'USD',
        );
        final raw = _rawStats(all, defaultCurrency: 'USD');
        expect(stats, raw);
      },
    );

    test(
      'bootstrap indexes recent window and safely scans older dates',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final recentDate = today.subtract(const Duration(days: 4));
        final oldDate = today.subtract(const Duration(days: 90));

        final box = await Hive.openBox<Transaction>(
          TransactionRepository.boxName,
        );
        await box.put(
          'recent_tx',
          Transaction(
            id: 'recent_tx',
            title: 'Recent',
            amount: 1,
            type: 'expense',
            transactionDate: recentDate,
            currency: 'USD',
          ),
        );
        await box.put(
          'old_tx',
          Transaction(
            id: 'old_tx',
            title: 'Old',
            amount: 1,
            type: 'expense',
            transactionDate: oldDate,
            currency: 'USD',
          ),
        );

        final repository = _buildRepository();
        final recent = await repository.getTransactionsForDate(recentDate);
        final old = await repository.getTransactionsForDate(oldDate);

        expect(recent.map((t) => t.id), contains('recent_tx'));
        expect(old.map((t) => t.id), contains('old_tx'));

        final indexBox = await Hive.openBox<dynamic>(
          'finance_tx_date_index_v1',
        );
        final recentIds =
            (indexBox.get(_dateKey(recentDate)) as List?)?.cast<String>() ??
            const <String>[];
        final oldIds =
            (indexBox.get(_dateKey(oldDate)) as List?)?.cast<String>() ??
            const <String>[];

        expect(recentIds, contains('recent_tx'));
        expect(oldIds, isEmpty);
      },
    );

    test(
      'stores daily summaries per currency using YYYYMMDD|currency keys',
      () async {
        final now = DateTime.now();
        final date = DateTime(now.year, now.month, now.day);
        final dateKey = _dateKey(date);

        final repository = _buildRepository();
        await repository.createTransaction(
          Transaction(
            id: 'usd_income',
            title: 'USD income',
            amount: 120,
            type: 'income',
            transactionDate: date,
            currency: 'USD',
            isCleared: false,
          ),
        );
        await repository.createTransaction(
          Transaction(
            id: 'eur_expense',
            title: 'EUR expense',
            amount: 55,
            type: 'expense',
            transactionDate: date,
            currency: 'EUR',
            isCleared: true,
          ),
        );
        await repository.createTransaction(
          Transaction(
            id: 'null_expense',
            title: 'Null expense',
            amount: 15,
            type: 'expense',
            transactionDate: date,
            currency: null,
            isCleared: false,
          ),
        );

        final summaryBox = await Hive.openBox<dynamic>(
          'finance_daily_summary_v1',
        );
        final usdKey = '$dateKey|USD';
        final eurKey = '$dateKey|EUR';
        const nullCurrencyKeySuffix = '__NULL_CURRENCY__';
        final nullKey = '$dateKey|$nullCurrencyKeySuffix';

        expect(summaryBox.containsKey(usdKey), isTrue);
        expect(summaryBox.containsKey(eurKey), isTrue);
        expect(summaryBox.containsKey(nullKey), isTrue);

        final usdSummary =
            (summaryBox.get(usdKey) as Map?) ?? const <String, dynamic>{};
        final eurSummary =
            (summaryBox.get(eurKey) as Map?) ?? const <String, dynamic>{};
        final nullSummary =
            (summaryBox.get(nullKey) as Map?) ?? const <String, dynamic>{};

        expect(_asInt(usdSummary['income_count']), 1);
        expect(_asDouble(usdSummary['income_amount']), 120);
        expect(_asInt(eurSummary['expense_count']), 1);
        expect(_asDouble(eurSummary['expense_amount']), 55);
        expect(_asInt(nullSummary['expense_count']), 1);
        expect(_asDouble(nullSummary['expense_amount']), 15);
      },
    );
  });
}

TransactionRepository _buildRepository() {
  return TransactionRepository(
    transactionBoxOpener: () =>
        Hive.openBox<Transaction>(TransactionRepository.boxName),
    dynamicBoxOpener: (boxName) => Hive.openBox<dynamic>(boxName),
  );
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(20)) {
    Hive.registerAdapter(TransactionAdapter());
  }
}

Map<String, dynamic> _rawStats(
  Iterable<Transaction> transactions, {
  required String defaultCurrency,
}) {
  final income = transactions.where(
    (t) => t.isIncome && !t.isBalanceAdjustment,
  );
  final expenses = transactions.where(
    (t) => t.isExpense && !t.isBalanceAdjustment,
  );

  final totalIncomeByCurrency = <String, double>{};
  final totalExpenseByCurrency = <String, double>{};

  for (final tx in income) {
    final currency = tx.currency ?? defaultCurrency;
    totalIncomeByCurrency[currency] =
        (totalIncomeByCurrency[currency] ?? 0) + tx.amount;
  }
  for (final tx in expenses) {
    final currency = tx.currency ?? defaultCurrency;
    totalExpenseByCurrency[currency] =
        (totalExpenseByCurrency[currency] ?? 0) + tx.amount;
  }

  return <String, dynamic>{
    'total': transactions.length,
    'income': income.length,
    'expense': expenses.length,
    'transfer': transactions.where((t) => t.isTransfer).length,
    'totalIncomeByCurrency': totalIncomeByCurrency,
    'totalExpenseByCurrency': totalExpenseByCurrency,
    'needsReview': transactions.where((t) => t.needsReview).length,
    'uncleared': transactions.where((t) => !t.isCleared).length,
  };
}

String _dateKey(DateTime date) {
  final yyyy = date.year.toString().padLeft(4, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '$yyyy$mm$dd';
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
