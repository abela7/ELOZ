import 'package:hive_flutter/hive_flutter.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../models/transaction_category.dart';

/// Repository for transaction category CRUD operations using Hive
class TransactionCategoryRepository {
  static const String boxName = 'transactionCategoriesBox';

  /// Cached box reference for performance
  Box<TransactionCategory>? _cachedBox;

  /// Get the categories box (lazy initialization with caching)
  Future<Box<TransactionCategory>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<TransactionCategory>(boxName);
    return _cachedBox!;
  }

  /// Create a new category
  Future<void> createCategory(TransactionCategory category) async {
    final box = await _getBox();
    await box.put(category.id, category);
  }

  /// Get all categories
  Future<List<TransactionCategory>> getAllCategories() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get category by ID
  Future<TransactionCategory?> getCategoryById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing category
  Future<void> updateCategory(TransactionCategory category) async {
    final box = await _getBox();
    await box.put(category.id, category);
  }

  /// Delete a category
  Future<bool> deleteCategory(String id) async {
    final category = await getCategoryById(id);
    if (category == null) {
      return false;
    }

    final box = await _getBox();
    await box.delete(id);
    return true;
  }

  /// Get categories by type (income, expense, both)
  Future<List<TransactionCategory>> getCategoriesByType(String type) async {
    final allCategories = await getAllCategories();
    return allCategories
        .where((c) => c.type == type || c.type == 'both')
        .toList();
  }

  /// Get income categories
  Future<List<TransactionCategory>> getIncomeCategories() async {
    final allCategories = await getAllCategories();
    return allCategories.where((c) => c.isIncomeCategory).toList();
  }

  /// Get expense categories
  Future<List<TransactionCategory>> getExpenseCategories() async {
    final allCategories = await getAllCategories();
    return allCategories.where((c) => c.isExpenseCategory).toList();
  }

  /// Get parent categories (not subcategories)
  Future<List<TransactionCategory>> getParentCategories() async {
    final allCategories = await getAllCategories();
    return allCategories.where((c) => !c.isSubcategory).toList();
  }

  /// Get subcategories for a parent category
  Future<List<TransactionCategory>> getSubcategories(String parentId) async {
    final allCategories = await getAllCategories();
    return allCategories.where((c) => c.parentCategoryId == parentId).toList();
  }

  /// Get categories with budgets set
  Future<List<TransactionCategory>> getCategoriesWithBudgets() async {
    final allCategories = await getAllCategories();
    return allCategories.where((c) => c.hasBudget).toList();
  }

  /// Search categories by name
  Future<List<TransactionCategory>> searchCategories(String query) async {
    final allCategories = await getAllCategories();
    final lowerQuery = query.toLowerCase();
    return allCategories.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
          (c.description != null &&
              c.description!.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Delete all categories (for reset functionality)
  Future<void> deleteAllCategories() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Deactivate a category (hide it from lists)
  Future<void> deactivateCategory(String id) async {
    final category = await getCategoryById(id);
    if (category != null) {
      category.isActive = false;
      await updateCategory(category);
    }
  }

  /// Reactivate a category (show it in lists)
  Future<void> reactivateCategory(String id) async {
    final category = await getCategoryById(id);
    if (category != null) {
      category.isActive = true;
      await updateCategory(category);
    }
  }

  /// Get only active categories
  Future<List<TransactionCategory>> getActiveCategories() async {
    final allCategories = await getAllCategories();
    return allCategories.where((c) => c.isActive).toList();
  }

  /// Get active expense categories
  Future<List<TransactionCategory>> getActiveExpenseCategories() async {
    final expenseCategories = await getExpenseCategories();
    return expenseCategories.where((c) => c.isActive).toList();
  }

  /// Get active income categories
  Future<List<TransactionCategory>> getActiveIncomeCategories() async {
    final incomeCategories = await getIncomeCategories();
    return incomeCategories.where((c) => c.isActive).toList();
  }
}
