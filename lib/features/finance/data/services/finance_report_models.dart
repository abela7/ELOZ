/// Report data models for the comprehensive finance report pages.

/// Category breakdown item with name, amount, and percentage
class ReportCategoryItem {
  final String categoryId;
  final String categoryName;
  final double amount;
  final double percentage;

  const ReportCategoryItem({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });
}

/// Account balance change for a period
class ReportAccountChange {
  final String accountId;
  final String accountName;
  final String currency;
  final double openingBalance;
  final double closingBalance;
  final double delta;

  const ReportAccountChange({
    required this.accountId,
    required this.accountName,
    required this.currency,
    required this.openingBalance,
    required this.closingBalance,
    required this.delta,
  });
}

/// Budget utilization for report
class ReportBudgetStatus {
  final String budgetId;
  final String budgetName;
  final double limit;
  final double spent;
  final double percentage;
  final bool isExceeded;

  const ReportBudgetStatus({
    required this.budgetId,
    required this.budgetName,
    required this.limit,
    required this.spent,
    required this.percentage,
    required this.isExceeded,
  });
}

/// Daily report data
class DailyReportData {
  final DateTime date;
  final double openingBalance;
  final double closingBalance;
  final double netChange;
  final double totalIncome;
  final double totalExpense;
  final double savingsRate;
  final int incomeCount;
  final int expenseCount;
  final int transferCount;
  final Map<int, double> hourlyIncome;
  final Map<int, double> hourlyExpense;
  final List<ReportCategoryItem> expenseCategories;
  final List<ReportCategoryItem> incomeCategories;
  final List<ReportAccountChange> accountChanges;
  final List<dynamic> incomeTransactions;
  final List<dynamic> expenseTransactions;
  final List<dynamic> transferTransactions;

  const DailyReportData({
    required this.date,
    required this.openingBalance,
    required this.closingBalance,
    required this.netChange,
    required this.totalIncome,
    required this.totalExpense,
    required this.savingsRate,
    required this.incomeCount,
    required this.expenseCount,
    required this.transferCount,
    required this.hourlyIncome,
    required this.hourlyExpense,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.accountChanges,
    required this.incomeTransactions,
    required this.expenseTransactions,
    required this.transferTransactions,
  });
}

/// Weekly report data
class WeeklyReportData {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double totalIncome;
  final double totalExpense;
  final double net;
  final double savingsRate;
  final double? incomeChangeVsPrevWeek;
  final double? expenseChangeVsPrevWeek;
  final List<DailySummary> dailySummaries;
  final List<double> dailyClosingBalances;
  final List<ReportCategoryItem> topExpenseCategories;
  final String? busiestDay;
  final String? quietestDay;
  final double averageDailySpending;
  final int totalTransactions;
  final double avgPerTransaction;
  final double? highestSingleExpense;
  final double? highestSingleIncome;

  const WeeklyReportData({
    required this.weekStart,
    required this.weekEnd,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.savingsRate,
    this.incomeChangeVsPrevWeek,
    this.expenseChangeVsPrevWeek,
    required this.dailySummaries,
    required this.dailyClosingBalances,
    required this.topExpenseCategories,
    this.busiestDay,
    this.quietestDay,
    required this.averageDailySpending,
    required this.totalTransactions,
    required this.avgPerTransaction,
    this.highestSingleExpense,
    this.highestSingleIncome,
  });
}

class DailySummary {
  final DateTime date;
  final String label;
  final double income;
  final double expense;
  final double closingBalance;

  const DailySummary({
    required this.date,
    required this.label,
    required this.income,
    required this.expense,
    required this.closingBalance,
  });
}

/// Monthly report data
class MonthlyReportData {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;
  final double net;
  final double savingsRate;
  final double? incomeChangeVsPrevMonth;
  final double? expenseChangeVsPrevMonth;
  final List<double> dailyClosingBalances;
  final List<WeeklySummary> weeklySummaries;
  final List<ReportCategoryItem> expenseCategories;
  final List<ReportBudgetStatus> budgetStatuses;
  final int billsPaidCount;
  final int billsUpcomingCount;
  final double billsTotalCost;
  final double debtPaymentsThisMonth;
  final double savingsContributionsThisMonth;
  final List<dynamic> topExpenses;
  final List<dynamic> topIncomes;

  const MonthlyReportData({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.savingsRate,
    this.incomeChangeVsPrevMonth,
    this.expenseChangeVsPrevMonth,
    required this.dailyClosingBalances,
    required this.weeklySummaries,
    required this.expenseCategories,
    required this.budgetStatuses,
    required this.billsPaidCount,
    required this.billsUpcomingCount,
    required this.billsTotalCost,
    required this.debtPaymentsThisMonth,
    required this.savingsContributionsThisMonth,
    required this.topExpenses,
    required this.topIncomes,
  });
}

class WeeklySummary {
  final DateTime weekStart;
  final String label;
  final double income;
  final double expense;

  const WeeklySummary({
    required this.weekStart,
    required this.label,
    required this.income,
    required this.expense,
  });
}

/// Yearly report data
class YearlyReportData {
  final int year;
  final double totalIncome;
  final double totalExpense;
  final double net;
  final double savingsRate;
  final double? incomeChangeVsPrevYear;
  final double? expenseChangeVsPrevYear;
  final List<MonthlySummary> monthlySummaries;
  final List<double> monthlyClosingBalances;
  final List<double> monthlySavingsRates;
  final List<ReportCategoryItem> expenseCategories;
  final String? bestIncomeMonth;
  final double? bestIncomeAmount;
  final String? worstExpenseMonth;
  final double? worstExpenseAmount;
  final String? bestSavingsMonth;
  final double? bestSavingsRate;
  final double debtStartOfYear;
  final double debtEndOfYear;
  final double totalDebtPayments;
  final double savingsStartOfYear;
  final double savingsEndOfYear;
  final double totalSavingsContributions;
  final int totalTransactions;
  final double avgMonthlySpend;
  final double avgMonthlyIncome;
  final String? mostUsedPaymentMethod;

  const YearlyReportData({
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.savingsRate,
    this.incomeChangeVsPrevYear,
    this.expenseChangeVsPrevYear,
    required this.monthlySummaries,
    required this.monthlyClosingBalances,
    required this.monthlySavingsRates,
    required this.expenseCategories,
    this.bestIncomeMonth,
    this.bestIncomeAmount,
    this.worstExpenseMonth,
    this.worstExpenseAmount,
    this.bestSavingsMonth,
    this.bestSavingsRate,
    required this.debtStartOfYear,
    required this.debtEndOfYear,
    required this.totalDebtPayments,
    required this.savingsStartOfYear,
    required this.savingsEndOfYear,
    required this.totalSavingsContributions,
    required this.totalTransactions,
    required this.avgMonthlySpend,
    required this.avgMonthlyIncome,
    this.mostUsedPaymentMethod,
  });
}

class MonthlySummary {
  final int month;
  final String label;
  final double income;
  final double expense;

  const MonthlySummary({
    required this.month,
    required this.label,
    required this.income,
    required this.expense,
  });
}
