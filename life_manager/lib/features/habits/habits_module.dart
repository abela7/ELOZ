import 'package:hive/hive.dart';
import 'data/models/habit.dart';
import 'data/models/habit_completion.dart';
import 'data/models/habit_reason.dart';
import 'data/models/habit_type.dart';
import 'data/models/completion_type_config.dart';
import 'data/models/habit_category.dart';
import 'data/models/unit_category.dart';
import 'data/models/habit_unit.dart';
import 'data/models/temptation_log.dart';
import '../../data/local/hive/hive_service.dart';
import '../../core/notifications/notification_hub.dart';
import 'notifications/habit_notification_adapter.dart';

/// Habits Module - Handles all Habit-related initialization
///
/// This module registers Hive adapters and opens database boxes
/// for the Habits mini-app. Following the modular super-app pattern,
/// each feature module handles its own initialization.
///
/// TypeId Range: 10-19 (reserved for Habits module)
class HabitsModule {
  static bool _initialized = false;
  static bool _boxesPreopened = false;

  /// Initialize the Habits module
  ///
  /// This should be called during app startup.
  /// It's safe to call multiple times (idempotent).
  static Future<void> init({bool preOpenBoxes = true}) async {
    if (!_initialized) {
      // Register Habit-related Hive adapters
      // TypeIds 10-19 are reserved for Habits module
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(HabitAdapter());
      }
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(HabitCompletionAdapter());
      }
      if (!Hive.isAdapterRegistered(12)) {
        Hive.registerAdapter(HabitReasonAdapter());
      }
      if (!Hive.isAdapterRegistered(13)) {
        Hive.registerAdapter(HabitTypeAdapter());
      }
      if (!Hive.isAdapterRegistered(14)) {
        Hive.registerAdapter(CompletionTypeConfigAdapter());
      }
      if (!Hive.isAdapterRegistered(15)) {
        Hive.registerAdapter(HabitUnitAdapter());
      }
      if (!Hive.isAdapterRegistered(16)) {
        Hive.registerAdapter(UnitCategoryAdapter());
      }
      if (!Hive.isAdapterRegistered(17)) {
        Hive.registerAdapter(TemptationLogAdapter());
      }
      if (!Hive.isAdapterRegistered(18)) {
        Hive.registerAdapter(HabitCategoryAdapter());
      }

      _initialized = true;
    }

    // Register this mini app with the Notification Hub.
    NotificationHub().registerAdapter(HabitNotificationAdapter());

    if (preOpenBoxes && !_boxesPreopened) {
      // IMPORTANT: Open unit categories box BEFORE units box (units depend on categories)
      await HiveService.getBox<Habit>('habitsBox');
      await HiveService.getBox<HabitCompletion>('habitCompletionsBox');
      await HiveService.getBox<HabitReason>('habitReasonsBox');
      await HiveService.getBox<HabitType>('habitTypesBox');
      await HiveService.getBox<CompletionTypeConfig>(
        'completionTypeConfigsBox',
      );
      await HiveService.getBox<HabitCategory>('habitCategoriesBox');
      await HiveService.getBox<UnitCategory>('unitCategoriesBox');
      await HiveService.getBox<HabitUnit>('habitUnitsBox');
      await HiveService.getBox<TemptationLog>('temptationLogsBox');
      _boxesPreopened = true;
    }
  }

  /// Check if the module is initialized
  static bool get isInitialized => _initialized;

  /// Hive typeId range reserved for Habits module: 10-19
  /// - 10: Habit
  /// - 11: HabitCompletion
  /// - 12: HabitReason
  /// - 13: HabitType
  /// - 14: CompletionTypeConfig
  /// - 15: HabitUnit
  /// - 16: UnitCategory
  /// - 17: TemptationLog
  /// - 18: HabitCategory
  /// - 19: Reserved for future Habit-related models
  static const int typeIdRangeStart = 10;
  static const int typeIdRangeEnd = 19;
}
