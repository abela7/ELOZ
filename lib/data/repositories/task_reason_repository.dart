import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_reason.dart';
import '../local/hive/hive_service.dart';

/// Repository for task reason CRUD operations using Hive
class TaskReasonRepository {
  static const String boxName = 'taskReasonsBox';

  /// Cached box reference for performance
  Box<TaskReason>? _cachedBox;

  /// Get the reasons box (lazy initialization with caching)
  Future<Box<TaskReason>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<TaskReason>(boxName);
    return _cachedBox!;
  }

  /// Create a new reason
  Future<void> createReason(TaskReason reason) async {
    final box = await _getBox();
    await box.put(reason.id, reason);
  }

  /// Get all reasons
  Future<List<TaskReason>> getAllReasons() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get reasons by type (0 = notDone, 1 = postpone)
  Future<List<TaskReason>> getReasonsByType(int typeIndex) async {
    final box = await _getBox();
    return box.values.where((r) => r.typeIndex == typeIndex).toList();
  }

  /// Get "Not Done" reasons
  Future<List<TaskReason>> getNotDoneReasons() async {
    return getReasonsByType(0);
  }

  /// Get "Postpone" reasons
  Future<List<TaskReason>> getPostponeReasons() async {
    return getReasonsByType(1);
  }

  /// Get reason by ID
  Future<TaskReason?> getReasonById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing reason
  Future<void> updateReason(TaskReason reason) async {
    final box = await _getBox();
    await box.put(reason.id, reason);
  }

  /// Delete a reason
  Future<void> deleteReason(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Initialize with no defaults (app starts empty)
  Future<void> initializeDefaults() async {
    // No default reasons - user creates their own
    return;
  }
}

