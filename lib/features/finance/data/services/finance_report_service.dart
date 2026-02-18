import 'package:intl/intl.dart';

import '../models/account.dart';
import '../models/debt.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/transaction_category_repository.dart';
import '../repositories/debt_repository.dart';
import '../repositories/bill_repository.dart';
import '../repositories/savings_goal_repository.dart';
import 'daily_balance_service.dart';
import 'budget_tracker_service.dart';
import 'finance_statistics_service.dart';
import 'finance_report_models.dart';

/// Service that aggregates finance data into report-ready structures for
/// Daily, Weekly, Monthly, and Yearly report pages.
class FinanceReportService {
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;
  final TransactionCategoryRepository _categoryRepo;
  final DailyBalanceService _dailyBalanceService;
  final BudgetTrackerService _budgetTracker;
  final DebtRepository _debtRepo;
  final BillRepository _billRepo;
  final SavingsGoalRepository _savingsRepo;
  final FinanceStatisticsService _statsService;

  FinanceReportService({
    required TransactionRepository transactionRepo,
    required AccountRepository accountRepo,
    required TransactionCategoryRepository categoryRepo,
    required DailyBalanceService dailyBalanceService,
    required BudgetTrackerService budgetTracker,
    required DebtRepository debtRepo,
    required BillRepository billRepo,
    required SavingsGoalRepository savingsRepo,
    required FinanceStatisticsService statsService,
  })  : _transactionRepo = transactionRepo,
        _accountRepo = accountRepo,
        _categoryRepo = categoryRepo,
        _dailyBalanceService = dailyBalanceService,
        _budgetTracker = budgetTracker,
        _debtRepo = debtRepo,
        _billRepo = billRepo,
        _savingsRepo = savingsRepo,
        _statsService = statsService;

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static DateTime _startOfWeek(DateTime d) {
    final normalized = _dateOnly(d);
    final weekday = normalized.weekday;
    return normalized.subtract(Duration(days: weekday - 1));
  }

  Future<DailyReportData> getDailyReport(
    DateTime date,
    String currency,
  ) async {
    final dateOnly = _dateOnly(date);
    final dayBefore = dateOnly.subtract(const Duration(days: 1));

    final openingBalances =
        await _dailyBalanceService.getTotalBalanceByCurrencyForDate(dayBefore);
    final closingBalances =
        await _dailyBalanceService.getTotalBalanceByCurrencyForDate(dateOnly);

    final openingBalance = openingBalances[currency] ?? 0.0;
    final closingBalance = closingBalances[currency] ?? 0.0;
    final netChange = closingBalance - openingBalance;

    final startOfDay = dateOnly;
    final endOfDay = DateTime(
      dateOnly.year,
      dateOnly.month,
      dateOnly.day,
      23,
      59,
      59,
      999,
    );
    final transactions = await _transactionRepo.getTransactionsInRange(
      startOfDay,
      endOfDay,
    );

    final income = transactions
        .where((t) => t.isIncome && !t.isBalanceAdjustment)
        .toList();
    final expenses = transactions
        .where((t) => t.isExpense && !t.isBalanceAdjustment)
        .toList();
    final transfers = transactions.where((t) => t.isTransfer).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    final hourlyIncome = <int, double>{};
    final hourlyExpense = <int, double>{};

    for (final t in income) {
      if ((t.currency ?? currency) != currency) continue;
      totalIncome += t.amount;
      final hour = t.transactionTimeHour ?? 12;
      hourlyIncome[hour] = (hourlyIncome[hour] ?? 0) + t.amount;
    }
    for (final t in expenses) {
      if ((t.currency ?? currency) != currency) continue;
      totalExpense += t.amount;
      final hour = t.transactionTimeHour ?? 12;
      hourlyExpense[hour] = (hourlyExpense[hour] ?? 0) + t.amount;
    }

    final savingsRate = totalIncome > 0
        ? ((totalIncome - totalExpense) / totalIncome * 100)
        : 0.0;

    final expenseByCat = <String, double>{};
    for (final t in expenses) {
      if ((t.currency ?? currency) != currency) continue;
      final catId = t.categoryId ?? 'uncategorized';
      expenseByCat[catId] = (expenseByCat[catId] ?? 0) + t.amount;
    }
    final incomeByCat = <String, double>{};
    for (final t in income) {
      if ((t.currency ?? currency) != currency) continue;
      final catId = t.categoryId ?? 'uncategorized';
      incomeByCat[catId] = (incomeByCat[catId] ?? 0) + t.amount;
    }

    final categories = await _categoryRepo.getAllCategories();
    final catMap = {for (final c in categories) c.id: c.name};

    final expenseCategories = _buildCategoryItems(
      expenseByCat,
      totalExpense,
      catMap,
    );
    final incomeCategories = _buildCategoryItems(
      incomeByCat,
      totalIncome,
      catMap,
    );

    final accounts = await _accountRepo.getAccountsInTotal();
    final accountChanges = <ReportAccountChange>[];
    for (final acc in accounts.where((a) => a.currency == currency)) {
      final dayStartBal = await _getAccountBalanceAtDate(acc, dayBefore);
      final dayEndBal = await _getAccountBalanceAtDate(acc, dateOnly);
      final delta = dayEndBal - dayStartBal;
      accountChanges.add(ReportAccountChange(
        accountId: acc.id,
        accountName: acc.name,
        currency: acc.currency,
        openingBalance: dayStartBal,
        closingBalance: dayEndBal,
        delta: delta,
      ));
    }

    return DailyReportData(
      date: dateOnly,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
      netChange: netChange,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      savingsRate: savingsRate,
      incomeCount: income.length,
      expenseCount: expenses.length,
      transferCount: transfers.length,
      hourlyIncome: hourlyIncome,
      hourlyExpense: hourlyExpense,
      expenseCategories: expenseCategories,
      incomeCategories: incomeCategories,
      accountChanges: accountChanges,
      incomeTransactions: income,
      expenseTransactions: expenses,
      transferTransactions: transfers,
    );
  }

  Future<double> _getAccountBalanceAtDate(Account account, DateTime date) async {
    final allAccounts = await _accountRepo.getAccountsInTotal();
    final relevant = allAccounts
        .where((a) =>
            a.currency == account.currency &&
            !a.createdAt.isAfter(DateTime(date.year, date.month, date.day, 23, 59, 59)))
        .toList();
    if (relevant.isEmpty) return 0;
    final txUpTo = await _transactionRepo.getTransactionsUpToDate(
      DateTime(date.year, date.month, date.day, 23, 59, 59),
    );
    final balMap = {
      for (final a in relevant) a.id: a.initialBalance,
    };
    for (final tx in txUpTo) {
      final accId = tx.accountId;
      final toId = tx.toAccountId;
      if (tx.type == 'income' && accId != null && balMap.containsKey(accId)) {
        balMap[accId] = (balMap[accId] ?? 0) + tx.amount;
      } else if (tx.type == 'expense' && accId != null && balMap.containsKey(accId)) {
        balMap[accId] = (balMap[accId] ?? 0) - tx.amount;
      } else if (tx.type == 'transfer') {
        if (accId != null && balMap.containsKey(accId)) {
          balMap[accId] = (balMap[accId] ?? 0) - tx.amount;
        }
        if (toId != null && balMap.containsKey(toId)) {
          balMap[toId] = (balMap[toId] ?? 0) + tx.amount;
        }
      }
    }
    return balMap[account.id] ?? 0;
  }

  List<ReportCategoryItem> _buildCategoryItems(
    Map<String, double> byCat,
    double total,
    Map<String, String> catMap,
  ) {
    if (total <= 0) return [];
    final entries = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((e) => ReportCategoryItem(
              categoryId: e.key,
              categoryName: catMap[e.key] ?? e.key,
              amount: e.value,
              percentage: (e.value / total * 100),
            ))
        .toList();
  }

  Future<WeeklyReportData> getWeeklyReport(
    DateTime weekStart,
    String currency,
  ) async {
    final start = _dateOnly(weekStart);
    final end = start.add(const Duration(days: 6));

    final stats = await _statsService.getIncomeExpenseStats(
      startDate: start,
      endDate: end,
      defaultCurrency: currency,
    );
    final totalIncome = (stats['totalIncome'] as num?)?.toDouble() ?? 0;
    final totalExpense = (stats['totalExpense'] as num?)?.toDouble() ?? 0;
    final net = totalIncome - totalExpense;
    final savingsRate = (stats['savingsRate'] as num?)?.toDouble() ?? 0;

    final prevWeekStart = start.subtract(const Duration(days: 7));
    final prevWeekEnd = prevWeekStart.add(const Duration(days: 6));
    double? incomeChange;
    double? expenseChange;
    try {
      final prevStats = await _statsService.getIncomeExpenseStats(
        startDate: prevWeekStart,
        endDate: prevWeekEnd,
        defaultCurrency: currency,
      );
      final prevIncome = (prevStats['totalIncome'] as num?)?.toDouble() ?? 0;
      final prevExpense = (prevStats['totalExpense'] as num?)?.toDouble() ?? 0;
      if (prevIncome > 0) {
        incomeChange = ((totalIncome - prevIncome) / prevIncome * 100);
      }
      if (prevExpense > 0) {
        expenseChange = ((totalExpense - prevExpense) / prevExpense * 100);
      }
    } catch (_) {}

    final dailySummaries = <DailySummary>[];
    final dailyClosingBalances = <double>[];
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (var i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final dayTx = await _transactionRepo.getTransactionsInRange(d, d);
      double dayIncome = 0;
      double dayExpense = 0;
      for (final t in dayTx) {
        if ((t.currency ?? currency) != currency) continue;
        if (t.isIncome && !t.isBalanceAdjustment) dayIncome += t.amount;
        if (t.isExpense && !t.isBalanceAdjustment) dayExpense += t.amount;
      }
      final closing = await _dailyBalanceService.getTotalBalanceByCurrencyForDate(d);
      final bal = closing[currency] ?? 0;
      dailySummaries.add(DailySummary(
        date: d,
        label: dayLabels[i],
        income: dayIncome,
        expense: dayExpense,
        closingBalance: bal,
      ));
      dailyClosingBalances.add(bal);
    }

    final spendingByCat = await _statsService.getSpendingByCategory(
      startDate: start,
      endDate: end,
    );
    final categories = await _categoryRepo.getAllCategories();
    final catMap = {for (final c in categories) c.id: c.name};
    final topExpenseCategories = _buildCategoryItems(
      spendingByCat,
      totalExpense,
      catMap,
    );

    var busiestDay = 0.0;
    var quietestDay = double.infinity;
    String? busiestLabel;
    String? quietestLabel;
    for (final s in dailySummaries) {
      final total = s.income + s.expense;
      if (total > busiestDay) {
        busiestDay = total;
        busiestLabel = s.label;
      }
      if (total < quietestDay) {
        quietestDay = total;
        quietestLabel = s.label;
      }
    }

    final transactions = await _transactionRepo.getTransactionsInRange(start, end);
    final expenseTx = transactions
        .where((t) => t.isExpense && !t.isBalanceAdjustment && (t.currency ?? currency) == currency)
        .toList();
    final incomeTx = transactions
        .where((t) => t.isIncome && !t.isBalanceAdjustment && (t.currency ?? currency) == currency)
        .toList();

    double? highestExpense;
    double? highestIncome;
    if (expenseTx.isNotEmpty) {
      expenseTx.sort((a, b) => b.amount.compareTo(a.amount));
      highestExpense = expenseTx.first.amount;
    }
    if (incomeTx.isNotEmpty) {
      incomeTx.sort((a, b) => b.amount.compareTo(a.amount));
      highestIncome = incomeTx.first.amount;
    }

    final avgDaily = totalExpense / 7;
    final totalCount = transactions.length;
    final avgPerTx = totalCount > 0
        ? (totalIncome + totalExpense) / totalCount
        : 0.0;

    return WeeklyReportData(
      weekStart: start,
      weekEnd: end,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      net: net,
      savingsRate: savingsRate,
      incomeChangeVsPrevWeek: incomeChange,
      expenseChangeVsPrevWeek: expenseChange,
      dailySummaries: dailySummaries,
      dailyClosingBalances: dailyClosingBalances,
      topExpenseCategories: topExpenseCategories,
      busiestDay: busiestLabel,
      quietestDay: quietestLabel,
      averageDailySpending: avgDaily,
      totalTransactions: totalCount,
      avgPerTransaction: avgPerTx,
      highestSingleExpense: highestExpense,
      highestSingleIncome: highestIncome,
    );
  }

  Future<MonthlyReportData> getMonthlyReport(
    DateTime month,
    String currency,
  ) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final stats = await _statsService.getIncomeExpenseStats(
      startDate: start,
      endDate: end,
      defaultCurrency: currency,
    );
    final totalIncome = (stats['totalIncome'] as num?)?.toDouble() ?? 0;
    final totalExpense = (stats['totalExpense'] as num?)?.toDouble() ?? 0;
    final net = totalIncome - totalExpense;
    final savingsRate = (stats['savingsRate'] as num?)?.toDouble() ?? 0;

    final prevMonth = DateTime(month.year, month.month - 1, 1);
    final prevEnd = DateTime(month.year, month.month, 0);
    double? incomeChange;
    double? expenseChange;
    try {
      final prevStats = await _statsService.getIncomeExpenseStats(
        startDate: prevMonth,
        endDate: prevEnd,
        defaultCurrency: currency,
      );
      final prevIncome = (prevStats['totalIncome'] as num?)?.toDouble() ?? 0;
      final prevExpense = (prevStats['totalExpense'] as num?)?.toDouble() ?? 0;
      if (prevIncome > 0) incomeChange = ((totalIncome - prevIncome) / prevIncome * 100);
      if (prevExpense > 0) expenseChange = ((totalExpense - prevExpense) / prevExpense * 100);
    } catch (_) {}

    final dailyClosingBalances = <double>[];
    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      final bal = await _dailyBalanceService.getTotalBalanceByCurrencyForDate(d);
      dailyClosingBalances.add(bal[currency] ?? 0);
    }

    final weeklySummaries = <WeeklySummary>[];
    var wStart = start;
    while (!wStart.isAfter(end)) {
      var wEnd = wStart.add(const Duration(days: 6));
      if (wEnd.isAfter(end)) wEnd = end;
      final wTx = await _transactionRepo.getTransactionsInRange(wStart, wEnd);
      double wIncome = 0;
      double wExpense = 0;
      for (final t in wTx) {
        if ((t.currency ?? currency) != currency) continue;
        if (t.isIncome && !t.isBalanceAdjustment) wIncome += t.amount;
        if (t.isExpense && !t.isBalanceAdjustment) wExpense += t.amount;
      }
      weeklySummaries.add(WeeklySummary(
        weekStart: wStart,
        label: 'W${((wStart.day - 1) ~/ 7) + 1}',
        income: wIncome,
        expense: wExpense,
      ));
      wStart = wStart.add(const Duration(days: 7));
    }

    final spendingByCat = await _statsService.getSpendingByCategory(
      startDate: start,
      endDate: end,
    );
    final categories = await _categoryRepo.getAllCategories();
    final catMap = {for (final c in categories) c.id: c.name};
    final expenseCategories = _buildCategoryItems(
      spendingByCat,
      totalExpense,
      catMap,
    );

    final budgetStatuses = <ReportBudgetStatus>[];
    final statuses = await _budgetTracker.getAllBudgetStatuses();
    for (final s in statuses) {
      final amount = (s['amount'] as num?)?.toDouble() ?? 0;
      final spent = (s['currentSpent'] as num?)?.toDouble() ?? 0;
      final pct = (s['percentage'] as num?)?.toDouble() ?? 0;
      final exceeded = s['isExceeded'] as bool? ?? false;
      budgetStatuses.add(ReportBudgetStatus(
        budgetId: s['id'] as String? ?? '',
        budgetName: s['name'] as String? ?? '',
        limit: amount,
        spent: spent,
        percentage: pct,
        isExceeded: exceeded,
      ));
    }

    final bills = await _billRepo.getAllBills();
    var billsPaidCount = 0;
    var billsUpcomingCount = 0;
    var billsTotalCost = 0.0;
    for (final b in bills.where((x) => x.isActive)) {
      if (b.lastPaidDate != null) {
        final pd = _dateOnly(b.lastPaidDate!);
        if (!pd.isBefore(start) && !pd.isAfter(end)) {
          billsPaidCount++;
        }
      }
      if (b.nextDueDate != null) {
        final nd = _dateOnly(b.nextDueDate!);
        if (!nd.isBefore(start) && !nd.isAfter(end)) {
          billsUpcomingCount++;
          billsTotalCost += b.defaultAmount;
        }
      }
    }

    var debtPayments = 0.0;
    final debts = await _debtRepo.getAllDebts(direction: DebtDirection.owed);
    for (final d in debts) {
      for (final p in d.paymentHistory) {
        final pd = _dateOnly(p.paidAt);
        if (!pd.isBefore(start) && !pd.isAfter(end)) {
          debtPayments += p.amount;
        }
      }
    }

    var savingsContrib = 0.0;
    final goals = await _savingsRepo.getActiveGoals();
    for (final g in goals) {
      for (final c in g.contributionHistory) {
        final cd = _dateOnly(c.contributedAt);
        if (!cd.isBefore(start) && !cd.isAfter(end)) {
          savingsContrib += c.amount;
        }
      }
    }

    final transactions = await _transactionRepo.getTransactionsInRange(start, end);
    final expenses = transactions
        .where((t) => t.isExpense && !t.isBalanceAdjustment && (t.currency ?? currency) == currency)
        .toList();
    final incomes = transactions
        .where((t) => t.isIncome && !t.isBalanceAdjustment && (t.currency ?? currency) == currency)
        .toList();
    expenses.sort((a, b) => b.amount.compareTo(a.amount));
    incomes.sort((a, b) => b.amount.compareTo(a.amount));
    final topExpenses = expenses.take(5).toList();
    final topIncomes = incomes.take(5).toList();

    return MonthlyReportData(
      month: start,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      net: net,
      savingsRate: savingsRate,
      incomeChangeVsPrevMonth: incomeChange,
      expenseChangeVsPrevMonth: expenseChange,
      dailyClosingBalances: dailyClosingBalances,
      weeklySummaries: weeklySummaries,
      expenseCategories: expenseCategories,
      budgetStatuses: budgetStatuses,
      billsPaidCount: billsPaidCount,
      billsUpcomingCount: billsUpcomingCount,
      billsTotalCost: billsTotalCost,
      debtPaymentsThisMonth: debtPayments,
      savingsContributionsThisMonth: savingsContrib,
      topExpenses: topExpenses,
      topIncomes: topIncomes,
    );
  }

  Future<YearlyReportData> getYearlyReport(int year, String currency) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);

    final stats = await _statsService.getIncomeExpenseStats(
      startDate: start,
      endDate: end,
      defaultCurrency: currency,
    );
    final totalIncome = (stats['totalIncome'] as num?)?.toDouble() ?? 0;
    final totalExpense = (stats['totalExpense'] as num?)?.toDouble() ?? 0;
    final net = totalIncome - totalExpense;
    final savingsRate = (stats['savingsRate'] as num?)?.toDouble() ?? 0;

    final prevStart = DateTime(year - 1, 1, 1);
    final prevEnd = DateTime(year - 1, 12, 31);
    double? incomeChange;
    double? expenseChange;
    try {
      final prevStats = await _statsService.getIncomeExpenseStats(
        startDate: prevStart,
        endDate: prevEnd,
        defaultCurrency: currency,
      );
      final prevIncome = (prevStats['totalIncome'] as num?)?.toDouble() ?? 0;
      final prevExpense = (prevStats['totalExpense'] as num?)?.toDouble() ?? 0;
      if (prevIncome > 0) incomeChange = ((totalIncome - prevIncome) / prevIncome * 100);
      if (prevExpense > 0) expenseChange = ((totalExpense - prevExpense) / prevExpense * 100);
    } catch (_) {}

    final monthlySummaries = <MonthlySummary>[];
    final monthlyClosingBalances = <double>[];
    final monthlySavingsRates = <double>[];
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    for (var m = 1; m <= 12; m++) {
      final mStart = DateTime(year, m, 1);
      final mEnd = DateTime(year, m + 1, 0);
      final mTx = await _transactionRepo.getTransactionsInRange(mStart, mEnd);
      double mIncome = 0;
      double mExpense = 0;
      for (final t in mTx) {
        if ((t.currency ?? currency) != currency) continue;
        if (t.isIncome && !t.isBalanceAdjustment) mIncome += t.amount;
        if (t.isExpense && !t.isBalanceAdjustment) mExpense += t.amount;
      }
      monthlySummaries.add(MonthlySummary(
        month: m,
        label: monthNames[m - 1],
        income: mIncome,
        expense: mExpense,
      ));
      final lastDay = DateTime(year, m, mEnd.day);
      final bal = await _dailyBalanceService.getTotalBalanceByCurrencyForDate(lastDay);
      monthlyClosingBalances.add(bal[currency] ?? 0);
      final sr = mIncome > 0 ? ((mIncome - mExpense) / mIncome * 100) : 0.0;
      monthlySavingsRates.add(sr);
    }

    final spendingByCat = await _statsService.getSpendingByCategory(
      startDate: start,
      endDate: end,
    );
    final categories = await _categoryRepo.getAllCategories();
    final catMap = {for (final c in categories) c.id: c.name};
    final expenseCategories = _buildCategoryItems(
      spendingByCat,
      totalExpense,
      catMap,
    );

    var bestIncomeAmount = 0.0;
    String? bestIncomeMonthName;
    var worstExpenseMonth = double.infinity;
    var worstExpenseAmount = 0.0;
    String? worstExpenseMonthName;
    var bestSavingsRate = -1.0;
    String? bestSavingsMonthName;

    for (var i = 0; i < monthlySummaries.length; i++) {
      final s = monthlySummaries[i];
      if (s.income > bestIncomeAmount) {
        bestIncomeAmount = s.income;
        bestIncomeMonthName = s.label;
      }
      if (s.expense > 0 && s.expense < worstExpenseMonth) {
        worstExpenseMonth = s.expense;
        worstExpenseAmount = s.expense;
        worstExpenseMonthName = s.label;
      }
      if (monthlySavingsRates[i] > bestSavingsRate) {
        bestSavingsRate = monthlySavingsRates[i];
        bestSavingsMonthName = s.label;
      }
    }
    if (worstExpenseMonth == double.infinity) worstExpenseMonthName = null;

    var debtEnd = 0.0;
    var totalDebtPayments = 0.0;
    final debts = await _debtRepo.getAllDebts(direction: DebtDirection.owed);
    for (final d in debts) {
      if (d.currency != currency) continue;
      debtEnd += d.currentBalance;
      for (final p in d.paymentHistory) {
        if (p.paidAt.year == year) totalDebtPayments += p.amount;
      }
    }
    final debtStart = debtEnd + totalDebtPayments;

    var savingsStart = 0.0;
    var savingsEnd = 0.0;
    var totalSavingsContrib = 0.0;
    final goals = await _savingsRepo.getActiveGoals();
    for (final g in goals) {
      if (g.currency != currency) continue;
      savingsEnd += g.savedAmount;
      for (final c in g.contributionHistory) {
        if (c.contributedAt.year == year) totalSavingsContrib += c.amount;
      }
    }
    savingsStart = savingsEnd - totalSavingsContrib;

    final transactions = await _transactionRepo.getTransactionsInRange(start, end);
    final paymentMethods = <String, int>{};
    for (final t in transactions) {
      final pm = t.paymentMethod ?? 'unknown';
      paymentMethods[pm] = (paymentMethods[pm] ?? 0) + 1;
    }
    String? mostUsed;
    var maxCount = 0;
    for (final e in paymentMethods.entries) {
      if (e.value > maxCount) {
        maxCount = e.value;
        mostUsed = e.key;
      }
    }

    return YearlyReportData(
      year: year,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      net: net,
      savingsRate: savingsRate,
      incomeChangeVsPrevYear: incomeChange,
      expenseChangeVsPrevYear: expenseChange,
      monthlySummaries: monthlySummaries,
      monthlyClosingBalances: monthlyClosingBalances,
      monthlySavingsRates: monthlySavingsRates,
      expenseCategories: expenseCategories,
      bestIncomeMonth: bestIncomeMonthName,
      bestIncomeAmount: bestIncomeAmount > 0 ? bestIncomeAmount : null,
      worstExpenseMonth: worstExpenseMonthName,
      worstExpenseAmount: worstExpenseAmount > 0 ? worstExpenseAmount : null,
      bestSavingsMonth: bestSavingsMonthName,
      bestSavingsRate: bestSavingsRate >= 0 ? bestSavingsRate : null,
      debtStartOfYear: debtStart,
      debtEndOfYear: debtEnd,
      totalDebtPayments: totalDebtPayments,
      savingsStartOfYear: savingsStart,
      savingsEndOfYear: savingsEnd,
      totalSavingsContributions: totalSavingsContrib,
      totalTransactions: transactions.length,
      avgMonthlySpend: totalExpense / 12,
      avgMonthlyIncome: totalIncome / 12,
      mostUsedPaymentMethod: mostUsed != 'unknown' ? mostUsed : null,
    );
  }

  /// Quick summary for hub screen
  Future<Map<String, Map<String, dynamic>>> getHubSummaries(String currency) async {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final weekStart = _startOfWeek(now);
    final monthStart = DateTime(now.year, now.month, 1);

    final daily = await getDailyReport(today, currency);
    final weekly = await getWeeklyReport(weekStart, currency);
    final monthly = await getMonthlyReport(monthStart, currency);
    final yearly = await getYearlyReport(now.year, currency);

    return {
      'daily': {
        'net': daily.netChange,
        'label': DateFormat('MMM d').format(today),
      },
      'weekly': {
        'net': weekly.net,
        'label': '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekStart.add(const Duration(days: 6)))}',
      },
      'monthly': {
        'net': monthly.net,
        'label': DateFormat('MMMM yyyy').format(monthStart),
      },
      'yearly': {
        'net': yearly.net,
        'label': '${now.year}',
      },
    };
  }
}
