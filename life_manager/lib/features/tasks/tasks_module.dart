import 'package:hive/hive.dart';
import '../../data/models/task.dart';
import '../../data/models/task_type.dart';
import '../../data/models/category.dart';
import '../../data/models/task_reason.dart';
import '../../data/models/subtask.dart';
import '../../data/models/task_template.dart';
import '../../data/models/simple_reminder.dart';
import '../../data/local/hive/hive_service.dart';
import '../../core/notifications/notification_hub.dart';
import 'notifications/task_notification_adapter.dart';

/// Tasks Module - Handles all Task-related initialization
///
/// This module registers Hive adapters and opens database boxes
/// for the Tasks mini-app. Following the modular super-app pattern,
/// each feature module handles its own initialization.
class TasksModule {
  static bool _initialized = false;
  static bool _boxesPreopened = false;

  /// Initialize the Tasks module
  ///
  /// This should be called during app startup.
  /// It's safe to call multiple times (idempotent).
  static Future<void> init({bool preOpenBoxes = true}) async {
    if (!_initialized) {
      // Register Task-related Hive adapters
      // Each adapter has a unique typeId (0-4 for Tasks module)
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(TaskAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(TaskTypeAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(CategoryAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(TaskReasonAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(SubtaskAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(TaskTemplateAdapter());
      }
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(SimpleReminderAdapter());
      }

      _initialized = true;
    }

    // Register this mini app with the Notification Hub.
    NotificationHub().registerAdapter(TaskNotificationAdapter());

    if (preOpenBoxes && !_boxesPreopened) {
      await HiveService.getBox<Task>('tasksBox');
      await HiveService.getBox<Category>('categoriesBox');
      await HiveService.getBox<TaskType>('taskTypesBox');
      await HiveService.getBox<TaskReason>('taskReasonsBox');
      await HiveService.getBox<TaskTemplate>('task_templates');
      await HiveService.getBox<SimpleReminder>('remindersBox');
      _boxesPreopened = true;
    }
  }

  /// Check if the module is initialized
  static bool get isInitialized => _initialized;

  /// Hive typeId range reserved for Tasks module: 0-9
  /// Other modules should use different ranges:
  /// - Tasks: 0-9
  /// - Habits: 10-19
  /// - Finance: 20-29
  /// - Mood: 30-39
  /// - Time Management: 40-49
  static const int typeIdRangeStart = 0;
  static const int typeIdRangeEnd = 9;
}
