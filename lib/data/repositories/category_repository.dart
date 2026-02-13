import 'package:hive_flutter/hive_flutter.dart';
import '../models/category.dart';
import '../local/hive/hive_service.dart';

/// Repository for category CRUD operations using Hive
class CategoryRepository {
  static const String boxName = 'categoriesBox';
  
  /// Cached box reference for performance
  Box<Category>? _cachedBox;

  /// Get the categories box (lazy initialization with caching)
  Future<Box<Category>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<Category>(boxName);
    return _cachedBox!;
  }

  /// Create a new category
  Future<void> createCategory(Category category) async {
    final box = await _getBox();
    await box.put(category.id, category);
  }

  /// Get all categories
  Future<List<Category>> getAllCategories() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get category by ID
  Future<Category?> getCategoryById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing category
  Future<void> updateCategory(Category category) async {
    final box = await _getBox();
    final updated = category.copyWith(updatedAt: DateTime.now());
    await box.put(category.id, updated);
  }

  /// Delete a category
  Future<void> deleteCategory(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Initialize default categories if none exist
  /// Currently disabled for testing - app starts with empty database
  Future<void> initializeDefaults() async {
    // No default categories - user must create their own
    return;
  }
}

