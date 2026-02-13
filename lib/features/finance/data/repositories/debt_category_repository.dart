import 'package:hive_flutter/hive_flutter.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../models/debt_category.dart';

/// Repository for debt category CRUD operations using Hive
class DebtCategoryRepository {
  static const String boxName = 'debtCategoriesBox';

  /// Cached box reference for performance
  Box<DebtCategory>? _cachedBox;

  /// Get the debt categories box (lazy initialization with caching)
  Future<Box<DebtCategory>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<DebtCategory>(boxName);
    return _cachedBox!;
  }

  /// Create a new debt category
  Future<void> createCategory(DebtCategory category) async {
    final box = await _getBox();
    await box.put(category.id, category);
  }

  /// Get all debt categories
  Future<List<DebtCategory>> getAllCategories() async {
    final box = await _getBox();
    return box.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get category by ID
  Future<DebtCategory?> getCategoryById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing category
  Future<void> updateCategory(DebtCategory category) async {
    final box = await _getBox();
    await box.put(category.id, category);
    if (category.isInBox) {
      await category.save();
    }
  }

  /// Delete a category
  Future<void> deleteCategory(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Get active categories
  Future<List<DebtCategory>> getActiveCategories() async {
    final all = await getAllCategories();
    return all.where((c) => c.isActive).toList();
  }

  /// Delete all categories
  Future<void> deleteAllCategories() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Check if any categories exist
  Future<bool> hasCategories() async {
    final box = await _getBox();
    return box.isNotEmpty;
  }
}
