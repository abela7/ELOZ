import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/unit_category.dart';
import '../../data/repositories/unit_category_repository.dart';

/// Singleton provider for UnitCategoryRepository instance
final unitCategoryRepositoryProvider = Provider<UnitCategoryRepository>((ref) {
  return UnitCategoryRepository();
});

/// StateNotifier for managing unit category list state
class UnitCategoryNotifier extends StateNotifier<AsyncValue<List<UnitCategory>>> {
  final UnitCategoryRepository repository;

  UnitCategoryNotifier(this.repository) : super(const AsyncValue.loading()) {
    _initialize();
  }

  /// Initialize with defaults if empty
  Future<void> _initialize() async {
    await repository.initializeDefaults();
    await loadCategories();
  }

  /// Load all categories from database
  Future<void> loadCategories() async {
    state = const AsyncValue.loading();
    try {
      final categories = await repository.getAllCategories();
      state = AsyncValue.data(categories);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Add a new category - optimized: update state immediately
  Future<void> addCategory(UnitCategory category) async {
    try {
      // Update state immediately
      state.whenData((categories) {
        final newCategories = [...categories, category];
        newCategories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        state = AsyncValue.data(newCategories);
      });
      // Persist to database
      await repository.saveCategory(category);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadCategories(); // Reload on error
    }
  }

  /// Update an existing category
  Future<void> updateCategory(UnitCategory category) async {
    try {
      final updatedCategory = category.copyWith(updatedAt: DateTime.now());
      // Update state immediately
      state.whenData((categories) {
        final updatedCategories = categories.map((c) => c.id == category.id ? updatedCategory : c).toList();
        updatedCategories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        state = AsyncValue.data(updatedCategories);
      });
      // Persist to database
      await repository.saveCategory(updatedCategory);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadCategories();
    }
  }

  /// Delete a category (only custom categories)
  Future<bool> deleteCategory(String id) async {
    try {
      final success = await repository.deleteCategory(id);
      if (success) {
        state.whenData((categories) {
          state = AsyncValue.data(categories.where((c) => c.id != id).toList());
        });
      }
      return success;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadCategories();
      return false;
    }
  }

  /// Get category by ID
  UnitCategory? getCategoryById(String id) {
    return state.maybeWhen(
      data: (categories) {
        try {
          return categories.firstWhere((c) => c.id == id);
        } catch (e) {
          return null;
        }
      },
      orElse: () => null,
    );
  }

  /// Get next sort order for new categories
  int getNextSortOrder() {
    return state.maybeWhen(
      data: (categories) {
        if (categories.isEmpty) return 1;
        final maxOrder = categories.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);
        return maxOrder + 1;
      },
      orElse: () => 1,
    );
  }
}

/// Provider for UnitCategoryNotifier
final unitCategoryNotifierProvider =
    StateNotifierProvider<UnitCategoryNotifier, AsyncValue<List<UnitCategory>>>((ref) {
  final repository = ref.watch(unitCategoryRepositoryProvider);
  return UnitCategoryNotifier(repository);
});

/// Provider for custom categories only
final customUnitCategoriesProvider = Provider<List<UnitCategory>>((ref) {
  final categoriesAsync = ref.watch(unitCategoryNotifierProvider);
  return categoriesAsync.maybeWhen(
    data: (categories) => categories.where((c) => !c.isDefault).toList(),
    orElse: () => [],
  );
});

/// Provider for default categories only
final defaultUnitCategoriesProvider = Provider<List<UnitCategory>>((ref) {
  final categoriesAsync = ref.watch(unitCategoryNotifierProvider);
  return categoriesAsync.maybeWhen(
    data: (categories) => categories.where((c) => c.isDefault).toList(),
    orElse: () => [],
  );
});
