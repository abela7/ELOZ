import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/transaction.dart';
import '../../data/models/transaction_category.dart';
import '../../data/models/transaction_template.dart';
import '../../data/models/budget.dart';
import '../../data/models/account.dart';
import '../../data/models/debt.dart';
import '../../data/models/debt_category.dart';
import '../../data/models/bill.dart';
import '../../data/models/bill_category.dart';
import '../../data/models/savings_goal.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transaction_category_repository.dart';
import '../../data/repositories/transaction_template_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/daily_balance_repository.dart';
import '../../data/repositories/debt_repository.dart';
import '../../data/repositories/debt_category_repository.dart';
import '../../data/repositories/bill_repository.dart';
import '../../data/repositories/bill_category_repository.dart';
import '../../data/repositories/savings_goal_repository.dart';
import '../../data/services/finance_statistics_service.dart';
import '../../data/services/budget_tracker_service.dart';
import '../../data/services/transaction_balance_service.dart';
import '../../data/services/daily_balance_service.dart';
import '../../data/services/recurring_transaction_service.dart';
import '../../data/services/finance_settings_service.dart';
import '../../data/services/finance_encrypted_backup_service.dart';
import '../../data/services/debt_service.dart';
import '../../data/services/bill_service.dart';
import '../../data/services/savings_goal_service.dart';
import '../../data/services/finance_security_service.dart';
import '../../data/services/finance_data_reset_service.dart';
import '../../../../core/utils/perf_trace.dart';
import '../services/finance_access_guard.dart';

// ==================== REPOSITORY PROVIDERS ====================

/// Transaction repository provider
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

/// Transaction category repository provider
final transactionCategoryRepositoryProvider =
    Provider<TransactionCategoryRepository>((ref) {
      return TransactionCategoryRepository();
    });

/// Transaction template repository provider
final transactionTemplateRepositoryProvider =
    Provider<TransactionTemplateRepository>((ref) {
      return TransactionTemplateRepository();
    });

/// Budget repository provider
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository();
});

/// Savings goal repository provider
final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  return SavingsGoalRepository();
});

/// Account repository provider
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository();
});

/// Daily balance repository provider
final dailyBalanceRepositoryProvider = Provider<DailyBalanceRepository>((ref) {
  return DailyBalanceRepository();
});

/// Finance settings service provider
final financeSettingsServiceProvider = Provider<FinanceSettingsService>((ref) {
  return FinanceSettingsService();
});

/// Encrypted backup service provider
final financeEncryptedBackupServiceProvider =
    Provider<FinanceEncryptedBackupService>((ref) {
      return FinanceEncryptedBackupService();
    });

// ==================== SERVICE PROVIDERS ====================

/// Finance statistics service provider
final financeStatisticsServiceProvider = Provider<FinanceStatisticsService>((
  ref,
) {
  final transactionRepository = ref.watch(transactionRepositoryProvider);
  return FinanceStatisticsService(transactionRepository);
});

/// Budget tracker service provider
final budgetTrackerServiceProvider = Provider<BudgetTrackerService>((ref) {
  final budgetRepository = ref.watch(budgetRepositoryProvider);
  final transactionRepository = ref.watch(transactionRepositoryProvider);
  return BudgetTrackerService(budgetRepository, transactionRepository);
});

/// Savings goal service provider
final savingsGoalServiceProvider = Provider<SavingsGoalService>((ref) {
  final repository = ref.watch(savingsGoalRepositoryProvider);
  return SavingsGoalService(repository);
});

/// Transaction balance service provider - handles all balance calculations
final transactionBalanceServiceProvider = Provider<TransactionBalanceService>((
  ref,
) {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final transactionRepository = ref.watch(transactionRepositoryProvider);
  return TransactionBalanceService(accountRepository, transactionRepository);
});

/// Daily balance service provider - handles per-day total balances
final dailyBalanceServiceProvider = Provider<DailyBalanceService>((ref) {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final transactionRepository = ref.watch(transactionRepositoryProvider);
  final dailyBalanceRepository = ref.watch(dailyBalanceRepositoryProvider);
  return DailyBalanceService(
    accountRepository,
    transactionRepository,
    dailyBalanceRepository,
  );
});

/// Recurring transaction service provider
final recurringTransactionServiceProvider =
    Provider<RecurringTransactionService>((ref) {
      final transactionRepository = ref.watch(transactionRepositoryProvider);
      final balanceService = ref.watch(transactionBalanceServiceProvider);
      return RecurringTransactionService(transactionRepository, balanceService);
    });

/// Default currency provider
final defaultCurrencyProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(financeSettingsServiceProvider);
  return await service.getDefaultCurrency();
});

// ==================== DATA PROVIDERS ====================

/// All transactions provider
final allTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final trace = PerfTrace('FinanceProvider.allTransactions');
  final repository = ref.watch(transactionRepositoryProvider);
  final transactions = await repository.getAllTransactions();
  trace.end('done', details: {'count': transactions.length});
  return transactions;
});

/// Transactions for a specific date provider
final transactionsForDateProvider =
    FutureProvider.family<List<Transaction>, DateTime>((ref, date) async {
      final trace = PerfTrace('FinanceProvider.transactionsForDate');
      final repository = ref.watch(transactionRepositoryProvider);
      // Normalize date to midnight for consistent provider keys
      final localDate = date.toLocal();
      final normalizedDate = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
      );
      trace.step(
        'normalized',
        details: {'date': normalizedDate.toIso8601String().split('T').first},
      );
      final transactions = await repository.getTransactionsForDate(
        normalizedDate,
      );
      trace.end('done', details: {'count': transactions.length});
      return transactions;
    });

/// All transaction categories provider
final allTransactionCategoriesProvider =
    FutureProvider<List<TransactionCategory>>((ref) async {
      final repository = ref.watch(transactionCategoryRepositoryProvider);
      return await repository.getAllCategories();
    });

/// All transaction templates provider
final allTransactionTemplatesProvider =
    FutureProvider<List<TransactionTemplate>>((ref) async {
      final repository = ref.watch(transactionTemplateRepositoryProvider);
      return await repository.getAllTemplates();
    });

/// Income transaction categories provider (legacy - for transaction categories)
final incomeTransactionCategoriesProvider =
    FutureProvider<List<TransactionCategory>>((ref) async {
      final repository = ref.watch(transactionCategoryRepositoryProvider);
      return await repository.getIncomeCategories();
    });

/// Expense transaction categories provider (only active categories)
final expenseTransactionCategoriesProvider =
    FutureProvider<List<TransactionCategory>>((ref) async {
      final repository = ref.watch(transactionCategoryRepositoryProvider);
      return await repository.getActiveExpenseCategories();
    });

/// All expense transaction categories provider (including inactive)
final allExpenseTransactionCategoriesProvider =
    FutureProvider<List<TransactionCategory>>((ref) async {
      final repository = ref.watch(transactionCategoryRepositoryProvider);
      return await repository.getExpenseCategories();
    });

/// Expense categories provider
final expenseCategoriesProvider = FutureProvider<List<TransactionCategory>>((
  ref,
) async {
  final repository = ref.watch(transactionCategoryRepositoryProvider);
  return await repository.getExpenseCategories();
});

/// Transaction category by ID provider (for both income and expense)
final transactionCategoryByIdProvider =
    Provider.family<TransactionCategory?, String>((ref, id) {
      final categoriesAsync = ref.watch(allTransactionCategoriesProvider);
      return categoriesAsync.maybeWhen(
        data: (categories) {
          try {
            return categories.firstWhere((c) => c.id == id);
          } catch (_) {
            return null;
          }
        },
        orElse: () => null,
      );
    });

/// All budgets provider
final allBudgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final repository = ref.watch(budgetRepositoryProvider);
  return await repository.getAllBudgets();
});

/// Active budgets provider
final activeBudgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final repository = ref.watch(budgetRepositoryProvider);
  return await repository.getActiveBudgets();
});

/// All savings goals provider
final allSavingsGoalsProvider = FutureProvider<List<SavingsGoal>>((ref) async {
  final repository = ref.watch(savingsGoalRepositoryProvider);
  return await repository.getAllGoals();
});

/// Active and completed savings goals provider
final activeSavingsGoalsProvider = FutureProvider<List<SavingsGoal>>((
  ref,
) async {
  final repository = ref.watch(savingsGoalRepositoryProvider);
  return await repository.getActiveGoals();
});

/// Archived savings goals provider
final archivedSavingsGoalsProvider = FutureProvider<List<SavingsGoal>>((
  ref,
) async {
  final repository = ref.watch(savingsGoalRepositoryProvider);
  return await repository.getArchivedGoals();
});

/// Savings goals summary provider
final savingsGoalsSummaryProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final service = ref.watch(savingsGoalServiceProvider);
  return await service.getSummary();
});

/// All accounts provider
final allAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final repository = ref.watch(accountRepositoryProvider);
  return await repository.getAllAccounts();
});

/// Active accounts provider
final activeAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final repository = ref.watch(accountRepositoryProvider);
  return await repository.getActiveAccounts();
});

/// Default account provider
final defaultAccountProvider = FutureProvider<Account?>((ref) async {
  final repository = ref.watch(accountRepositoryProvider);
  return await repository.getDefaultAccount();
});

/// Account by ID provider
final accountByIdProvider = Provider.family<AsyncValue<Account?>, String>((
  ref,
  accountId,
) {
  final accountsAsync = ref.watch(allAccountsProvider);
  return accountsAsync.whenData((accounts) {
    try {
      return accounts.firstWhere((a) => a.id == accountId);
    } catch (e) {
      return null;
    }
  });
});

/// Total balance provider
final totalBalanceProvider = FutureProvider<Map<String, double>>((ref) async {
  final repository = ref.watch(accountRepositoryProvider);
  return await repository.getTotalBalanceByCurrency();
});

/// Daily total balance provider (by date)
final dailyTotalBalanceProvider =
    FutureProvider.family<Map<String, double>, DateTime>((ref, date) async {
      final trace = PerfTrace('FinanceProvider.dailyTotalBalance');
      final service = ref.watch(dailyBalanceServiceProvider);
      final balances = await service.getTotalBalanceByCurrencyForDate(date);
      trace.end('done', details: {'currencies': balances.length});
      return balances;
    });

// ==================== STATISTICS PROVIDERS ====================

/// Monthly statistics provider
final monthlyStatisticsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final trace = PerfTrace('FinanceProvider.monthlyStatistics');
  final service = ref.watch(financeStatisticsServiceProvider);
  final defaultCurrency = await ref.watch(defaultCurrencyProvider.future);
  trace.step('default_currency_ready', details: {'currency': defaultCurrency});
  final stats = await service.getMonthlyStatistics(
    defaultCurrency: defaultCurrency,
  );
  trace.end('done');
  return stats;
});

/// Yearly statistics provider
final yearlyStatisticsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final service = ref.watch(financeStatisticsServiceProvider);
  final defaultCurrency = await ref.watch(defaultCurrencyProvider.future);
  return await service.getYearlyStatistics(defaultCurrency: defaultCurrency);
});

/// Budget statuses provider
final allBudgetStatusesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(budgetTrackerServiceProvider);
  return await service.getAllBudgetStatuses();
});

/// Transaction statistics provider
final transactionStatisticsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final defaultCurrency = await ref.watch(defaultCurrencyProvider.future);
  return await repository.getTransactionStatistics(
    defaultCurrency: defaultCurrency,
  );
});

// ==================== STATE NOTIFIER PROVIDERS ====================

/// Selected date for viewing transactions
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Selected transaction type filter (all, income, expense, transfer)
final selectedTransactionTypeProvider = StateProvider<String?>((ref) => null);

/// Selected account filter
final selectedAccountFilterProvider = StateProvider<String?>((ref) => null);

/// Selected category filter
final selectedCategoryFilterProvider = StateProvider<String?>((ref) => null);

// ==================== DEBT PROVIDERS ====================

/// Debt repository provider
final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository();
});

/// Debt category repository provider
final debtCategoryRepositoryProvider = Provider<DebtCategoryRepository>((ref) {
  return DebtCategoryRepository();
});

/// Debt service provider
final debtServiceProvider = Provider<DebtService>((ref) {
  final debtRepo = ref.watch(debtRepositoryProvider);
  final categoryRepo = ref.watch(debtCategoryRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final balanceService = ref.watch(transactionBalanceServiceProvider);
  return DebtService(debtRepo, categoryRepo, transactionRepo, balanceService);
});

/// All debts provider
final allDebtsProvider = FutureProvider<List<Debt>>((ref) async {
  final repository = ref.watch(debtRepositoryProvider);
  return await repository.getAllDebts(direction: DebtDirection.owed);
});

/// Active debts provider
final activeDebtsProvider = FutureProvider<List<Debt>>((ref) async {
  final repository = ref.watch(debtRepositoryProvider);
  return await repository.getActiveDebts(direction: DebtDirection.owed);
});

/// All lent records provider (money others owe you)
final allLentDebtsProvider = FutureProvider<List<Debt>>((ref) async {
  final repository = ref.watch(debtRepositoryProvider);
  return await repository.getAllDebts(direction: DebtDirection.lent);
});

/// Active lent records provider
final activeLentDebtsProvider = FutureProvider<List<Debt>>((ref) async {
  final repository = ref.watch(debtRepositoryProvider);
  return await repository.getActiveDebts(direction: DebtDirection.lent);
});

/// All debt categories provider
final allDebtCategoriesProvider = FutureProvider<List<DebtCategory>>((
  ref,
) async {
  final repository = ref.watch(debtCategoryRepositoryProvider);
  return await repository.getAllCategories();
});

/// Active debt categories provider
final activeDebtCategoriesProvider = FutureProvider<List<DebtCategory>>((
  ref,
) async {
  final repository = ref.watch(debtCategoryRepositoryProvider);
  return await repository.getActiveCategories();
});

/// Total debt by currency provider
final totalDebtByCurrencyProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final repository = ref.watch(debtRepositoryProvider);
  return await repository.getTotalDebtByCurrency(direction: DebtDirection.owed);
});

/// Total debt by currency as-of selected day provider.
final totalDebtByCurrencyForDateProvider =
    FutureProvider.family<Map<String, double>, DateTime>((ref, date) async {
      final trace = PerfTrace('FinanceProvider.totalDebtForDate');
      final repository = ref.watch(debtRepositoryProvider);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final debts = await repository.getTotalDebtByCurrencyAsOf(
        normalizedDate,
        direction: DebtDirection.owed,
      );
      trace.end('done', details: {'currencies': debts.length});
      return debts;
    });

/// Total lent by currency provider
final totalLentByCurrencyProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final repository = ref.watch(debtRepositoryProvider);
  return await repository.getTotalDebtByCurrency(direction: DebtDirection.lent);
});

/// Total lent by currency as-of selected day provider.
final totalLentByCurrencyForDateProvider =
    FutureProvider.family<Map<String, double>, DateTime>((ref, date) async {
      final repository = ref.watch(debtRepositoryProvider);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      return await repository.getTotalDebtByCurrencyAsOf(
        normalizedDate,
        direction: DebtDirection.lent,
      );
    });

/// Debt statistics provider
final debtStatisticsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final repository = ref.watch(debtRepositoryProvider);
  return await repository.getDebtStatistics(direction: DebtDirection.owed);
});

/// Lent statistics provider
final lentStatisticsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final repository = ref.watch(debtRepositoryProvider);
  return await repository.getDebtStatistics(direction: DebtDirection.lent);
});

/// Debts grouped by category provider
final debtsGroupedByCategoryProvider = FutureProvider<Map<String, List<Debt>>>((
  ref,
) async {
  final service = ref.watch(debtServiceProvider);
  return await service.getDebtsGroupedByCategory(direction: DebtDirection.owed);
});

/// Lent grouped by category provider
final lentGroupedByCategoryProvider = FutureProvider<Map<String, List<Debt>>>((
  ref,
) async {
  final service = ref.watch(debtServiceProvider);
  return await service.getDebtsGroupedByCategory(direction: DebtDirection.lent);
});

/// Debts needing attention provider (overdue or due soon)
final debtsNeedingAttentionProvider = FutureProvider<List<Debt>>((ref) async {
  final service = ref.watch(debtServiceProvider);
  return await service.getDebtsNeedingAttention(direction: DebtDirection.owed);
});

/// Lent records needing attention provider (overdue or due soon)
final lentNeedingAttentionProvider = FutureProvider<List<Debt>>((ref) async {
  final service = ref.watch(debtServiceProvider);
  return await service.getDebtsNeedingAttention(direction: DebtDirection.lent);
});

/// Net worth by currency provider (assets - debts)
final netWorthByCurrencyProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final assets = await ref.watch(totalBalanceProvider.future);
  final service = ref.watch(debtServiceProvider);
  return await service.calculateNetWorthByCurrency(assetsByCurrency: assets);
});

// ============================================================================
// BILL & SUBSCRIPTION PROVIDERS
// ============================================================================

/// Bill repository provider
final billRepositoryProvider = Provider<BillRepository>((ref) {
  return BillRepository();
});

/// Bill category repository provider
final billCategoryRepositoryProvider = Provider<BillCategoryRepository>((ref) {
  return BillCategoryRepository();
});

/// Bill service provider
final billServiceProvider = Provider<BillService>((ref) {
  final billRepo = ref.watch(billRepositoryProvider);
  final categoryRepo = ref.watch(billCategoryRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final balanceService = ref.watch(transactionBalanceServiceProvider);
  return BillService(billRepo, categoryRepo, transactionRepo, balanceService);
});

/// All bills provider
final allBillsProvider = FutureProvider<List<Bill>>((ref) async {
  final repository = ref.watch(billRepositoryProvider);
  return await repository.getAllBills();
});

/// Active bills provider
final activeBillsProvider = FutureProvider<List<Bill>>((ref) async {
  final repository = ref.watch(billRepositoryProvider);
  return await repository.getActiveBills();
});

/// Bills only provider (not subscriptions)
final billsOnlyProvider = FutureProvider<List<Bill>>((ref) async {
  final repository = ref.watch(billRepositoryProvider);
  return await repository.getBillsByType('bill');
});

/// Subscriptions only provider
final subscriptionsOnlyProvider = FutureProvider<List<Bill>>((ref) async {
  final repository = ref.watch(billRepositoryProvider);
  return await repository.getBillsByType('subscription');
});

/// Upcoming bills provider (next 7 days)
final upcomingBillsProvider = FutureProvider<List<Bill>>((ref) async {
  final repository = ref.watch(billRepositoryProvider);
  return await repository.getUpcomingBills(days: 7);
});

/// Overdue bills provider
final overdueBillsProvider = FutureProvider<List<Bill>>((ref) async {
  final repository = ref.watch(billRepositoryProvider);
  return await repository.getOverdueBills();
});

/// All bill categories provider (DEPRECATED - use expenseTransactionCategoriesProvider)
/// Kept for backward compatibility during migration
final allBillCategoriesProvider = FutureProvider<List<BillCategory>>((
  ref,
) async {
  final repository = ref.watch(billCategoryRepositoryProvider);
  return await repository.getAllCategories();
});

/// Active bill categories provider (DEPRECATED - use expenseTransactionCategoriesProvider)
/// Kept for backward compatibility during migration
final activeBillCategoriesProvider = FutureProvider<List<BillCategory>>((
  ref,
) async {
  final repository = ref.watch(billCategoryRepositoryProvider);
  return await repository.getActiveCategories();
});

/// Bills grouped by category provider
final billsGroupedByCategoryProvider = FutureProvider<Map<String, List<Bill>>>((
  ref,
) async {
  final service = ref.watch(billServiceProvider);
  return await service.getBillsGroupedByCategory();
});

/// Monthly bills cost by currency provider
final monthlyBillsCostProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final repository = ref.watch(billRepositoryProvider);
  return await repository.getTotalMonthlyCostByCurrency();
});

/// Bill summary provider
final billSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(billServiceProvider);
  return await service.getMonthlySummary();
});

/// Bill by ID provider
final billByIdProvider = Provider.family<AsyncValue<Bill?>, String>((ref, id) {
  final billsAsync = ref.watch(allBillsProvider);
  return billsAsync.whenData((bills) {
    try {
      return bills.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  });
});

// ============================================================================
// BILL CATEGORY PROVIDERS (DEPRECATED - Use TransactionCategory instead)
// ============================================================================
// Note: These providers are kept for backward compatibility but should not be
// used in new code. All bill categories are now managed through TransactionCategory
// with type: 'expense'. Use expenseTransactionCategoriesProvider instead.

// ============================================================================
// SECURITY PROVIDERS
// ============================================================================

/// Finance security service provider
final financeSecurityServiceProvider = Provider<FinanceSecurityService>((ref) {
  return FinanceSecurityService();
});

/// Finance data reset service provider
final financeDataResetServiceProvider = Provider<FinanceDataResetService>((
  ref,
) {
  final securityService = ref.watch(financeSecurityServiceProvider);
  return FinanceDataResetService(securityService: securityService);
});

/// Finance access guard provider
final financeAccessGuardProvider = Provider<FinanceAccessGuard>((ref) {
  final securityService = ref.watch(financeSecurityServiceProvider);
  final dataResetService = ref.watch(financeDataResetServiceProvider);
  return FinanceAccessGuard(
    securityService: securityService,
    dataResetService: dataResetService,
  );
});
