import 'package:hive_flutter/hive_flutter.dart';
import '../models/unit_category.dart';
import '../../../../data/local/hive/hive_service.dart';

/// Repository for UnitCategory CRUD operations using Hive
class UnitCategoryRepository {
  static const String boxName = 'unitCategoriesBox';

  /// Cached box reference for performance
  Box<UnitCategory>? _cachedBox;

  /// Get the categories box (lazy initialization with caching)
  Future<Box<UnitCategory>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<UnitCategory>(boxName);
    return _cachedBox!;
  }

  /// Initialize with default categories if empty
  Future<void> initializeDefaults() async {
    final box = await _getBox();
    if (box.isEmpty) {
      final defaultCategories = UnitCategory.getAllDefaultCategories();
      for (final category in defaultCategories) {
        await box.put(category.id, category);
      }
    }
  }

  /// Create or update a category
  Future<void> saveCategory(UnitCategory category) async {
    final box = await _getBox();
    await box.put(category.id, category);
  }

  /// Get all categories
  Future<List<UnitCategory>> getAllCategories() async {
    final box = await _getBox();
    final categories = box.values.toList();
    // Sort by sortOrder
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  /// Get category by ID
  Future<UnitCategory?> getCategoryById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Delete a category
  Future<bool> deleteCategory(String id) async {
    final box = await _getBox();
    final category = box.get(id);
    if (category != null) {
      await box.delete(id);
      return true;
    }
    return false;
  }

  /// Delete all unit categories
  Future<void> deleteAllCategories() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Get custom categories only
  Future<List<UnitCategory>> getCustomCategories() async {
    final box = await _getBox();
    return box.values.where((c) => !c.isDefault).toList();
  }

  /// Get default categories only
  Future<List<UnitCategory>> getDefaultCategories() async {
    final box = await _getBox();
    return box.values.where((c) => c.isDefault).toList();
  }

  /// Get category by name
  Future<UnitCategory?> getCategoryByName(String name) async {
    final box = await _getBox();
    try {
      return box.values.firstWhere((c) => c.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      return null;
    }
  }
}
