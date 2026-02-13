import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/category.dart';
import '../../../../data/repositories/category_repository.dart';

/// Singleton provider for CategoryRepository instance (cached)
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

/// StateNotifier for managing category list state
class CategoryNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  final CategoryRepository repository;

  CategoryNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadCategories();
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
  Future<void> addCategory(Category category) async {
    try {
      // Update state immediately for instant UI response
      state.whenData((categories) {
        state = AsyncValue.data([...categories, category]);
      });
      // Persist to database in background
      await repository.createCategory(category);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadCategories(); // Reload on error
    }
  }

  /// Update an existing category - optimized: update state immediately
  Future<void> updateCategory(Category category) async {
    try {
      // Update state immediately
      state.whenData((categories) {
        final updatedCategories = categories.map((c) => c.id == category.id ? category : c).toList();
        state = AsyncValue.data(updatedCategories);
      });
      // Persist to database
      await repository.updateCategory(category);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadCategories(); // Reload on error
    }
  }

  /// Delete a category - optimized: update state immediately
  Future<void> deleteCategory(String id) async {
    try {
      // Update state immediately
      state.whenData((categories) {
        final updatedCategories = categories.where((c) => c.id != id).toList();
        state = AsyncValue.data(updatedCategories);
      });
      // Persist to database
      await repository.deleteCategory(id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadCategories(); // Reload on error
    }
  }
}

/// Provider for CategoryNotifier
final categoryNotifierProvider =
    StateNotifierProvider<CategoryNotifier, AsyncValue<List<Category>>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return CategoryNotifier(repository);
});

/// Provider for a single category by ID
final categoryByIdProvider = FutureProvider.family<Category?, String>((ref, id) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getCategoryById(id);
});

