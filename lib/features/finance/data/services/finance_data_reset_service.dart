import '../../../../data/local/hive/hive_service.dart';
import '../models/transaction.dart';
import '../models/transaction_category.dart';
import '../models/transaction_template.dart';
import '../models/budget.dart';
import '../models/account.dart';
import '../models/daily_balance.dart';
import '../models/debt_category.dart';
import '../models/debt.dart';
import '../models/bill_category.dart';
import '../models/bill.dart';
import '../models/savings_goal.dart';
import '../models/recurring_income.dart';
import '../repositories/transaction_repository.dart';
import 'finance_security_service.dart';

/// Summary of what was deleted during an emergency data wipe.
class FinanceDataResetSummary {
  final int deletedTransactions;
  final int deletedCategories;
  final int deletedTemplates;
  final int deletedBudgets;
  final int deletedAccounts;
  final int deletedDailyBalances;
  final int deletedDebtCategories;
  final int deletedDebts;
  final int deletedBillCategories;
  final int deletedBills;
  final int deletedSavingsGoals;

  const FinanceDataResetSummary({
    required this.deletedTransactions,
    required this.deletedCategories,
    required this.deletedTemplates,
    required this.deletedBudgets,
    required this.deletedAccounts,
    required this.deletedDailyBalances,
    required this.deletedDebtCategories,
    required this.deletedDebts,
    required this.deletedBillCategories,
    required this.deletedBills,
    required this.deletedSavingsGoals,
  });

  int get totalDeleted =>
      deletedTransactions +
      deletedCategories +
      deletedTemplates +
      deletedBudgets +
      deletedAccounts +
      deletedDailyBalances +
      deletedDebtCategories +
      deletedDebts +
      deletedBillCategories +
      deletedBills +
      deletedSavingsGoals;
}

/// Handles complete wipe of all finance data + security state.
///
/// Used as the nuclear option when the memorable word challenge is
/// exhausted (3 failures) to prevent a thief from accessing data.
class FinanceDataResetService {
  static const String _transactionsBox = 'transactionsBox';
  static const String _categoriesBox = 'transactionCategoriesBox';
  static const String _templatesBox = 'transactionTemplatesBox';
  static const String _budgetsBox = 'budgetsBox';
  static const String _accountsBox = 'accountsBox';
  static const String _dailyBalancesBox = 'dailyBalancesBox';
  static const String _debtCategoriesBox = 'debtCategoriesBox';
  static const String _debtsBox = 'debtsBox';
  static const String _billCategoriesBox = 'billCategoriesBox';
  static const String _billsBox = 'billsBox';
  static const String _savingsGoalsBox = 'savingsGoalsBox';
  static const String _recurringIncomesBox = 'recurring_incomes';

  final FinanceSecurityService _securityService;

  FinanceDataResetService({FinanceSecurityService? securityService})
    : _securityService = securityService ?? FinanceSecurityService();

  /// Permanently deletes ALL finance data from all 11 Hive boxes and
  /// resets all security state (passcode, memorable word, lockout counters).
  Future<FinanceDataResetSummary> wipeAllFinanceData() async {
    // Count items before deletion for the summary.
    final txBox = await HiveService.getBox<Transaction>(_transactionsBox);
    final catBox = await HiveService.getBox<TransactionCategory>(
      _categoriesBox,
    );
    final tplBox = await HiveService.getBox<TransactionTemplate>(_templatesBox);
    final budBox = await HiveService.getBox<Budget>(_budgetsBox);
    final accBox = await HiveService.getBox<Account>(_accountsBox);
    final dbBox = await HiveService.getBox<DailyBalance>(_dailyBalancesBox);
    final dcBox = await HiveService.getBox<DebtCategory>(_debtCategoriesBox);
    final debtBox = await HiveService.getBox<Debt>(_debtsBox);
    final bcBox = await HiveService.getBox<BillCategory>(_billCategoriesBox);
    final billBox = await HiveService.getBox<Bill>(_billsBox);
    final savingsBox = await HiveService.getBox<SavingsGoal>(_savingsGoalsBox);
    final recurringBox =
        await HiveService.getBox<RecurringIncome>(_recurringIncomesBox);

    final summary = FinanceDataResetSummary(
      deletedTransactions: txBox.length,
      deletedCategories: catBox.length,
      deletedTemplates: tplBox.length,
      deletedBudgets: budBox.length,
      deletedAccounts: accBox.length,
      deletedDailyBalances: dbBox.length,
      deletedDebtCategories: dcBox.length,
      deletedDebts: debtBox.length,
      deletedBillCategories: bcBox.length,
      deletedBills: billBox.length,
      deletedSavingsGoals: savingsBox.length,
    );

    // Clear all boxes.
    await txBox.clear();
    await catBox.clear();
    await tplBox.clear();
    await budBox.clear();
    await accBox.clear();
    await dbBox.clear();
    await dcBox.clear();
    await debtBox.clear();
    await bcBox.clear();
    await billBox.clear();
    await savingsBox.clear();
    await recurringBox.clear();

    // Reset security state (passcode, memorable word, lockouts).
    await _securityService.resetAllSecurityState();

    return summary;
  }

  /// Wipes ALL finance data but keeps settings (currency, security, notifications).
  /// Use for a fresh start while preserving user preferences.
  ///
  /// Clears: transactions, categories, templates, budgets, accounts,
  /// daily balances, debt categories, debts, bill categories, bills,
  /// savings goals, recurring incomes. Does NOT reset security state.
  Future<void> wipeAllFinanceDataKeepSettings() async {
    // Use TransactionRepository to clear transactions + indexes correctly
    final txRepo = TransactionRepository();
    await txRepo.deleteAllTransactions();

    final catBox =
        await HiveService.getBox<TransactionCategory>(_categoriesBox);
    final tplBox =
        await HiveService.getBox<TransactionTemplate>(_templatesBox);
    final budBox = await HiveService.getBox<Budget>(_budgetsBox);
    final accBox = await HiveService.getBox<Account>(_accountsBox);
    final dbBox = await HiveService.getBox<DailyBalance>(_dailyBalancesBox);
    final dcBox =
        await HiveService.getBox<DebtCategory>(_debtCategoriesBox);
    final debtBox = await HiveService.getBox<Debt>(_debtsBox);
    final bcBox =
        await HiveService.getBox<BillCategory>(_billCategoriesBox);
    final billBox = await HiveService.getBox<Bill>(_billsBox);
    final savingsBox =
        await HiveService.getBox<SavingsGoal>(_savingsGoalsBox);
    final recurringBox =
        await HiveService.getBox<RecurringIncome>(_recurringIncomesBox);

    await catBox.clear();
    await tplBox.clear();
    await budBox.clear();
    await accBox.clear();
    await dbBox.clear();
    await dcBox.clear();
    await debtBox.clear();
    await bcBox.clear();
    await billBox.clear();
    await savingsBox.clear();
    await recurringBox.clear();

    // Do NOT reset security - keep passcode, memorable word, lockout state
  }
}
