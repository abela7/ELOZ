import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/notifications/models/notification_hub_modules.dart';
import 'package:life_manager/core/notifications/services/notification_module_policy.dart';
import 'package:life_manager/core/notifications/services/notification_recovery_service.dart';
import 'package:life_manager/core/notifications/services/universal_notification_scheduler.dart';
import 'package:life_manager/data/models/task.dart';
import 'package:life_manager/features/habits/data/models/habit.dart';

Task _taskWithReminder(int index) {
  return Task(
    id: 'task-$index',
    title: 'Task $index',
    dueDate: DateTime(2026, 2, 16),
    remindersJson: '5 min before',
  );
}

Habit _habitWithReminder(int index) {
  return Habit(
    id: 'habit-$index',
    title: 'Habit $index',
    reminderEnabled: true,
    reminderDuration: '5 min before',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationRecoveryService.runRecovery', () {
    test('headless run skips legacy task/habit resync', () async {
      var bootstrapCalled = false;
      var initializeHubCalled = false;
      var syncUniversalCalled = false;
      var loadTasksCalled = false;
      var loadHabitsCalled = false;
      var pruneCalled = false;

      final result = await NotificationRecoveryService.runRecovery(
        bootstrapForBackground: true,
        sourceFlow: 'workmanager_test',
        overrides: NotificationRecoveryOverrides(
          bootstrapForBackground: () async => bootstrapCalled = true,
          initializeHub: () async => initializeHubCalled = true,
          loadFinanceEnabled: () async => false,
          syncUniversal: () async => syncUniversalCalled = true,
          loadTasks: () async {
            loadTasksCalled = true;
            return <Task>[];
          },
          loadHabits: () async {
            loadHabitsCalled = true;
            return <Habit>[];
          },
          pruneOrphanedAlarms: () async {
            pruneCalled = true;
            return 0;
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.legacyResyncSkippedHeadless, isTrue);
      expect(result.modulesProcessed, 1);
      expect(
        result.skippedReasons,
        containsAll(<String>[
          'finance_disabled',
          'legacy_resync_skipped_headless',
        ]),
      );
      expect(bootstrapCalled, isTrue);
      expect(initializeHubCalled, isTrue);
      expect(syncUniversalCalled, isTrue);
      expect(loadTasksCalled, isFalse);
      expect(loadHabitsCalled, isFalse);
      expect(pruneCalled, isFalse);
    });

    test('enforces per-run caps for task and habit legacy resync', () async {
      var taskRescheduleCalls = 0;
      var habitRescheduleCalls = 0;

      final result = await NotificationRecoveryService.runRecovery(
        bootstrapForBackground: false,
        sourceFlow: 'caps_test',
        overrides: NotificationRecoveryOverrides(
          initializeHub: () async {},
          readModulePolicy: (moduleId) async =>
              NotificationModulePolicyDecision(
                moduleId: moduleId,
                enabled: true,
                reason: NotificationModulePolicy.reasonEnabled,
              ),
          loadFinanceEnabled: () async => false,
          syncUniversal: () async {},
          pruneOrphanedAlarms: () async => 0,
          loadTasks: () async => List<Task>.generate(305, _taskWithReminder),
          rescheduleTask: (task) async => taskRescheduleCalls++,
          loadHabits: () async => List<Habit>.generate(405, _habitWithReminder),
          rescheduleHabit: (habit) async => habitRescheduleCalls++,
        ),
      );

      expect(result.success, isTrue);
      expect(result.taskRescheduled, 300);
      expect(result.habitRescheduled, 400);
      expect(result.taskSkippedByCap, 5);
      expect(result.habitSkippedByCap, 5);
      expect(result.modulesProcessed, 3);
      expect(result.skippedReasons, contains('finance_disabled'));
      expect(taskRescheduleCalls, 300);
      expect(habitRescheduleCalls, 400);
    });

    test('skips task/habit resync when module policy is disabled', () async {
      var loadTasksCalled = false;
      var loadHabitsCalled = false;
      var taskRescheduleCalls = 0;
      var habitRescheduleCalls = 0;

      final result = await NotificationRecoveryService.runRecovery(
        bootstrapForBackground: false,
        sourceFlow: 'policy_skip_test',
        overrides: NotificationRecoveryOverrides(
          initializeHub: () async {},
          readModulePolicy: (moduleId) async {
            if (moduleId == NotificationHubModuleIds.task ||
                moduleId == NotificationHubModuleIds.habit) {
              return NotificationModulePolicyDecision(
                moduleId: moduleId,
                enabled: false,
                reason:
                    NotificationModulePolicy.reasonModuleNotificationsDisabled,
              );
            }
            return NotificationModulePolicyDecision(
              moduleId: moduleId,
              enabled: true,
              reason: NotificationModulePolicy.reasonEnabled,
            );
          },
          loadFinanceEnabled: () async => false,
          syncUniversal: () async {},
          pruneOrphanedAlarms: () async => 0,
          loadTasks: () async {
            loadTasksCalled = true;
            return <Task>[_taskWithReminder(1)];
          },
          rescheduleTask: (task) async => taskRescheduleCalls++,
          loadHabits: () async {
            loadHabitsCalled = true;
            return <Habit>[_habitWithReminder(1)];
          },
          rescheduleHabit: (habit) async => habitRescheduleCalls++,
        ),
      );

      expect(result.success, isTrue);
      expect(result.modulesProcessed, 1);
      expect(result.taskRescheduled, 0);
      expect(result.habitRescheduled, 0);
      expect(taskRescheduleCalls, 0);
      expect(habitRescheduleCalls, 0);
      expect(loadTasksCalled, isFalse);
      expect(loadHabitsCalled, isFalse);
      expect(
        result.skippedReasons,
        containsAll(<String>[
          'finance_disabled',
          'task_${NotificationModulePolicy.reasonModuleNotificationsDisabled}',
          'habit_${NotificationModulePolicy.reasonModuleNotificationsDisabled}',
        ]),
      );
    });

    test(
      'does not resync deleted task/habit entities on later recovery runs',
      () async {
        var phase = 0;
        final firstRunRescheduledEntities = <String>[];
        final secondRunRescheduledEntities = <String>[];

        Future<NotificationRecoveryResult> run(String sourceFlow) {
          return NotificationRecoveryService.runRecovery(
            bootstrapForBackground: false,
            sourceFlow: sourceFlow,
            overrides: NotificationRecoveryOverrides(
              initializeHub: () async {},
              readModulePolicy: (moduleId) async =>
                  NotificationModulePolicyDecision(
                    moduleId: moduleId,
                    enabled: true,
                    reason: NotificationModulePolicy.reasonEnabled,
                  ),
              loadFinanceEnabled: () async => false,
              syncUniversal: () async {},
              pruneOrphanedAlarms: () async => 0,
              loadTasks: () async =>
                  phase == 0 ? <Task>[_taskWithReminder(1)] : <Task>[],
              rescheduleTask: (task) async {
                if (phase == 0) {
                  firstRunRescheduledEntities.add('task:${task.id}');
                } else {
                  secondRunRescheduledEntities.add('task:${task.id}');
                }
              },
              loadHabits: () async =>
                  phase == 0 ? <Habit>[_habitWithReminder(1)] : <Habit>[],
              rescheduleHabit: (habit) async {
                if (phase == 0) {
                  firstRunRescheduledEntities.add('habit:${habit.id}');
                } else {
                  secondRunRescheduledEntities.add('habit:${habit.id}');
                }
              },
            ),
          );
        }

        final first = await run('first_run_before_delete');
        phase = 1;
        final second = await run('second_run_after_delete');

        expect(first.success, isTrue);
        expect(first.taskRescheduled, 1);
        expect(first.habitRescheduled, 1);
        expect(
          firstRunRescheduledEntities,
          containsAll(<String>['task:task-1', 'habit:habit-1']),
        );

        expect(second.success, isTrue);
        expect(second.taskRescheduled, 0);
        expect(second.habitRescheduled, 0);
        expect(secondRunRescheduledEntities, isEmpty);
      },
    );

    test(
      'reports universal counters and elapsed duration in recovery summary',
      () async {
        final result = await NotificationRecoveryService.runRecovery(
          bootstrapForBackground: false,
          sourceFlow: 'metrics_test',
          overrides: NotificationRecoveryOverrides(
            initializeHub: () async {},
            loadFinanceEnabled: () async => true,
            syncFinance: () async =>
                const NotificationRecoveryFinanceSyncResult(
                  scheduled: 2,
                  cancelled: 1,
                ),
            syncUniversalWithMetrics: () async =>
                const UniversalNotificationSyncResult(
                  processed: 8,
                  scheduled: 4,
                  cancelled: 1,
                  skipped: 2,
                  failed: 1,
                  durationMs: 33,
                ),
            readModulePolicy: (moduleId) async =>
                NotificationModulePolicyDecision(
                  moduleId: moduleId,
                  enabled: false,
                  reason: NotificationModulePolicy.reasonModuleDisabled,
                ),
            pruneOrphanedAlarms: () async => 0,
          ),
        );

        expect(result.success, isTrue);
        expect(result.financeScheduled, 2);
        expect(result.financeCancelled, 1);
        expect(result.universalScheduled, 4);
        expect(result.universalCancelled, 1);
        expect(result.universalSkipped, 2);
        expect(result.universalFailed, 1);
        expect(result.durationMs, greaterThanOrEqualTo(0));
        expect(
          result.skippedReasons,
          containsAll(<String>[
            'task_${NotificationModulePolicy.reasonModuleDisabled}',
            'habit_${NotificationModulePolicy.reasonModuleDisabled}',
          ]),
        );
      },
    );
  });
}
