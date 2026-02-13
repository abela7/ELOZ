import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';
import '../local/hive/hive_service.dart';

/// Repository for task CRUD operations using Hive
/// Optimized: Caches box reference to avoid repeated lookups
class TaskRepository {
  static const String boxName = 'tasksBox';
  
  /// Cached box reference for performance
  Box<Task>? _cachedBox;

  /// Get the tasks box (lazy initialization with caching)
  Future<Box<Task>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<Task>(boxName);
    return _cachedBox!;
  }

  /// Create a new task
  Future<void> createTask(Task task) async {
    final box = await _getBox();
    await box.put(task.id, task);
  }

  /// Get all tasks
  Future<List<Task>> getAllTasks() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get task by ID
  Future<Task?> getTaskById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing task
  Future<void> updateTask(Task task) async {
    final box = await _getBox();
    await box.put(task.id, task);
  }

  /// Delete a task
  Future<void> deleteTask(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Get tasks by status
  Future<List<Task>> getTasksByStatus(String status) async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) => task.status == status).toList();
  }

  /// Get tasks for a specific date
  Future<List<Task>> getTasksForDate(DateTime date) async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) {
      final taskDate = task.dueDate;
      return taskDate.year == date.year &&
          taskDate.month == date.month &&
          taskDate.day == date.day;
    }).toList();
  }

  /// Get overdue tasks
  Future<List<Task>> getOverdueTasks() async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) => task.isOverdue).toList();
  }

  /// Get tasks by category
  Future<List<Task>> getTasksByCategory(String categoryId) async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) => task.categoryId == categoryId).toList();
  }

  /// Get tasks by priority
  Future<List<Task>> getTasksByPriority(String priority) async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) => task.priority == priority).toList();
  }

  /// Search tasks by title or description
  Future<List<Task>> searchTasks(String query) async {
    final allTasks = await getAllTasks();
    final lowerQuery = query.toLowerCase();
    return allTasks.where((task) {
      return task.title.toLowerCase().contains(lowerQuery) ||
          (task.description != null &&
              task.description!.toLowerCase().contains(lowerQuery)) ||
          (task.notes != null &&
              task.notes!.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Get task statistics
  Future<Map<String, int>> getTaskStatistics() async {
    final allTasks = await getAllTasks();
    return {
      'total': allTasks.length,
      'pending': allTasks.where((t) => t.status == 'pending').length,
      'completed': allTasks.where((t) => t.status == 'completed').length,
      'overdue': allTasks.where((t) => t.isOverdue).length,
      'postponed': allTasks.where((t) => t.status == 'postponed').length,
    };
  }

  /// Delete all tasks (for reset functionality)
  Future<void> deleteAllTasks() async {
    final box = await _getBox();
    await box.clear();
  }
}

