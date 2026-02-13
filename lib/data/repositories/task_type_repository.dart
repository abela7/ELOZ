import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_type.dart';
import '../local/hive/hive_service.dart';

/// Repository for task type CRUD operations using Hive
class TaskTypeRepository {
  static const String boxName = 'taskTypesBox';
  
  /// Cached box reference for performance
  Box<TaskType>? _cachedBox;

  /// Get the task types box (lazy initialization with caching)
  Future<Box<TaskType>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<TaskType>(boxName);
    return _cachedBox!;
  }

  /// Create a new task type
  Future<void> createTaskType(TaskType taskType) async {
    final box = await _getBox();
    await box.put(taskType.id, taskType);
  }

  /// Get all task types
  Future<List<TaskType>> getAllTaskTypes() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get task type by ID
  Future<TaskType?> getTaskTypeById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing task type
  Future<void> updateTaskType(TaskType taskType) async {
    final box = await _getBox();
    final updated = taskType.copyWith(updatedAt: DateTime.now());
    await box.put(taskType.id, updated);
  }

  /// Delete a task type
  Future<void> deleteTaskType(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Initialize default task types if none exist
  /// Currently disabled for testing - app starts with empty database
  Future<void> initializeDefaults() async {
    // No default task types - user must create their own
    return;
  }
}

