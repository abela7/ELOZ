import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit_unit.dart';
import '../../data/repositories/habit_unit_repository.dart';
import 'unit_category_providers.dart';

/// Singleton provider for HabitUnitRepository instance
final habitUnitRepositoryProvider = Provider<HabitUnitRepository>((ref) {
  return HabitUnitRepository();
});

/// StateNotifier for managing habit unit list state
class HabitUnitNotifier extends StateNotifier<AsyncValue<List<HabitUnit>>> {
  final HabitUnitRepository repository;
  final Ref ref;

  HabitUnitNotifier(this.repository, this.ref)
    : super(const AsyncValue.loading()) {
    _initialize();
  }

  /// Initialize with defaults if empty
  Future<void> _initialize() async {
    // Wait for categories to be initialized first
    final categoriesAsync = ref.read(unitCategoryNotifierProvider);
    await categoriesAsync.when(
      data: (categories) async {
        await repository.initializeDefaults(categories);
        await loadUnits();
      },
      loading: () async {
        // Wait a bit and retry
        await Future.delayed(const Duration(milliseconds: 500));
        await _initialize();
      },
      error: (e, stack) async {
        state = AsyncValue.error(e, stack);
      },
    );
  }

  /// Load all units from database
  Future<void> loadUnits() async {
    state = const AsyncValue.loading();
    try {
      final units = await repository.getAllUnits();
      final categories = ref.read(unitCategoryNotifierProvider).valueOrNull;

      // Sort by category sort order, then by name
      if (categories != null && categories.isNotEmpty) {
        units.sort((a, b) {
          final catA = categories.firstWhere(
            (c) => c.id == a.categoryId,
            orElse: () => categories.last,
          );
          final catB = categories.firstWhere(
            (c) => c.id == b.categoryId,
            orElse: () => categories.last,
          );
          final categoryCompare = catA.sortOrder.compareTo(catB.sortOrder);
          if (categoryCompare != 0) return categoryCompare;
          // Put default units first within category
          if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
          return a.name.compareTo(b.name);
        });
      }

      state = AsyncValue.data(units);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Add a new unit - optimized: update state immediately
  Future<void> addUnit(HabitUnit unit) async {
    try {
      final categories = ref.read(unitCategoryNotifierProvider).valueOrNull;

      // Update state immediately
      state.whenData((units) async {
        final newUnits = [...units, unit];
        if (categories != null && categories.isNotEmpty) {
          newUnits.sort((a, b) {
            final catA = categories.firstWhere(
              (c) => c.id == a.categoryId,
              orElse: () => categories.last,
            );
            final catB = categories.firstWhere(
              (c) => c.id == b.categoryId,
              orElse: () => categories.last,
            );
            final categoryCompare = catA.sortOrder.compareTo(catB.sortOrder);
            if (categoryCompare != 0) return categoryCompare;
            if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
            return a.name.compareTo(b.name);
          });
        }
        state = AsyncValue.data(newUnits);
      });
      // Persist to database
      await repository.saveUnit(unit);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadUnits(); // Reload on error
    }
  }

  /// Update an existing unit
  Future<void> updateUnit(HabitUnit unit) async {
    try {
      final updatedUnit = unit.copyWith(updatedAt: DateTime.now());
      // Update state immediately
      state.whenData((units) {
        final updatedUnits = units
            .map((u) => u.id == unit.id ? updatedUnit : u)
            .toList();
        state = AsyncValue.data(updatedUnits);
      });
      // Persist to database
      await repository.saveUnit(updatedUnit);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadUnits();
    }
  }

  /// Delete a unit (only custom units)
  Future<bool> deleteUnit(String id) async {
    try {
      final success = await repository.deleteUnit(id);
      if (success) {
        state.whenData((units) {
          state = AsyncValue.data(units.where((u) => u.id != id).toList());
        });
      }
      return success;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadUnits();
      return false;
    }
  }

  /// Get units by category ID
  List<HabitUnit> getUnitsByCategoryId(String categoryId) {
    return state.maybeWhen(
      data: (units) => units.where((u) => u.categoryId == categoryId).toList(),
      orElse: () => [],
    );
  }

  /// Get unit by ID
  HabitUnit? getUnitById(String id) {
    return state.maybeWhen(
      data: (units) {
        try {
          return units.firstWhere((u) => u.id == id);
        } catch (e) {
          return null;
        }
      },
      orElse: () => null,
    );
  }
}

/// Provider for HabitUnitNotifier
final habitUnitNotifierProvider =
    StateNotifierProvider<HabitUnitNotifier, AsyncValue<List<HabitUnit>>>((
      ref,
    ) {
      final repository = ref.watch(habitUnitRepositoryProvider);
      return HabitUnitNotifier(repository, ref);
    });

/// Provider for units grouped by category ID
final unitsByCategoryIdProvider = Provider<Map<String, List<HabitUnit>>>((ref) {
  final unitsAsync = ref.watch(habitUnitNotifierProvider);
  final categoriesAsync = ref.watch(unitCategoryNotifierProvider);

  return unitsAsync.maybeWhen(
    data: (units) {
      return categoriesAsync.maybeWhen(
        data: (categories) {
          final grouped = <String, List<HabitUnit>>{};
          for (final category in categories) {
            grouped[category.id] = units
                .where((u) => u.categoryId == category.id)
                .toList();
          }
          return grouped;
        },
        orElse: () => {},
      );
    },
    orElse: () => {},
  );
});

/// Provider for custom units only
final customUnitsProvider = Provider<List<HabitUnit>>((ref) {
  final unitsAsync = ref.watch(habitUnitNotifierProvider);
  return unitsAsync.maybeWhen(
    data: (units) => units.where((u) => !u.isDefault).toList(),
    orElse: () => [],
  );
});
