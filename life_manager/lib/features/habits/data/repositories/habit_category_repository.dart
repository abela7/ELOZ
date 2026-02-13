import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_category.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../../../../data/models/category.dart';

/// Repository for habit category CRUD operations using Hive
class HabitCategoryRepository {
  static const String boxName = 'habitCategoriesBox';

  Box<HabitCategory>? _cachedBox;

  Future<Box<HabitCategory>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<HabitCategory>(boxName);
    await _importLegacyCategoriesIfNeeded(_cachedBox!);
    return _cachedBox!;
  }

  Future<void> createCategory(HabitCategory category) async {
    final box = await _getBox();
    await box.put(category.id, category);
  }

  Future<List<HabitCategory>> getAllCategories() async {
    final box = await _getBox();
    return box.values.toList();
  }

  Future<HabitCategory?> getCategoryById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  Future<void> updateCategory(HabitCategory category) async {
    final box = await _getBox();
    final updated = category.copyWith(updatedAt: DateTime.now());
    await box.put(category.id, updated);
  }

  Future<void> deleteCategory(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Delete all habit categories
  Future<void> deleteAllCategories() async {
    final box = await _getBox();
    await box.clear();
  }

  Future<void> _importLegacyCategoriesIfNeeded(Box<HabitCategory> box) async {
    if (box.isNotEmpty) return;

    try {
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(CategoryAdapter());
      }
      final legacyBox = await HiveService.getBox<Category>('categoriesBox');
      if (legacyBox.values.isEmpty) return;

      for (final legacy in legacyBox.values) {
        final migrated = HabitCategory(
          id: legacy.id,
          name: legacy.name,
          iconCodePoint: int.tryParse(legacy.iconCodePoint) ?? legacy.icon.codePoint,
          iconFontFamily: legacy.iconFontFamily.isEmpty ? null : legacy.iconFontFamily,
          iconFontPackage: legacy.iconFontPackage.isEmpty ? null : legacy.iconFontPackage,
          colorValue: legacy.colorValue,
          createdAt: legacy.createdAt,
          updatedAt: legacy.updatedAt,
        );
        await box.put(migrated.id, migrated);
      }
    } catch (_) {
      // Ignore legacy migration failures
    }
  }
}
