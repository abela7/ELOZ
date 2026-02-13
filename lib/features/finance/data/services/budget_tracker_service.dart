import '../models/budget.dart';
import '../models/transaction.dart';
import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';

/// Service for budget tracking and management
class BudgetTrackerService {
  final BudgetRepository _budgetRepository;
  final TransactionRepository _transactionRepository;

  BudgetTrackerService(this._budgetRepository, this._transactionRepository);

  DateTime _normalizeDate(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _matchesAccountScope(Budget budget, String? transactionAccountId) {
    if (budget.accountId == null) return true;
    return budget.accountId == transactionAccountId;
  }

  String _budgetScopeLabel(Budget budget) {
    if (budget.accountId != null && budget.categoryId != null) {
      return '${budget.name} (account + category)';
    }
    if (budget.accountId != null) {
      return '${budget.name} (account)';
    }
    if (budget.categoryId != null) {
      return '${budget.name} (category)';
    }
    return budget.name;
  }

  String _lifecycleStatus(Budget budget) {
    if (budget.isEnded) return 'ended';
    if (budget.isStopped) return 'stopped';
    if (budget.isPausedState) return 'paused';
    return 'active';
  }

  bool _isPastDateEnd(Budget budget, DateTime reference) {
    if (budget.endDate == null) return false;
    final normalizedReference = _normalizeDate(reference);
    final normalizedEnd = _normalizeDate(budget.endDate!);

    if (budget.endCondition == 'on_date') {
      return normalizedReference.isAfter(normalizedEnd);
    }

    // Custom budgets always close after their configured end date.
    if (budget.budgetPeriod == BudgetPeriod.custom) {
      return normalizedReference.isAfter(normalizedEnd);
    }

    return false;
  }

  bool _reachedProgressEnd(Budget budget) {
    switch (budget.endCondition) {
      case 'after_transactions':
        final target = budget.endTransactionCount ?? 0;
        if (target <= 0) return false;
        return budget.matchedTransactionCount >= target;
      case 'after_spent':
        final target = budget.endSpentAmount ?? 0.0;
        if (target <= 0) return false;
        return budget.lifetimeSpent >= target;
      case 'on_date':
      case 'indefinite':
      default:
        return false;
    }
  }

  Iterable<Transaction> _matchingExpenses(
    Budget budget,
    Iterable<Transaction> transactions,
  ) {
    return transactions.where((transaction) {
      if (!transaction.isExpense || transaction.isBalanceAdjustment) {
        return false;
      }

      if (!_matchesAccountScope(budget, transaction.accountId)) {
        return false;
      }

      if ((transaction.currency ?? budget.currency) != budget.currency) {
        return false;
      }

      if (budget.isOverallBudget) {
        if (budget.excludedCategoryIds == null) return true;
        return !budget.excludedCategoryIds!.contains(transaction.categoryId);
      }

      return transaction.categoryId == budget.categoryId;
    });
  }

  /// Update budget spent amounts based on transactions
  Future<void> updateAllBudgetSpending() async {
    final budgets = await _budgetRepository.getAllBudgets();

    for (final budget in budgets) {
      if (!budget.canTrack) continue;
      await _updateBudgetSpending(budget);
    }
  }

  /// Update spending for a specific budget
  Future<void> _updateBudgetSpending(Budget budget) async {
    final now = DateTime.now();

    if (budget.isStopped || budget.isEnded) {
      if (budget.isActive || budget.isPaused) {
        budget.isActive = false;
        budget.isPaused = false;
        await _budgetRepository.updateBudget(budget);
      }
      return;
    }

    if (_isPastDateEnd(budget, now)) {
      budget.end(at: now);
      await _budgetRepository.updateBudget(budget);
      return;
    }

    if (!budget.isInActivePeriodAt(now)) {
      if (budget.currentSpent != 0) {
        budget.currentSpent = 0;
        await _budgetRepository.updateBudget(budget);
      }
      return;
    }

    final periodStart = budget.getCurrentPeriodStart(asOf: now);
    final periodEnd = budget.getCurrentPeriodEnd(asOf: now);

    // Get transactions in budget period.
    final periodTransactions = await _transactionRepository
        .getTransactionsInRange(periodStart, periodEnd);
    final matchingPeriodExpenses = _matchingExpenses(
      budget,
      periodTransactions,
    );
    final totalSpent = matchingPeriodExpenses.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );

    // Lifetime progress for end-condition evaluation.
    final normalizedNow = _normalizeDate(now);
    final normalizedStart = _normalizeDate(budget.startDate);
    final lifetimeTransactions = normalizedNow.isBefore(normalizedStart)
        ? <Transaction>[]
        : await _transactionRepository.getTransactionsInRange(
            normalizedStart,
            normalizedNow,
          );
    final matchingLifetimeExpenses = _matchingExpenses(
      budget,
      lifetimeTransactions,
    ).toList();
    final lifetimeSpent = matchingLifetimeExpenses.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );
    final matchedCount = matchingLifetimeExpenses.length;

    var changed = false;

    if (budget.currentSpent != totalSpent) {
      budget.currentSpent = totalSpent;
      changed = true;
    }

    if (budget.lifetimeSpent != lifetimeSpent) {
      budget.lifetimeSpent = lifetimeSpent;
      changed = true;
    }

    if (budget.matchedTransactionCount != matchedCount) {
      budget.matchedTransactionCount = matchedCount;
      changed = true;
    }

    if (_reachedProgressEnd(budget)) {
      budget.end(at: now);
      changed = true;
    }

    if (changed) {
      await _budgetRepository.updateBudget(budget);
    }
  }

  /// Check lifecycle transitions (date-based auto-ending).
  Future<void> checkAndResetBudgets() async {
    final budgets = await _budgetRepository.getAllBudgets();
    final now = DateTime.now();

    for (final budget in budgets) {
      var changed = false;

      if (budget.isStopped || budget.isEnded) {
        if (budget.isActive || budget.isPaused) {
          budget.isActive = false;
          budget.isPaused = false;
          changed = true;
        }
      } else if (_isPastDateEnd(budget, now)) {
        budget.end(at: now);
        changed = true;
      }

      if (changed) {
        await _budgetRepository.updateBudget(budget);
      }
    }
  }

  /// Get budget status for a specific budget
  Future<Map<String, dynamic>> getBudgetStatus(String budgetId) async {
    final budget = await _budgetRepository.getBudgetById(budgetId);
    if (budget == null) {
      return {};
    }

    if (budget.canTrack) {
      await _updateBudgetSpending(budget);
    }

    return {
      'id': budget.id,
      'name': budget.name,
      'amount': budget.amount,
      'currentSpent': budget.currentSpent,
      'remaining': budget.remaining,
      'percentage': budget.spendingPercentage,
      'isExceeded': budget.isExceeded,
      'isApproachingLimit': budget.isApproachingLimit,
      'daysRemaining': budget.daysRemaining,
      'accountId': budget.accountId,
      'status': _lifecycleStatus(budget),
      'lifetimeSpent': budget.lifetimeSpent,
      'matchedTransactionCount': budget.matchedTransactionCount,
      'endCondition': budget.endCondition,
    };
  }

  /// Get all budget statuses
  Future<List<Map<String, dynamic>>> getAllBudgetStatuses() async {
    final budgets = await _budgetRepository.getAllBudgets();
    final List<Map<String, dynamic>> statuses = [];

    for (final budget in budgets) {
      final status = await getBudgetStatus(budget.id);
      if (status.isNotEmpty) {
        statuses.add(status);
      }
    }

    return statuses;
  }

  /// Get budgets that need alerts
  Future<List<Budget>> getBudgetsNeedingAlerts() async {
    await updateAllBudgetSpending();
    return await _budgetRepository.getBudgetsShouldAlert();
  }

  /// Check if a transaction would exceed budget
  Future<Map<String, dynamic>> checkTransactionAgainstBudget({
    required double amount,
    String? categoryId,
    String? currency,
    String? accountId,
  }) async {
    final warnings = <String>[];
    var wouldExceed = false;
    var matchedBudgets = 0;
    final now = DateTime.now();
    final activeBudgets = await _budgetRepository.getActiveBudgets();

    for (final budget in activeBudgets) {
      if (!budget.isInActivePeriodAt(now)) continue;
      if (currency != null && budget.currency != currency) continue;
      if (budget.accountId != null && budget.accountId != accountId) continue;
      if (budget.categoryId != null && budget.categoryId != categoryId) {
        continue;
      }

      matchedBudgets += 1;
      await _updateBudgetSpending(budget);
      final projectedSpent = budget.currentSpent + amount;
      if (budget.amount <= 0) continue;

      if (projectedSpent > budget.amount) {
        wouldExceed = true;
        warnings.add(
          'Exceeds ${_budgetScopeLabel(budget)} by '
          '${(projectedSpent - budget.amount).toStringAsFixed(2)}',
        );
      } else if ((projectedSpent / budget.amount * 100) >=
          budget.alertThreshold) {
        warnings.add(
          '${_budgetScopeLabel(budget)} reaches '
          '${(projectedSpent / budget.amount * 100).toStringAsFixed(1)}%',
        );
      }
    }

    return {
      'wouldExceed': wouldExceed,
      'warnings': warnings,
      'matchedBudgets': matchedBudgets,
      'canProceed': true, // Always allow, just warn.
    };
  }

  /// Get budget recommendations based on spending patterns
  /// Returns recommendations grouped by currency to avoid mixing currencies.
  Future<Map<String, dynamic>> getBudgetRecommendations({
    required String defaultCurrency,
  }) async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);

    // Get last month's transactions.
    final transactions = await _transactionRepository.getTransactionsInRange(
      lastMonth,
      lastMonthEnd,
    );

    final expenses = transactions.where(
      (transaction) =>
          transaction.isExpense && !transaction.isBalanceAdjustment,
    );

    // Group spending by currency to avoid mixing currencies.
    final Map<String, double> totalSpentByCurrency = {};
    final Map<String, Map<String, double>> categorySpendingByCurrency = {};

    for (final expense in expenses) {
      final expenseCurrency = expense.currency ?? defaultCurrency;

      // Track total spending per currency.
      totalSpentByCurrency[expenseCurrency] =
          (totalSpentByCurrency[expenseCurrency] ?? 0) + expense.amount;

      // Track category spending per currency.
      if (expense.categoryId != null) {
        if (!categorySpendingByCurrency.containsKey(expenseCurrency)) {
          categorySpendingByCurrency[expenseCurrency] = {};
        }
        categorySpendingByCurrency[expenseCurrency]![expense.categoryId!] =
            (categorySpendingByCurrency[expenseCurrency]![expense
                    .categoryId!] ??
                0) +
            expense.amount;
      }
    }

    // Calculate recommendations per currency.
    final Map<String, double> recommendedOverallBudgetByCurrency = {};
    final Map<String, Map<String, double>> categoryRecommendationsByCurrency =
        {};

    for (final entry in totalSpentByCurrency.entries) {
      final expenseCurrency = entry.key;
      final totalSpent = entry.value;
      recommendedOverallBudgetByCurrency[expenseCurrency] =
          totalSpent * 1.1; // 10% buffer

      if (categorySpendingByCurrency.containsKey(expenseCurrency)) {
        categoryRecommendationsByCurrency[expenseCurrency] =
            categorySpendingByCurrency[expenseCurrency]!.map(
              (key, value) => MapEntry(key, value * 1.1),
            );
      }
    }

    return {
      'recommendedOverallBudgetByCurrency': recommendedOverallBudgetByCurrency,
      'categoryRecommendationsByCurrency': categoryRecommendationsByCurrency,
      'basedOnMonth': '${lastMonth.month}/${lastMonth.year}',
    };
  }
}
