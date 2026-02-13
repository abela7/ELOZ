import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../data/local/hive/hive_service.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../features/finance/data/services/finance_notification_settings_service.dart';
import '../../../features/finance/finance_module.dart';
import '../../../core/services/alarm_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/reminder_manager.dart';
import '../../../features/finance/notifications/finance_notification_scheduler.dart';
import '../../../features/habits/data/repositories/habit_repository.dart';
import '../../../features/habits/habits_module.dart';
import '../../../features/habits/services/habit_reminder_service.dart';
import '../../../features/sleep/sleep_module.dart';
import '../../../features/tasks/tasks_module.dart';
import '../notification_hub.dart';
import 'universal_notification_repository.dart';
import 'universal_notification_scheduler.dart';

/// Recovery service for notification schedules (nek12.dev "100% reliable" Layer 3).
///
/// Runs a full resync of Finance + Universal + legacy Task/Habit notifications.
/// Used by:
/// - WorkManager periodic task (safety net when app is killed)
/// - App-open health check (Layer 4)
/// - NotificationSystemRefresher (resume-after-15min)
///
/// When invoked from WorkManager, the app may be killed – this service performs
/// a minimal bootstrap (Hive + modules) before syncing.
class NotificationRecoveryService {
  NotificationRecoveryService._();

  static const String _taskName = 'notificationRecovery';

  /// Performs full notification schedule sync.
  ///
  /// Call from WorkManager callback or app context. If [bootstrapForBackground]
  /// is true, initializes Hive and modules first (required when app was killed).
  static Future<NotificationRecoveryResult> runRecovery({
    bool bootstrapForBackground = false,
  }) async {
    try {
      if (bootstrapForBackground) {
        await _bootstrapForBackground();
      }

      final hub = NotificationHub();
      await hub.initialize();

      var financeScheduled = 0;
      var financeCancelled = 0;

      final settingsService = FinanceNotificationSettingsService();
      final settings = await settingsService.load();
      if (settings.notificationsEnabled) {
        final financeResult =
            await FinanceNotificationScheduler().syncSchedules();
        financeScheduled = financeResult.scheduled;
        financeCancelled = financeResult.cancelled;
      }

      await UniversalNotificationScheduler().syncAll();

      // ── Legacy Task/Habit reminder resync ──────────────────────────
      // Only when running in app context (not WorkManager): the native
      // AlarmService uses MethodChannel from MainActivity, which is not
      // available in the headless WorkManager engine. Skipping avoids
      // MissingPluginException. User's next app open will run health
      // check with bootstrapForBackground=false and resync then.
      var taskRescheduled = 0;
      var habitRescheduled = 0;

      if (!bootstrapForBackground) {
        // Prune orphaned native alarms (entities deleted but alarms still in
        // AlarmBootReceiver storage). Android has no API to list AlarmManager
        // alarms; we must scan our own persistence.
        final pruned = await _pruneOrphanedAlarms();
        if (pruned > 0 && kDebugMode) {
          debugPrint(
            'NotificationRecoveryService: pruned $pruned orphaned native alarm(s)',
          );
        }

        try {
          final tasks = await TaskRepository().getAllTasks();
          final reminderManager = ReminderManager();
          for (final task in tasks) {
            if (_taskNeedsReminders(task)) {
              await reminderManager.rescheduleRemindersForTask(task);
              taskRescheduled++;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'NotificationRecoveryService: task resync failed: $e',
            );
          }
        }

        try {
          final habits = await HabitRepository().getAllHabits();
          final habitService = HabitReminderService();
          for (final habit in habits) {
            if (habit.reminderEnabled &&
                (habit.reminderDuration ?? '').isNotEmpty) {
              await habitService.rescheduleHabitReminders(habit);
              habitRescheduled++;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'NotificationRecoveryService: habit resync failed: $e',
            );
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
          'NotificationRecoveryService: sync complete – '
          'Finance: $financeScheduled scheduled, $financeCancelled cleared, '
          'Tasks: $taskRescheduled resynced, '
          'Habits: $habitRescheduled resynced',
        );
      }

      return NotificationRecoveryResult(
        success: true,
        financeScheduled: financeScheduled,
        financeCancelled: financeCancelled,
        taskRescheduled: taskRescheduled,
        habitRescheduled: habitRescheduled,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('NotificationRecoveryService: recovery failed: $e');
        debugPrintStack(stackTrace: st);
      }
      return NotificationRecoveryResult(success: false, error: e.toString());
    }
  }

  /// Minimal bootstrap when running in background (e.g. WorkManager).
  ///
  /// Initializes Hive and modules required for notification sync.
  static Future<void> _bootstrapForBackground() async {
    // Flutter bindings for plugins (path_provider, shared_preferences, etc.)
    // WidgetsFlutterBinding is done by WorkManager before invoking callback.

    if (!HiveService.isInitialized) {
      await HiveService.init();
    }

    await TasksModule.init(preOpenBoxes: true);
    await HabitsModule.init(preOpenBoxes: true);
    await SleepModule.init(preOpenBoxes: true);
    await FinanceModule.init(
      deferRecurringProcessing: true,
      preOpenBoxes: true,
      bootstrapDefaults: false,
    );
  }

  /// Task name for WorkManager registration.
  static String get taskName => _taskName;

  /// Lightweight health check (nek12 Layer 4): if we expect notifications but
  /// OS has none, resync. Call after normal sync on app open.
  static Future<void> runHealthCheckIfNeeded() async {
    try {
      final hub = NotificationHub();
      await hub.initialize();

      final pending = await NotificationService().getPendingNotifications();
      if (pending.isNotEmpty) return;

      // We have 0 pending. Check if we should have some.
      final hasUniversal = await _hasEnabledUniversalNotifications();
      final hasFinance = await _hasEnabledFinanceNotifications();
      final hasTasks = await _hasActiveTaskReminders();
      final hasHabits = await _hasActiveHabitReminders();
      if (!hasUniversal && !hasFinance && !hasTasks && !hasHabits) return;

      if (kDebugMode) {
        debugPrint(
          'NotificationRecoveryService: health check – 0 pending but '
          'expect notifications (universal=$hasUniversal, finance=$hasFinance, '
          'tasks=$hasTasks, habits=$hasHabits), resyncing',
        );
      }
      await runRecovery(bootstrapForBackground: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationRecoveryService: health check failed: $e');
      }
    }
  }

  static Future<bool> _hasEnabledUniversalNotifications() async {
    final repo = UniversalNotificationRepository();
    await repo.init();
    final all = await repo.getAll(enabledOnly: true);
    return all.isNotEmpty;
  }

  static Future<bool> _hasEnabledFinanceNotifications() async {
    final settings = await FinanceNotificationSettingsService().load();
    if (!settings.notificationsEnabled) return false;
    return settings.billsEnabled ||
        settings.debtsEnabled ||
        settings.budgetsEnabled ||
        settings.savingsGoalsEnabled ||
        settings.recurringIncomeEnabled;
  }

  /// Returns true if at least one pending task has configured reminders.
  static Future<bool> _hasActiveTaskReminders() async {
    try {
      final tasks = await TaskRepository().getAllTasks();
      return tasks.any(_taskNeedsReminders);
    } catch (_) {
      return false;
    }
  }

  /// Returns true if at least one active habit has reminders enabled.
  static Future<bool> _hasActiveHabitReminders() async {
    try {
      final habits = await HabitRepository().getAllHabits();
      return habits.any(
        (h) =>
            h.reminderEnabled && (h.reminderDuration ?? '').trim().isNotEmpty,
      );
    } catch (_) {
      return false;
    }
  }

  /// Whether a [Task] is in a state that should have active OS reminders.
  static bool _taskNeedsReminders(Task task) {
    if (task.status == 'completed' || task.status == 'not_done') return false;
    final raw = (task.remindersJson ?? '').trim();
    return raw.isNotEmpty;
  }

  /// Prune orphaned native alarms (for deleted entities). Call on app open.
  /// Requires app context (MethodChannel). Returns count of pruned alarms.
  static Future<int> pruneOrphanedAlarms() => _pruneOrphanedAlarms();

  /// Cancel native alarms for deleted entities. Call on app open (requires
  /// MethodChannel). Returns count of pruned alarms.
  static Future<int> _pruneOrphanedAlarms() async {
    if (!Platform.isAndroid) return 0;
    try {
      final alarms = await AlarmService().getScheduledAlarmsFromNative();
      if (alarms.isEmpty) return 0;

      final taskIds =
          (await TaskRepository().getAllTasks()).map((t) => t.id).toSet();
      final habitIds = (await HabitRepository().getAllHabits(
        includeArchived: true,
      ))
          .map((h) => h.id)
          .toSet();

      var pruned = 0;
      for (final alarm in alarms) {
        final payload = alarm['payload'] as String? ?? '';
        final parts = payload.split('|');
        if (parts.length < 2) continue;

        final type = parts[0];
        final entityId = parts[1];
        if (entityId.isEmpty) continue;

        final isOrphan = (type == 'task' && !taskIds.contains(entityId)) ||
            (type == 'habit' && !habitIds.contains(entityId));

        if (!isOrphan) continue;

        final id = (alarm['id'] as num?)?.toInt();
        if (id != null) {
          await AlarmService().cancelAlarm(id);
          pruned++;
        }
      }
      return pruned;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationRecoveryService: prune failed: $e');
      }
      return 0;
    }
  }
}

/// Result of a notification recovery run.
class NotificationRecoveryResult {
  final bool success;
  final int financeScheduled;
  final int financeCancelled;
  final int taskRescheduled;
  final int habitRescheduled;
  final String? error;

  const NotificationRecoveryResult({
    required this.success,
    this.financeScheduled = 0,
    this.financeCancelled = 0,
    this.taskRescheduled = 0,
    this.habitRescheduled = 0,
    this.error,
  });
}
