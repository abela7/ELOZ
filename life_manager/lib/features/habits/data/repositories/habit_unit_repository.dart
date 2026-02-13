import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_unit.dart';
import '../models/unit_category.dart';
import '../../../../data/local/hive/hive_service.dart';

/// Repository for HabitUnit CRUD operations using Hive
class HabitUnitRepository {
  static const String boxName = 'habitUnitsBox';

  /// Cached box reference for performance
  Box<HabitUnit>? _cachedBox;

  /// Get the units box (lazy initialization with caching)
  Future<Box<HabitUnit>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<HabitUnit>(boxName);
    return _cachedBox!;
  }

  /// Initialize with default units if empty
  /// IMPORTANT: This requires categories to be initialized first
  Future<void> initializeDefaults(List<UnitCategory> categories) async {
    final box = await _getBox();
    if (box.isEmpty && categories.isNotEmpty) {
      // Find category IDs by name
      final timeCategory = categories.firstWhere((c) => c.name == 'Time');
      final volumeCategory = categories.firstWhere((c) => c.name == 'Volume');
      final weightCategory = categories.firstWhere((c) => c.name == 'Weight');
      final distanceCategory = categories.firstWhere((c) => c.name == 'Distance');
      final countCategory = categories.firstWhere((c) => c.name == 'Count');

      final defaultUnits = [
        ...HabitUnit.createTimeUnits(timeCategory.id),
        ...HabitUnit.createVolumeUnits(volumeCategory.id),
        ...HabitUnit.createWeightUnits(weightCategory.id),
        ...HabitUnit.createDistanceUnits(distanceCategory.id),
        ...HabitUnit.createCountUnits(countCategory.id),
      ];

      for (final unit in defaultUnits) {
        await box.put(unit.id, unit);
      }
    }
  }

  /// Create or update a unit
  Future<void> saveUnit(HabitUnit unit) async {
    final box = await _getBox();
    await box.put(unit.id, unit);
  }

  /// Get all units
  Future<List<HabitUnit>> getAllUnits() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get units by category ID
  Future<List<HabitUnit>> getUnitsByCategoryId(String categoryId) async {
    final box = await _getBox();
    return box.values.where((u) => u.categoryId == categoryId).toList();
  }

  /// Get unit by ID
  Future<HabitUnit?> getUnitById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Get unit by symbol
  Future<HabitUnit?> getUnitBySymbol(String symbol) async {
    final box = await _getBox();
    try {
      return box.values.firstWhere((u) => u.symbol.toLowerCase() == symbol.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Delete all units
  Future<void> deleteAllUnits() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Delete a unit
  Future<bool> deleteUnit(String id) async {
    final box = await _getBox();
    final unit = box.get(id);
    if (unit != null) {
      await box.delete(id);
      return true;
    }
    return false;
  }

  /// Get custom units only
  Future<List<HabitUnit>> getCustomUnits() async {
    final box = await _getBox();
    return box.values.where((u) => !u.isDefault).toList();
  }

  /// Get default units only
  Future<List<HabitUnit>> getDefaultUnits() async {
    final box = await _getBox();
    return box.values.where((u) => u.isDefault).toList();
  }
}
