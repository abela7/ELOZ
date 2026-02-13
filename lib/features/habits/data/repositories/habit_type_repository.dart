import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_type.dart';
import '../../../../data/local/hive/hive_service.dart';

/// Repository for habit type CRUD operations using Hive
class HabitTypeRepository {
  static const String boxName = 'habitTypesBox';

  /// Cached box reference for performance
  Box<HabitType>? _cachedBox;

  /// Get the habit types box (lazy initialization with caching)
  Future<Box<HabitType>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<HabitType>(boxName);
    return _cachedBox!;
  }

  /// Create a new habit type
  Future<void> createHabitType(HabitType habitType) async {
    final box = await _getBox();
    await box.put(habitType.id, habitType);
  }

  /// Get all habit types
  Future<List<HabitType>> getAllHabitTypes() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get habit type by ID
  Future<HabitType?> getHabitTypeById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing habit type
  Future<void> updateHabitType(HabitType habitType) async {
    final box = await _getBox();
    await box.put(habitType.id, habitType);
  }

  /// Delete a habit type
  Future<void> deleteHabitType(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Delete all habit types
  Future<void> deleteAllHabitTypes() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Initialize with no defaults (app starts empty)
  Future<void> initializeDefaults() async {
    // No default habit types - user creates their own
    return;
  }
}
