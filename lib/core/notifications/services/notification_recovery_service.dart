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
import '../../../features/habits/data/models/habit.dart';
import '../../../features/habits/habits_module.dart';
import '../../../features/habits/services/habit_reminder_service.dart';
import '../../../features/mbt/mbt_module.dart';
import '../../../features/behavior/behavior_module.dart';
import '../../../features/sleep/sleep_module.dart';
import '../../../features/tasks/tasks_module.dart';
import '../models/notification_hub_modules.dart';
import '../notification_hub.dart';
import 'notification_flow_trace.dart';
import 'notification_module_policy.dart';
import 'universal_notification_repository.dart';
import 'universal_notification_scheduler.dart';

class NotificationRecoveryFinanceSyncResult {
  final int scheduled;
  final int cancelled;

  const NotificationRecoveryFinanceSyncResult({
    required this.scheduled,
    required this.cancelled,
  });
}

@immutable
class NotificationRecoveryOverrides {
  final Future<void> Function()? bootstrapForBackground;
  final Future<void> Function()? initializeHub;
  final Future<NotificationModulePolicyDecision> Function(String moduleId)?
  readModulePolicy;
  final Future<bool> Function()? loadFinanceEnabled;
  final Future<NotificationRecoveryFinanceSyncResult> Function()? syncFinance;
  final Future<UniversalNotificationSyncResult> Function()?
  syncUniversalWithMetrics;
  final Future<void> Function()? syncUniversal;
  final Future<List<Task>> Function()? loadTasks;
  final Future<void> Function(Task task)? rescheduleTask;
  final Future<List<Habit>> Function()? loadHabits;
  final Future<void> Function(Habit habit)? rescheduleHabit;
  final Future<int> Function()? pruneOrphanedAlarms;

  const NotificationRecoveryOverrides({
    this.bootstrapForBackground,
    this.initializeHub,
    this.readModulePolicy,
    this.loadFinanceEnabled,
    this.syncFinance,
    this.syncUniversalWithMetrics,
    this.syncUniversal,
    this.loadTasks,
    this.rescheduleTask,
    this.loadHabits,
    this.rescheduleHabit,
    this.pruneOrphanedAlarms,
  });
}

/// Recovery service for notification schedules (nek12.dev "100% reliable" Layer 3).
///
/// Runs a full resync of Finance + Universal + legacy Task/Habit notifications.
/// Used by:
/// - WorkManager periodic task (safety net when app is killed)
/// - App-open health check (Layer 4)
/// - NotificationSystemRefresher (resume-after-15min)
///
/// When invoked from WorkManager, the app may be killed - this service performs
/// a minimal bootstrap (Hive + modules) before syncing.
class NotificationRecoveryService {
  NotificationRecoveryService._();

  static const String _taskName = 'notificationRecovery';
  static const int _maxTaskResyncPerRun = 300;
  static const int _maxHabitResyncPerRun = 400;

  /// Performs full notification schedule sync.
  ///
  /// Call from WorkManager callback or app context. If [bootstrapForBackground]
  /// is true, initializes Hive and modules first (required when app was killed).
  static Future<NotificationRecoveryResult> runRecovery({
    bool bootstrapForBackground = false,
    String sourceFlow = 'app_runtime',
    NotificationRecoveryOverrides overrides =
        const NotificationRecoveryOverrides(),
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (bootstrapForBackground) {
        if (overrides.bootstrapForBackground != null) {
          await overrides.bootstrapForBackground!.call();
        } else {
          await _bootstrapForBackground();
        }
      }

      if (overrides.initializeHub != null) {
        await overrides.initializeHub!.call();
      } else {
        final hub = NotificationHub();
        await hub.initialize();
      }

      var financeScheduled = 0;
      var financeCancelled = 0;
      var universalScheduled = 0;
      var universalCancelled = 0;
      var universalSkipped = 0;
      var universalFailed = 0;
      var outOfRangeCancelled = 0;
      var modulesProcessed = 0;
      final skippedReasons = <String>[];

      final canPruneOutOfRange =
          !bootstrapForBackground && (Platform.isAndroid || Platform.isIOS);
      if (canPruneOutOfRange) {
        try {
          outOfRangeCancelled = await NotificationService()
              .cancelOutOfRangePendingNotifications(
                sourceFlow: '${sourceFlow}_recovery_pre_cleanup',
              );
          if (outOfRangeCancelled > 0) {
            skippedReasons.add('out_of_range_pruned_$outOfRangeCancelled');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'NotificationRecoveryService: out-of-range cleanup failed: $e',
            );
          }
        }
      } else if (bootstrapForBackground) {
        skippedReasons.add('out_of_range_skip_headless');
      } else {
        skippedReasons.add('out_of_range_skip_platform');
      }

      final financeEnabled = overrides.loadFinanceEnabled != null
          ? await overrides.loadFinanceEnabled!.call()
          : await _loadFinanceNotificationsEnabled();

      if (financeEnabled) {
        if (overrides.syncFinance != null) {
          final financeResult = await overrides.syncFinance!.call();
          financeScheduled = financeResult.scheduled;
          financeCancelled = financeResult.cancelled;
        } else {
          final financeResult = await FinanceNotificationScheduler()
              .syncSchedules();
          financeScheduled = financeResult.scheduled;
          financeCancelled = financeResult.cancelled;
        }
        modulesProcessed++;
      } else {
        skippedReasons.add('finance_disabled');
      }

      if (overrides.syncUniversalWithMetrics != null) {
        final universalResult = await overrides.syncUniversalWithMetrics!
            .call();
        universalScheduled = universalResult.scheduled;
        universalCancelled = universalResult.cancelled;
        universalSkipped = universalResult.skipped;
        universalFailed = universalResult.failed;
      } else if (overrides.syncUniversal != null) {
        await overrides.syncUniversal!.call();
      } else {
        final universalResult = await UniversalNotificationScheduler()
            .syncAllWithMetrics();
        universalScheduled = universalResult.scheduled;
        universalCancelled = universalResult.cancelled;
        universalSkipped = universalResult.skipped;
        universalFailed = universalResult.failed;
      }
      if (universalFailed > 0) {
        skippedReasons.add('universal_failed_$universalFailed');
      }
      modulesProcessed++;

      var taskRescheduled = 0;
      var habitRescheduled = 0;
      var taskSkippedByCap = 0;
      var habitSkippedByCap = 0;
      var legacyResyncSkippedHeadless = false;

      if (!bootstrapForBackground) {
        final pruned = overrides.pruneOrphanedAlarms != null
            ? await overrides.pruneOrphanedAlarms!.call()
            : await _pruneOrphanedAlarms();
        if (pruned > 0 && kDebugMode) {
          debugPrint(
            'NotificationRecoveryService: pruned $pruned orphaned native alarm(s)',
          );
        }

        final taskPolicy = overrides.readModulePolicy != null
            ? await overrides.readModulePolicy!(NotificationHubModuleIds.task)
            : await NotificationModulePolicy.read(
                NotificationHubModuleIds.task,
              );
        if (!taskPolicy.enabled) {
          skippedReasons.add('task_${taskPolicy.reason}');
        } else {
          try {
            final tasks = overrides.loadTasks != null
                ? await overrides.loadTasks!.call()
                : await TaskRepository().getAllTasks();
            final candidates = tasks.where(_taskNeedsReminders).toList();
            final toResync = candidates.take(_maxTaskResyncPerRun).toList();
            taskSkippedByCap = candidates.length - toResync.length;
            for (final task in toResync) {
              if (overrides.rescheduleTask != null) {
                await overrides.rescheduleTask!.call(task);
              } else {
                await ReminderManager().rescheduleRemindersForTask(
                  task,
                  sourceFlow: sourceFlow,
                );
              }
              taskRescheduled++;
            }
            modulesProcessed++;
            if (taskSkippedByCap > 0 && kDebugMode) {
              debugPrint(
                'NotificationRecoveryService: task resync capped '
                '($_maxTaskResyncPerRun), skipped $taskSkippedByCap task(s)',
              );
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('NotificationRecoveryService: task resync failed: $e');
            }
          }
        }

        final habitPolicy = overrides.readModulePolicy != null
            ? await overrides.readModulePolicy!(NotificationHubModuleIds.habit)
            : await NotificationModulePolicy.read(
                NotificationHubModuleIds.habit,
              );
        if (!habitPolicy.enabled) {
          skippedReasons.add('habit_${habitPolicy.reason}');
        } else {
          try {
            final habits = overrides.loadHabits != null
                ? await overrides.loadHabits!.call()
                : await HabitRepository().getAllHabits();
            final candidates = habits
                .where(
                  (h) =>
                      h.reminderEnabled &&
                      (h.reminderDuration ?? '').trim().isNotEmpty,
                )
                .toList();
            final toResync = candidates.take(_maxHabitResyncPerRun).toList();
            habitSkippedByCap = candidates.length - toResync.length;
            for (final habit in toResync) {
              if (overrides.rescheduleHabit != null) {
                await overrides.rescheduleHabit!.call(habit);
              } else {
                await HabitReminderService().rescheduleHabitReminders(
                  habit,
                  sourceFlow: sourceFlow,
                );
              }
              habitRescheduled++;
            }
            modulesProcessed++;
            if (habitSkippedByCap > 0 && kDebugMode) {
              debugPrint(
                'NotificationRecoveryService: habit resync capped '
                '($_maxHabitResyncPerRun), skipped $habitSkippedByCap habit(s)',
              );
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                'NotificationRecoveryService: habit resync failed: $e',
              );
            }
          }
        }
      } else {
        legacyResyncSkippedHeadless = true;
        skippedReasons.add('legacy_resync_skipped_headless');
        if (kDebugMode) {
          debugPrint(
            'NotificationRecoveryService: background isolate run - '
            'skipping legacy task/habit resync (headless safety)',
          );
        }
      }

      stopwatch.stop();
      final result = NotificationRecoveryResult(
        success: true,
        sourceFlow: sourceFlow,
        modulesProcessed: modulesProcessed,
        skippedReasons: skippedReasons,
        durationMs: stopwatch.elapsedMilliseconds,
        financeScheduled: financeScheduled,
        financeCancelled: financeCancelled,
        universalScheduled: universalScheduled,
        universalCancelled: universalCancelled,
        universalSkipped: universalSkipped,
        universalFailed: universalFailed,
        taskRescheduled: taskRescheduled,
        habitRescheduled: habitRescheduled,
        taskSkippedByCap: taskSkippedByCap,
        habitSkippedByCap: habitSkippedByCap,
        legacyResyncSkippedHeadless: legacyResyncSkippedHeadless,
      );

      NotificationFlowTrace.log(
        event: 'recovery_summary',
        sourceFlow: sourceFlow,
        details: result.toMap(),
      );

      if (kDebugMode) {
        debugPrint('NotificationRecoveryService: ${result.summaryLine()}');
      }

      return result;
    } catch (e, st) {
      if (stopwatch.isRunning) {
        stopwatch.stop();
      }
      if (kDebugMode) {
        debugPrint('NotificationRecoveryService: recovery failed: $e');
        debugPrintStack(stackTrace: st);
      }
      final failed = NotificationRecoveryResult(
        success: false,
        sourceFlow: sourceFlow,
        durationMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
        skippedReasons: const <String>['recovery_exception'],
      );
      NotificationFlowTrace.log(
        event: 'recovery_summary',
        sourceFlow: sourceFlow,
        reason: 'recovery_failed',
        details: failed.toMap(),
      );
      return failed;
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
    await MbtModule.init(preOpenBoxes: true);
    await BehaviorModule.init(preOpenBoxes: true);
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
          'NotificationRecoveryService: health check - 0 pending but '
          'expect notifications (universal=$hasUniversal, finance=$hasFinance, '
          'tasks=$hasTasks, habits=$hasHabits), resyncing',
        );
      }
      await runRecovery(
        bootstrapForBackground: false,
        sourceFlow: 'health_check',
      );
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

  static Future<bool> _loadFinanceNotificationsEnabled() async {
    final settings = await FinanceNotificationSettingsService().load();
    return settings.notificationsEnabled;
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
      if (!await _isModuleSchedulingEnabled(NotificationHubModuleIds.task)) {
        return false;
      }
      final tasks = await TaskRepository().getAllTasks();
      return tasks.any(_taskNeedsReminders);
    } catch (_) {
      return false;
    }
  }

  /// Returns true if at least one active habit has reminders enabled.
  static Future<bool> _hasActiveHabitReminders() async {
    try {
      if (!await _isModuleSchedulingEnabled(NotificationHubModuleIds.habit)) {
        return false;
      }
      final habits = await HabitRepository().getAllHabits();
      return habits.any(
        (h) =>
            h.reminderEnabled && (h.reminderDuration ?? '').trim().isNotEmpty,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isModuleSchedulingEnabled(String moduleId) async {
    return NotificationModulePolicy.isSchedulingEnabled(moduleId);
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

      final taskIds = (await TaskRepository().getAllTasks())
          .map((t) => t.id)
          .toSet();
      final habitIds = (await HabitRepository().getAllHabits(
        includeArchived: true,
      )).map((h) => h.id).toSet();

      var pruned = 0;
      for (final alarm in alarms) {
        final payload = alarm['payload'] as String? ?? '';
        final parts = payload.split('|');
        if (parts.length < 2) continue;

        final type = parts[0];
        final entityId = parts[1];
        if (entityId.isEmpty) continue;

        final isOrphan =
            (type == 'task' && !taskIds.contains(entityId)) ||
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
  final String sourceFlow;
  final int durationMs;
  final int modulesProcessed;
  final List<String> skippedReasons;
  final int financeScheduled;
  final int financeCancelled;
  final int universalScheduled;
  final int universalCancelled;
  final int universalSkipped;
  final int universalFailed;
  final int taskRescheduled;
  final int habitRescheduled;
  final int taskSkippedByCap;
  final int habitSkippedByCap;
  final bool legacyResyncSkippedHeadless;
  final String? error;

  const NotificationRecoveryResult({
    required this.success,
    this.sourceFlow = 'app_runtime',
    this.durationMs = 0,
    this.modulesProcessed = 0,
    this.skippedReasons = const <String>[],
    this.financeScheduled = 0,
    this.financeCancelled = 0,
    this.universalScheduled = 0,
    this.universalCancelled = 0,
    this.universalSkipped = 0,
    this.universalFailed = 0,
    this.taskRescheduled = 0,
    this.habitRescheduled = 0,
    this.taskSkippedByCap = 0,
    this.habitSkippedByCap = 0,
    this.legacyResyncSkippedHeadless = false,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'success': success,
      'sourceFlow': sourceFlow,
      'durationMs': durationMs,
      'modulesProcessed': modulesProcessed,
      'financeScheduled': financeScheduled,
      'financeCancelled': financeCancelled,
      'universalScheduled': universalScheduled,
      'universalCancelled': universalCancelled,
      'universalSkipped': universalSkipped,
      'universalFailed': universalFailed,
      'taskRescheduled': taskRescheduled,
      'habitRescheduled': habitRescheduled,
      'taskSkippedByCap': taskSkippedByCap,
      'habitSkippedByCap': habitSkippedByCap,
      'legacyResyncSkippedHeadless': legacyResyncSkippedHeadless,
      'skippedReasons': skippedReasons,
      if (error != null) 'error': error,
    };
  }

  String summaryLine() {
    return 'source=$sourceFlow success=$success durationMs=$durationMs '
        'modulesProcessed=$modulesProcessed '
        'financeScheduled=$financeScheduled financeCancelled=$financeCancelled '
        'universalScheduled=$universalScheduled universalCancelled=$universalCancelled '
        'universalSkipped=$universalSkipped universalFailed=$universalFailed '
        'taskRescheduled=$taskRescheduled habitRescheduled=$habitRescheduled '
        'taskSkippedByCap=$taskSkippedByCap habitSkippedByCap=$habitSkippedByCap '
        'legacyResyncSkippedHeadless=$legacyResyncSkippedHeadless '
        'skippedReasons=${skippedReasons.join(',')}'
        '${error != null ? ' error=$error' : ''}';
  }
}
