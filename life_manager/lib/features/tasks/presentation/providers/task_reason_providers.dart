import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/task_reason.dart';
import '../../../../data/repositories/task_reason_repository.dart';

/// Singleton provider for TaskReasonRepository instance (cached)
final taskReasonRepositoryProvider = Provider<TaskReasonRepository>((ref) {
  return TaskReasonRepository();
});

/// StateNotifier for managing task reason list state
class TaskReasonNotifier extends StateNotifier<AsyncValue<List<TaskReason>>> {
  final TaskReasonRepository repository;

  TaskReasonNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadReasons();
  }

  /// Load all reasons from database
  Future<void> loadReasons() async {
    state = const AsyncValue.loading();
    try {
      final reasons = await repository.getAllReasons();
      state = AsyncValue.data(reasons);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Add a new reason - optimized: update state immediately
  Future<void> addReason(TaskReason reason) async {
    try {
      // Update state immediately for instant UI response
      state.whenData((reasons) {
        state = AsyncValue.data([...reasons, reason]);
      });
      // Persist to database in background
      await repository.createReason(reason);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadReasons(); // Reload on error
    }
  }

  /// Update an existing reason - optimized: update state immediately
  Future<void> updateReason(TaskReason reason) async {
    try {
      // Update state immediately
      state.whenData((reasons) {
        final updatedReasons = reasons.map((r) => r.id == reason.id ? reason : r).toList();
        state = AsyncValue.data(updatedReasons);
      });
      // Persist to database
      await repository.updateReason(reason);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadReasons(); // Reload on error
    }
  }

  /// Delete a reason - optimized: update state immediately
  Future<void> deleteReason(String id) async {
    try {
      // Update state immediately
      state.whenData((reasons) {
        final updatedReasons = reasons.where((r) => r.id != id).toList();
        state = AsyncValue.data(updatedReasons);
      });
      // Persist to database
      await repository.deleteReason(id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadReasons(); // Reload on error
    }
  }
}

/// Provider for TaskReasonNotifier
final taskReasonNotifierProvider =
    StateNotifierProvider<TaskReasonNotifier, AsyncValue<List<TaskReason>>>((ref) {
  final repository = ref.watch(taskReasonRepositoryProvider);
  return TaskReasonNotifier(repository);
});

/// Provider for "Not Done" reasons only
final notDoneReasonsProvider = Provider<AsyncValue<List<TaskReason>>>((ref) {
  final allReasons = ref.watch(taskReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => r.typeIndex == 0).toList());
});

/// Provider for "Postpone" reasons only
final postponeReasonsProvider = Provider<AsyncValue<List<TaskReason>>>((ref) {
  final allReasons = ref.watch(taskReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => r.typeIndex == 1).toList());
});

