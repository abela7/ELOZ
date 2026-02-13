import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/task_type.dart';
import '../../../../data/repositories/task_type_repository.dart';

/// Singleton provider for TaskTypeRepository instance (cached)
final taskTypeRepositoryProvider = Provider<TaskTypeRepository>((ref) {
  return TaskTypeRepository();
});

/// StateNotifier for managing task type list state
class TaskTypeNotifier extends StateNotifier<AsyncValue<List<TaskType>>> {
  final TaskTypeRepository repository;

  TaskTypeNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadTaskTypes();
  }

  /// Load all task types from database
  Future<void> loadTaskTypes() async {
    state = const AsyncValue.loading();
    try {
      final taskTypes = await repository.getAllTaskTypes();
      state = AsyncValue.data(taskTypes);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Add a new task type - optimized: update state immediately
  Future<void> addTaskType(TaskType taskType) async {
    try {
      // Update state immediately for instant UI response
      state.whenData((taskTypes) {
        state = AsyncValue.data([...taskTypes, taskType]);
      });
      // Persist to database in background
      await repository.createTaskType(taskType);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTaskTypes(); // Reload on error
    }
  }

  /// Update an existing task type - optimized: update state immediately
  Future<void> updateTaskType(TaskType taskType) async {
    try {
      // Update state immediately
      state.whenData((taskTypes) {
        final updatedTaskTypes = taskTypes.map((t) => t.id == taskType.id ? taskType : t).toList();
        state = AsyncValue.data(updatedTaskTypes);
      });
      // Persist to database
      await repository.updateTaskType(taskType);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTaskTypes(); // Reload on error
    }
  }

  /// Delete a task type - optimized: update state immediately
  Future<void> deleteTaskType(String id) async {
    try {
      // Update state immediately
      state.whenData((taskTypes) {
        final updatedTaskTypes = taskTypes.where((t) => t.id != id).toList();
        state = AsyncValue.data(updatedTaskTypes);
      });
      // Persist to database
      await repository.deleteTaskType(id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTaskTypes(); // Reload on error
    }
  }
}

/// Provider for TaskTypeNotifier
final taskTypeNotifierProvider =
    StateNotifierProvider<TaskTypeNotifier, AsyncValue<List<TaskType>>>((ref) {
  final repository = ref.watch(taskTypeRepositoryProvider);
  return TaskTypeNotifier(repository);
});

/// Provider for a single task type by ID
final taskTypeByIdProvider = FutureProvider.family<TaskType?, String>((ref, id) async {
  final repository = ref.watch(taskTypeRepositoryProvider);
  return repository.getTaskTypeById(id);
});

