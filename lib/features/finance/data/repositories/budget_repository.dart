import 'package:hive_flutter/hive_flutter.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../models/budget.dart';

/// Repository for budget CRUD operations using Hive
class BudgetRepository {
  static const String boxName = 'budgetsBox';

  /// Cached box reference for performance
  Box<Budget>? _cachedBox;

  /// Get the budgets box (lazy initialization with caching)
  Future<Box<Budget>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<Budget>(boxName);
    return _cachedBox!;
  }

  /// Create a new budget
  Future<void> createBudget(Budget budget) async {
    final box = await _getBox();
    await box.put(budget.id, budget);
  }

  /// Get all budgets
  Future<List<Budget>> getAllBudgets() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get budget by ID
  Future<Budget?> getBudgetById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing budget
  Future<void> updateBudget(Budget budget) async {
    final box = await _getBox();
    await box.put(budget.id, budget);
  }

  /// Delete a budget
  Future<void> deleteBudget(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Get active budgets
  Future<List<Budget>> getActiveBudgets() async {
    final allBudgets = await getAllBudgets();
    return allBudgets.where((b) => b.canTrack).toList();
  }

  /// Get budgets in active period
  Future<List<Budget>> getBudgetsInActivePeriod() async {
    final allBudgets = await getAllBudgets();
    return allBudgets.where((b) => b.isInActivePeriod).toList();
  }

  /// Get budget for a specific category
  Future<Budget?> getBudgetForCategory(String categoryId) async {
    final allBudgets = await getAllBudgets();
    try {
      return allBudgets.firstWhere(
        (b) => b.categoryId == categoryId && b.canTrack,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get overall budget (not category-specific)
  Future<Budget?> getOverallBudget() async {
    final allBudgets = await getAllBudgets();
    try {
      return allBudgets.firstWhere((b) => b.isOverallBudget && b.canTrack);
    } catch (e) {
      return null;
    }
  }

  /// Get budgets by period
  Future<List<Budget>> getBudgetsByPeriod(String period) async {
    final allBudgets = await getAllBudgets();
    return allBudgets.where((b) => b.period == period).toList();
  }

  /// Get exceeded budgets
  Future<List<Budget>> getExceededBudgets() async {
    final allBudgets = await getAllBudgets();
    return allBudgets.where((b) => b.isExceeded && b.canTrack).toList();
  }

  /// Get budgets approaching limit
  Future<List<Budget>> getBudgetsApproachingLimit() async {
    final allBudgets = await getAllBudgets();
    return allBudgets.where((b) => b.isApproachingLimit && b.canTrack).toList();
  }

  /// Get budgets that should trigger alerts
  Future<List<Budget>> getBudgetsShouldAlert() async {
    final allBudgets = await getAllBudgets();
    return allBudgets.where((b) => b.canTrack && b.shouldAlert).toList();
  }

  /// Update budget spent amount
  Future<void> updateBudgetSpent(String budgetId, double amount) async {
    final budget = await getBudgetById(budgetId);
    if (budget != null) {
      budget.currentSpent = amount;
      await updateBudget(budget);
    }
  }

  /// Reset budget for new period
  Future<void> resetBudgetForNewPeriod(String budgetId) async {
    final budget = await getBudgetById(budgetId);
    if (budget != null) {
      budget.resetForNewPeriod();
      await updateBudget(budget);
    }
  }

  /// Delete all budgets (for reset functionality)
  Future<void> deleteAllBudgets() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Reset all budget spending to zero
  /// Used during data reset to clear transaction effects while keeping budget limits
  Future<void> resetAllBudgetSpending() async {
    final box = await _getBox();
    final budgets = box.values.toList();

    for (final budget in budgets) {
      budget.currentSpent = 0.0;
      // Force save
      await box.put(budget.id, budget);
    }

    // Flush to ensure persistence
    await box.flush();
  }
}
