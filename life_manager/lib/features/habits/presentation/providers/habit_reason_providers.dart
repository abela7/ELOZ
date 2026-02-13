import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit_reason.dart';
import '../../data/repositories/habit_reason_repository.dart';

/// Singleton provider for HabitReasonRepository instance (cached)
final habitReasonRepositoryProvider = Provider<HabitReasonRepository>((ref) {
  return HabitReasonRepository();
});

/// StateNotifier for managing habit reason list state
class HabitReasonNotifier extends StateNotifier<AsyncValue<List<HabitReason>>> {
  final HabitReasonRepository repository;

  HabitReasonNotifier(this.repository) : super(const AsyncValue.loading()) {
    _initialize();
  }

  /// Initialize defaults and load reasons
  Future<void> _initialize() async {
    try {
      // Initialize quit habit default reasons only (Slip & Temptation)
      // Good habit reasons (Not Done & Postpone) were removed as per user request
      await repository.initializeQuitDefaults();
      // Load all reasons
      await loadReasons();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
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
  Future<void> addReason(HabitReason reason) async {
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
  Future<void> updateReason(HabitReason reason) async {
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

  /// Toggle active status of a reason
  Future<void> toggleActive(String id) async {
    try {
      state.whenData((reasons) {
        final updatedReasons = reasons.map((r) {
          if (r.id == id) {
            return r.copyWith(isActive: !r.isActive);
          }
          return r;
        }).toList();
        state = AsyncValue.data(updatedReasons);
        
        // Update in database
        final reason = updatedReasons.firstWhere((r) => r.id == id);
        repository.updateReason(reason);
      });
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadReasons();
    }
  }

  /// Reset all default reasons (restore any deleted defaults)
  Future<void> resetDefaults() async {
    try {
      state = const AsyncValue.loading();
      // Only reset quit habit defaults (Slip & Temptation)
      await repository.initializeQuitDefaults();
      await loadReasons();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

/// Provider for HabitReasonNotifier
final habitReasonNotifierProvider =
    StateNotifierProvider<HabitReasonNotifier, AsyncValue<List<HabitReason>>>((ref) {
  final repository = ref.watch(habitReasonRepositoryProvider);
  return HabitReasonNotifier(repository);
});

/// Provider for "Not Done" reasons only (all, for settings)
final habitNotDoneReasonsProvider = Provider<AsyncValue<List<HabitReason>>>((ref) {
  final allReasons = ref.watch(habitReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => r.typeIndex == 0).toList());
});

/// Provider for "Not Done" reasons only (active only, for dialogs)
final habitActiveNotDoneReasonsProvider = Provider<AsyncValue<List<HabitReason>>>((ref) {
  final allReasons = ref.watch(habitReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => r.typeIndex == 0 && r.isActive).toList());
});

/// Provider for "Postpone" reasons only (all, for settings)
final habitPostponeReasonsProvider = Provider<AsyncValue<List<HabitReason>>>((ref) {
  final allReasons = ref.watch(habitReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => r.typeIndex == 1).toList());
});

/// Provider for "Postpone" reasons only (active only, for dialogs)
final habitActivePostponeReasonsProvider = Provider<AsyncValue<List<HabitReason>>>((ref) {
  final allReasons = ref.watch(habitReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => r.typeIndex == 1 && r.isActive).toList());
});

/// Provider for "Slip" reasons only (all, for settings)
final habitSlipReasonsProvider = Provider<AsyncValue<List<HabitReason>>>((ref) {
  final allReasons = ref.watch(habitReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => r.typeIndex == 2).toList());
});

/// Provider for "Slip" reasons only (active only, for dialogs)
final habitActiveSlipReasonsProvider = Provider<AsyncValue<List<HabitReason>>>((ref) {
  final allReasons = ref.watch(habitReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => r.typeIndex == 2 && r.isActive).toList());
});

/// Provider for "Temptation" reasons only (all, for settings)
final habitTemptationReasonsProvider = Provider<AsyncValue<List<HabitReason>>>((ref) {
  final allReasons = ref.watch(habitReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => r.typeIndex == 3).toList());
});

/// Provider for "Temptation" reasons only (active only, for dialogs)
final habitActiveTemptationReasonsProvider = Provider<AsyncValue<List<HabitReason>>>((ref) {
  final allReasons = ref.watch(habitReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => r.typeIndex == 3 && r.isActive).toList());
});

/// Provider for all quit habit reasons (slip + temptation, all)
final habitQuitReasonsProvider = Provider<AsyncValue<List<HabitReason>>>((ref) {
  final allReasons = ref.watch(habitReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => r.typeIndex == 2 || r.typeIndex == 3).toList());
});

/// Provider for all quit habit reasons (active only, for dialogs)
final habitActiveQuitReasonsProvider = Provider<AsyncValue<List<HabitReason>>>((ref) {
  final allReasons = ref.watch(habitReasonNotifierProvider);
  return allReasons.whenData((reasons) => reasons.where((r) => (r.typeIndex == 2 || r.typeIndex == 3) && r.isActive).toList());
});
