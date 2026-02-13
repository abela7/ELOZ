import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/temptation_log.dart';
import '../../data/repositories/temptation_log_repository.dart';

/// Repository provider
final temptationLogRepositoryProvider = Provider<TemptationLogRepository>((ref) {
  return TemptationLogRepository();
});

/// Main state notifier for temptation logs
class TemptationLogNotifier extends StateNotifier<AsyncValue<List<TemptationLog>>> {
  final TemptationLogRepository repository;
  final String? habitId;

  TemptationLogNotifier(this.repository, {this.habitId}) 
      : super(const AsyncValue.loading()) {
    loadLogs();
  }

  /// Load logs (all or for specific habit)
  Future<void> loadLogs() async {
    state = const AsyncValue.loading();
    try {
      final logs = habitId != null 
          ? await repository.getLogsForHabit(habitId!)
          : await repository.getAllLogs();
      state = AsyncValue.data(logs);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Add a new temptation log
  Future<void> addLog(TemptationLog log) async {
    try {
      // Optimistic update
      state.whenData((logs) {
        state = AsyncValue.data([log, ...logs]);
      });
      // Persist
      await repository.createLog(log);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadLogs();
    }
  }

  /// Update an existing log
  Future<void> updateLog(TemptationLog log) async {
    try {
      state.whenData((logs) {
        final updatedLogs = logs.map((l) => l.id == log.id ? log : l).toList();
        state = AsyncValue.data(updatedLogs);
      });
      await repository.updateLog(log);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadLogs();
    }
  }

  /// Delete a log
  Future<void> deleteLog(String id) async {
    try {
      state.whenData((logs) {
        state = AsyncValue.data(logs.where((l) => l.id != id).toList());
      });
      await repository.deleteLog(id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadLogs();
    }
  }
}

/// Provider for all temptation logs
final temptationLogNotifierProvider = 
    StateNotifierProvider<TemptationLogNotifier, AsyncValue<List<TemptationLog>>>((ref) {
  final repository = ref.watch(temptationLogRepositoryProvider);
  return TemptationLogNotifier(repository);
});

/// Provider for temptation logs of a specific habit
final habitTemptationLogsProvider = 
    StateNotifierProvider.family<TemptationLogNotifier, AsyncValue<List<TemptationLog>>, String>(
  (ref, habitId) {
    final repository = ref.watch(temptationLogRepositoryProvider);
    return TemptationLogNotifier(repository, habitId: habitId);
  },
);

/// Provider for today's temptation count for a habit
final todayTemptationCountProvider = FutureProvider.family<int, String>((ref, habitId) async {
  final repository = ref.watch(temptationLogRepositoryProvider);
  return repository.getTodayCountForHabit(habitId);
});

/// Provider for total temptation count for a habit
final totalTemptationCountProvider = FutureProvider.family<int, String>((ref, habitId) async {
  final repository = ref.watch(temptationLogRepositoryProvider);
  return repository.getTotalCountForHabit(habitId);
});

/// Provider for temptation reason stats
final temptationReasonStatsProvider = FutureProvider.family<Map<String, int>, String>((ref, habitId) async {
  final repository = ref.watch(temptationLogRepositoryProvider);
  return repository.getReasonStats(habitId);
});

/// Provider for temptation intensity stats
final temptationIntensityStatsProvider = FutureProvider.family<Map<int, int>, String>((ref, habitId) async {
  final repository = ref.watch(temptationLogRepositoryProvider);
  return repository.getIntensityStats(habitId);
});

/// Provider for days without temptation
final daysWithoutTemptationProvider = FutureProvider.family<int, String>((ref, habitId) async {
  final repository = ref.watch(temptationLogRepositoryProvider);
  return repository.getDaysWithoutTemptation(habitId);
});
