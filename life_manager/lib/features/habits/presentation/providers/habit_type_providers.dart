import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit_type.dart';
import '../../data/repositories/habit_type_repository.dart';

/// Singleton provider for HabitTypeRepository instance (cached)
final habitTypeRepositoryProvider = Provider<HabitTypeRepository>((ref) {
  return HabitTypeRepository();
});

/// StateNotifier for managing habit type list state
class HabitTypeNotifier extends StateNotifier<AsyncValue<List<HabitType>>> {
  final HabitTypeRepository repository;

  HabitTypeNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadHabitTypes();
  }

  /// Load all habit types from database
  Future<void> loadHabitTypes() async {
    state = const AsyncValue.loading();
    try {
      final habitTypes = await repository.getAllHabitTypes();
      state = AsyncValue.data(habitTypes);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Add a new habit type - optimized: update state immediately
  Future<void> addHabitType(HabitType habitType) async {
    try {
      // Update state immediately for instant UI response
      state.whenData((habitTypes) {
        state = AsyncValue.data([...habitTypes, habitType]);
      });
      // Persist to database in background
      await repository.createHabitType(habitType);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabitTypes(); // Reload on error
    }
  }

  /// Update an existing habit type - optimized: update state immediately
  Future<void> updateHabitType(HabitType habitType) async {
    try {
      // Update state immediately
      state.whenData((habitTypes) {
        final updatedTypes = habitTypes.map((ht) => ht.id == habitType.id ? habitType : ht).toList();
        state = AsyncValue.data(updatedTypes);
      });
      // Persist to database
      await repository.updateHabitType(habitType);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabitTypes(); // Reload on error
    }
  }

  /// Delete a habit type - optimized: update state immediately
  Future<void> deleteHabitType(String id) async {
    try {
      // Update state immediately
      state.whenData((habitTypes) {
        final updatedTypes = habitTypes.where((ht) => ht.id != id).toList();
        state = AsyncValue.data(updatedTypes);
      });
      // Persist to database
      await repository.deleteHabitType(id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadHabitTypes(); // Reload on error
    }
  }
}

/// Provider for HabitTypeNotifier
final habitTypeNotifierProvider =
    StateNotifierProvider<HabitTypeNotifier, AsyncValue<List<HabitType>>>((ref) {
  final repository = ref.watch(habitTypeRepositoryProvider);
  return HabitTypeNotifier(repository);
});
