import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit_category.dart';
import '../../data/repositories/habit_category_repository.dart';

/// Repository provider for habit categories
final habitCategoryRepositoryProvider = Provider<HabitCategoryRepository>((ref) {
  return HabitCategoryRepository();
});

/// StateNotifier for managing habit categories
class HabitCategoryNotifier extends StateNotifier<AsyncValue<List<HabitCategory>>> {
  final HabitCategoryRepository repository;

  HabitCategoryNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = const AsyncValue.loading();
    try {
      final categories = await repository.getAllCategories();
      state = AsyncValue.data(categories);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> addCategory(HabitCategory category) async {
    try {
      state.whenData((categories) {
        state = AsyncValue.data([...categories, category]);
      });
      await repository.createCategory(category);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadCategories();
    }
  }

  Future<void> updateCategory(HabitCategory category) async {
    try {
      state.whenData((categories) {
        final updated = categories.map((c) => c.id == category.id ? category : c).toList();
        state = AsyncValue.data(updated);
      });
      await repository.updateCategory(category);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadCategories();
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      state.whenData((categories) {
        state = AsyncValue.data(categories.where((c) => c.id != id).toList());
      });
      await repository.deleteCategory(id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadCategories();
    }
  }
}

final habitCategoryNotifierProvider =
    StateNotifierProvider<HabitCategoryNotifier, AsyncValue<List<HabitCategory>>>((ref) {
  final repository = ref.watch(habitCategoryRepositoryProvider);
  return HabitCategoryNotifier(repository);
});

final habitCategoryByIdProvider = FutureProvider.family<HabitCategory?, String>((ref, id) async {
  final repository = ref.watch(habitCategoryRepositoryProvider);
  return repository.getCategoryById(id);
});
