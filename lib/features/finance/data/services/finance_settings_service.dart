import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/account_repository.dart';
import '../repositories/bill_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/daily_balance_repository.dart';
import '../repositories/debt_repository.dart';
import '../repositories/savings_goal_repository.dart';
import '../repositories/transaction_repository.dart';

/// Service for finance settings (default currency, etc.)
class FinanceSettingsService {
  static const String _defaultCurrencyKey = 'default_currency';
  static const String _initialSetupDoneKey = 'finance_initial_setup_done';

  /// Fallback currency - only used if user hasn't set one yet
  /// This is NOT hardcoded display - it's just the initial default
  static const String fallbackCurrency = 'ETB';

  /// Supported currencies for the finance module
  static const List<String> supportedCurrencies = [
    'ETB', // Ethiopian Birr
    'USD', // US Dollar
    'EUR', // Euro
    'GBP', // British Pound
    'JPY', // Japanese Yen
    'CNY', // Chinese Yuan
    'INR', // Indian Rupee
    'AUD', // Australian Dollar
    'CAD', // Canadian Dollar
    'CHF', // Swiss Franc
    'KRW', // Korean Won
    'BRL', // Brazilian Real
    'MXN', // Mexican Peso
    'ZAR', // South African Rand
    'AED', // UAE Dirham
    'SAR', // Saudi Riyal
    'TRY', // Turkish Lira
    'RUB', // Russian Ruble
    'PLN', // Polish Zloty
    'SEK', // Swedish Krona
    'NOK', // Norwegian Krone
    'DKK', // Danish Krone
    'SGD', // Singapore Dollar
    'HKD', // Hong Kong Dollar
    'THB', // Thai Baht
    'MYR', // Malaysian Ringgit
    'IDR', // Indonesian Rupiah
    'PHP', // Philippine Peso
    'VND', // Vietnamese Dong
    'PKR', // Pakistani Rupee
    'BDT', // Bangladeshi Taka
    'NGN', // Nigerian Naira
    'EGP', // Egyptian Pound
    'KES', // Kenyan Shilling
  ];

  Future<String> getDefaultCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_defaultCurrencyKey);
    if (stored == null) {
      return fallbackCurrency;
    }
    return supportedCurrencies.contains(stored) ? stored : fallbackCurrency;
  }

  Future<void> setDefaultCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    final value = supportedCurrencies.contains(currency)
        ? currency
        : fallbackCurrency;
    await prefs.setString(_defaultCurrencyKey, value);
  }

  /// Check if initial setup has been completed
  Future<bool> isInitialSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_initialSetupDoneKey) ?? false;
  }

  /// Mark initial setup as complete
  Future<void> markInitialSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_initialSetupDoneKey, true);
  }

  /// Bulk update all items to use the new currency
  /// This updates all accounts, bills, debts, budgets, savings goals,
  /// and transactions.
  ///
  /// NOTE: This is a "relabel" operation (no FX conversion). Amount values
  /// remain unchanged - only currency codes are updated.
  ///
  /// It also clears cached daily balance snapshots so the dashboard recalculates
  /// immediately using the new currency labels.
  Future<BulkUpdateResult> bulkUpdateCurrency(String newCurrency) async {
    final currency = supportedCurrencies.contains(newCurrency)
        ? newCurrency
        : fallbackCurrency;

    int accountsUpdated = 0;
    int billsUpdated = 0;
    int debtsUpdated = 0;
    int budgetsUpdated = 0;
    int savingsGoalsUpdated = 0;
    int transactionsUpdated = 0;

    // Update all accounts
    final accountRepo = AccountRepository();
    final accounts = await accountRepo.getAllAccounts();
    for (final account in accounts) {
      if (account.currency != currency) {
        final updated = account.copyWith(currency: currency);
        await accountRepo.updateAccount(updated);
        accountsUpdated++;
      }
    }

    // Update all bills
    final billRepo = BillRepository();
    final bills = await billRepo.getAllBills();
    for (final bill in bills) {
      if (bill.currency != currency) {
        final updated = bill.copyWith(currency: currency);
        await billRepo.updateBill(updated);
        billsUpdated++;
      }
    }

    // Update all debts
    final debtRepo = DebtRepository();
    final debts = await debtRepo.getAllDebtRecords();
    for (final debt in debts) {
      if (debt.currency != currency) {
        final updated = debt.copyWith(currency: currency);
        await debtRepo.updateDebt(updated);
        debtsUpdated++;
      }
    }

    // Update all budgets
    final budgetRepo = BudgetRepository();
    final budgets = await budgetRepo.getAllBudgets();
    for (final budget in budgets) {
      if (budget.currency != currency) {
        final updated = budget.copyWith(currency: currency);
        await budgetRepo.updateBudget(updated);
        budgetsUpdated++;
      }
    }

    // Update all savings goals
    final savingsRepo = SavingsGoalRepository();
    final savingsGoals = await savingsRepo.getAllGoals();
    for (final goal in savingsGoals) {
      if (goal.currency != currency) {
        final updated = goal.copyWith(currency: currency);
        await savingsRepo.updateGoal(updated);
        savingsGoalsUpdated++;
      }
    }

    // Update all transactions
    final transactionRepo = TransactionRepository();
    final transactions = await transactionRepo.getAllTransactions();
    for (final tx in transactions) {
      // tx.currency can be null on older records; normalize everything.
      if (tx.currency != currency) {
        final updated = tx.copyWith(currency: currency);
        await transactionRepo.updateTransaction(updated);
        transactionsUpdated++;
      }
    }

    // Save as new default
    await setDefaultCurrency(currency);

    // Clear cached daily balance snapshots so totals recalc with new labels
    final dailyBalanceRepo = DailyBalanceRepository();
    await dailyBalanceRepo.deleteAllSnapshots();

    return BulkUpdateResult(
      accountsUpdated: accountsUpdated,
      billsUpdated: billsUpdated,
      debtsUpdated: debtsUpdated,
      budgetsUpdated: budgetsUpdated,
      savingsGoalsUpdated: savingsGoalsUpdated,
      transactionsUpdated: transactionsUpdated,
      dailyBalanceSnapshotsCleared: true,
    );
  }
}

/// Result of bulk currency update operation
class BulkUpdateResult {
  final int accountsUpdated;
  final int billsUpdated;
  final int debtsUpdated;
  final int budgetsUpdated;
  final int savingsGoalsUpdated;
  final int transactionsUpdated;
  final bool dailyBalanceSnapshotsCleared;

  BulkUpdateResult({
    required this.accountsUpdated,
    required this.billsUpdated,
    required this.debtsUpdated,
    required this.budgetsUpdated,
    required this.savingsGoalsUpdated,
    required this.transactionsUpdated,
    required this.dailyBalanceSnapshotsCleared,
  });

  int get totalUpdated =>
      accountsUpdated +
      billsUpdated +
      debtsUpdated +
      budgetsUpdated +
      savingsGoalsUpdated +
      transactionsUpdated;
}
