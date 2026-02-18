import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/reminder.dart';
import '../models/pending_notification_info.dart';
import '../notifications/models/notification_hub_modules.dart';
import '../notifications/models/notification_hub_payload.dart';
import '../notifications/notification_hub.dart';
import '../notifications/services/notification_flow_trace.dart';
import '../notifications/services/notification_module_policy.dart';
import '../notifications/services/universal_notification_repository.dart';
import '../../data/models/task.dart';
import '../../features/habits/data/models/habit.dart';
import '../../features/habits/services/habit_reminder_service.dart';
import 'alarm_service.dart';
import 'notification_service.dart';

/// Reminder Manager - Central coordinator for task reminders
///
/// Responsibilities:
/// - Parse reminder strings from tasks
/// - Convert to Reminder objects
/// - Coordinate with NotificationService
/// - Handle task lifecycle events (create, update, complete, delete)
class ReminderManager {
  static final ReminderManager _instance = ReminderManager._internal();
  factory ReminderManager() => _instance;
  ReminderManager._internal();

  final NotificationService _notificationService = NotificationService();
  final HabitReminderService _habitReminderService = HabitReminderService();
  final NotificationHub _hub = NotificationHub();
  final Map<String, Future<void>> _entityLocks = <String, Future<void>>{};

  /// Initialize the reminder manager
  Future<void> initialize({bool startupOptimized = false}) async {
    await _notificationService.initialize(startupOptimized: startupOptimized);
  }

  /// Parse reminder string from task to Reminder objects
  ///
  /// Examples of reminder strings:
  /// - "5 min before"
  /// - "15 min before"
  /// - "1 hour before"
  /// - "1 day before"
  /// - "At task time"
  /// - "Custom: 1h 30m"
  List<Reminder> parseReminderString(String? reminderString) {
    if (reminderString == null || reminderString.isEmpty) {
      return [];
    }

    // Handle "No reminder" case
    if (reminderString.toLowerCase() == 'no reminder') {
      return [];
    }

    // Handle common patterns
    if (reminderString.contains('5 min before') ||
        reminderString.contains('5 minutes before')) {
      return [Reminder.fiveMinutesBefore()];
    }

    if (reminderString.contains('15 min before') ||
        reminderString.contains('15 minutes before')) {
      return [Reminder.fifteenMinutesBefore()];
    }

    if (reminderString.contains('30 min before') ||
        reminderString.contains('30 minutes before')) {
      return [Reminder.thirtyMinutesBefore()];
    }

    if (reminderString.contains('1 hour before') ||
        reminderString.contains('1 hr before')) {
      return [Reminder.oneHourBefore()];
    }

    if (reminderString.contains('1 day before')) {
      return [Reminder.oneDayBefore()];
    }

    if (reminderString.toLowerCase() == 'at task time' ||
        reminderString.toLowerCase() == 'on time') {
      return [Reminder.atTaskTime()];
    }

    // Handle custom format: "Custom: 1h 30m"
    if (reminderString.startsWith('Custom:')) {
      return _parseCustomReminder(reminderString);
    }

    // Default fallback: 5 minutes before
    return [Reminder.fiveMinutesBefore()];
  }

  /// Parse custom reminder format
  List<Reminder> _parseCustomReminder(String reminderString) {
    final reminders = <Reminder>[];

    // Remove "Custom: " prefix
    final customPart = reminderString.substring(8).trim();

    // Try to parse time components
    final hourMatch = RegExp(r'(\d+)\s*h').firstMatch(customPart);
    final minuteMatch = RegExp(r'(\d+)\s*m').firstMatch(customPart);

    if (hourMatch != null || minuteMatch != null) {
      int totalMinutes = 0;

      if (hourMatch != null) {
        totalMinutes += int.parse(hourMatch.group(1)!) * 60;
      }

      if (minuteMatch != null) {
        totalMinutes += int.parse(minuteMatch.group(1)!);
      }

      if (totalMinutes > 0) {
        reminders.add(
          Reminder(type: 'before', value: totalMinutes, unit: 'minutes'),
        );
      }
    }

    return reminders.isNotEmpty ? reminders : [Reminder.fiveMinutesBefore()];
  }

  /// Schedule reminders for a task.
  ///
  /// [sourceFlow] should describe who triggered scheduling
  /// (e.g. `task_update`, `recovery_resync`, `manual_sync`).
  Future<void> scheduleRemindersForTask(
    Task task, {
    String sourceFlow = 'task_runtime',
  }) async {
    await _runEntityLocked(
      scope: NotificationHubModuleIds.task,
      entityId: task.id,
      action: () => _scheduleRemindersForTaskUnlocked(
        task,
        sourceFlow: sourceFlow,
      ),
    );
  }

  Future<void> _scheduleRemindersForTaskUnlocked(
    Task task, {
    required String sourceFlow,
  }) async {
    final beforeIds = await _pendingIdsForEntity(
      moduleId: NotificationHubModuleIds.task,
      entityId: task.id,
    );

    NotificationFlowTrace.log(
      event: 'legacy_schedule_request',
      sourceFlow: sourceFlow,
      moduleId: NotificationHubModuleIds.task,
      entityId: task.id,
      details: <String, dynamic>{
        'title': task.title,
        'status': task.status,
        'pendingBefore': beforeIds,
        'remindersRaw': task.remindersJson ?? '',
      },
    );

    final policy = await NotificationModulePolicy.read(
      NotificationHubModuleIds.task,
    );
    if (!policy.enabled) {
      await _cancelRemindersForTaskUnlocked(
        task.id,
        sourceFlow: sourceFlow,
        reason: policy.reason,
      );
      return;
    }

    if (await _hasEnabledUniversalDefinitions(
      moduleId: NotificationHubModuleIds.task,
      entityId: task.id,
    )) {
      await _cancelRemindersForTaskUnlocked(
        task.id,
        sourceFlow: sourceFlow,
        reason: 'universal_definition_enabled',
      );
      return;
    }

    final reminders = _parseTaskReminders(task);
    if (reminders.isEmpty) {
      NotificationFlowTrace.log(
        event: 'legacy_schedule_skipped',
        sourceFlow: sourceFlow,
        moduleId: NotificationHubModuleIds.task,
        entityId: task.id,
        reason: 'no_enabled_reminders',
      );
      return;
    }

    // Don't schedule reminders for completed or not_done tasks.
    if (task.status == 'completed' || task.status == 'not_done') {
      NotificationFlowTrace.log(
        event: 'legacy_schedule_skipped',
        sourceFlow: sourceFlow,
        moduleId: NotificationHubModuleIds.task,
        entityId: task.id,
        reason: 'task_status_${task.status}',
      );
      return;
    }

    await _notificationService.scheduleMultipleReminders(
      task: task,
      reminders: reminders,
      sourceFlow: sourceFlow,
    );

    final afterIds = await _pendingIdsForEntity(
      moduleId: NotificationHubModuleIds.task,
      entityId: task.id,
    );
    final scheduledIds = afterIds.where((id) => !beforeIds.contains(id)).toList()
      ..sort();
    NotificationFlowTrace.log(
      event: 'legacy_schedule_result',
      sourceFlow: sourceFlow,
      moduleId: NotificationHubModuleIds.task,
      entityId: task.id,
      notificationIds: scheduledIds,
      details: <String, dynamic>{
        'pendingBefore': beforeIds,
        'pendingAfter': afterIds,
        'reminderCount': reminders.length,
      },
    );
  }

  List<Reminder> _parseTaskReminders(Task task) {
    final raw = (task.remindersJson ?? '').trim();
    if (raw.isEmpty) return [];

    // New format: JSON list
    if (raw.startsWith('[')) {
      try {
        return Reminder.decodeList(raw).where((r) => r.enabled).toList();
      } catch (_) {
        return [];
      }
    }

    // Legacy format: single string like "5 min before"
    return parseReminderString(raw).where((r) => r.enabled).toList();
  }

  /// Schedule reminders for a habit.
  Future<void> scheduleRemindersForHabit(
    Habit habit, {
    String sourceFlow = 'habit_runtime',
  }) async {
    await _runEntityLocked(
      scope: NotificationHubModuleIds.habit,
      entityId: habit.id,
      action: () => _habitReminderService.scheduleHabitReminders(
        habit,
        sourceFlow: sourceFlow,
      ),
    );
  }

  /// Cancel reminders for a task.
  Future<void> cancelRemindersForTask(
    String taskId, {
    String sourceFlow = 'task_runtime',
    String reason = 'cancel',
  }) async {
    await _runEntityLocked(
      scope: NotificationHubModuleIds.task,
      entityId: taskId,
      action: () => _cancelRemindersForTaskUnlocked(
        taskId,
        sourceFlow: sourceFlow,
        reason: reason,
      ),
    );
  }

  Future<void> _cancelRemindersForTaskUnlocked(
    String taskId, {
    required String sourceFlow,
    required String reason,
  }) async {
    final beforeIds = await _pendingIdsForEntity(
      moduleId: NotificationHubModuleIds.task,
      entityId: taskId,
    );
    await _notificationService.cancelAllTaskReminders(
      taskId,
      sourceFlow: sourceFlow,
      reason: reason,
    );
    await _cancelHubRemindersForTask(taskId);
    await _cancelNativeAlarmsForEntity('task', taskId);
    final afterIds = await _pendingIdsForEntity(
      moduleId: NotificationHubModuleIds.task,
      entityId: taskId,
    );
    final cancelledIds = beforeIds.where((id) => !afterIds.contains(id)).toList()
      ..sort();
    NotificationFlowTrace.log(
      event: 'legacy_cancel_result',
      sourceFlow: sourceFlow,
      moduleId: NotificationHubModuleIds.task,
      entityId: taskId,
      reason: reason,
      notificationIds: cancelledIds,
      details: <String, dynamic>{
        'pendingBefore': beforeIds,
        'pendingAfter': afterIds,
      },
    );
  }

  Future<void> _cancelHubRemindersForTask(String taskId) async {
    await _hub.cancelForEntity(
      moduleId: NotificationHubModuleIds.task,
      entityId: taskId,
    );
  }

  Future<void> _cancelHubRemindersForHabit(String habitId) async {
    await _hub.cancelForEntity(
      moduleId: NotificationHubModuleIds.habit,
      entityId: habitId,
    );
  }

  Future<void> _deleteUniversalTaskDefinitions(String taskId) async {
    await UniversalNotificationRepository().deleteByEntity(taskId);
  }

  Future<void> _deleteUniversalHabitDefinitions(String habitId) async {
    await UniversalNotificationRepository().deleteByEntity(habitId);
  }

  /// Cancel reminders for a habit.
  Future<void> cancelRemindersForHabit(
    String habitId, {
    String sourceFlow = 'habit_runtime',
    String reason = 'cancel',
  }) async {
    await _runEntityLocked(
      scope: NotificationHubModuleIds.habit,
      entityId: habitId,
      action: () => _cancelRemindersForHabitUnlocked(
        habitId,
        sourceFlow: sourceFlow,
        reason: reason,
      ),
    );
  }

  Future<void> _cancelRemindersForHabitUnlocked(
    String habitId, {
    required String sourceFlow,
    required String reason,
  }) async {
    final beforeIds = await _pendingIdsForEntity(
      moduleId: NotificationHubModuleIds.habit,
      entityId: habitId,
    );
    await _habitReminderService.cancelHabitReminders(
      habitId,
      sourceFlow: sourceFlow,
      reason: reason,
    );
    await _cancelHubRemindersForHabit(habitId);
    await _cancelNativeAlarmsForEntity('habit', habitId);
    final afterIds = await _pendingIdsForEntity(
      moduleId: NotificationHubModuleIds.habit,
      entityId: habitId,
    );
    final cancelledIds = beforeIds.where((id) => !afterIds.contains(id)).toList()
      ..sort();
    NotificationFlowTrace.log(
      event: 'legacy_cancel_result',
      sourceFlow: sourceFlow,
      moduleId: NotificationHubModuleIds.habit,
      entityId: habitId,
      reason: reason,
      notificationIds: cancelledIds,
      details: <String, dynamic>{
        'pendingBefore': beforeIds,
        'pendingAfter': afterIds,
      },
    );
  }

  /// Cancel reminders for all habits
  Future<void> cancelAllHabitReminders() async {
    await _habitReminderService.cancelAllHabitReminders();
  }

  /// Cancel a specific pending notification by its notification ID.
  Future<void> cancelPendingNotificationById({
    required int notificationId,
    String? entityId,
  }) async {
    await _notificationService.cancelPendingNotificationById(
      notificationId: notificationId,
      entityId: entityId,
    );
  }

  /// Reschedule reminders when task is updated.
  Future<void> rescheduleRemindersForTask(
    Task task, {
    String sourceFlow = 'task_reschedule',
  }) async {
    await _runEntityLocked(
      scope: NotificationHubModuleIds.task,
      entityId: task.id,
      action: () async {
        await _cancelRemindersForTaskUnlocked(
          task.id,
          sourceFlow: sourceFlow,
          reason: 'reschedule',
        );
        await _scheduleRemindersForTaskUnlocked(
          task,
          sourceFlow: sourceFlow,
        );
      },
    );
  }

  /// Reschedule reminders when habit is updated.
  Future<void> rescheduleRemindersForHabit(
    Habit habit, {
    String sourceFlow = 'habit_reschedule',
  }) async {
    await _runEntityLocked(
      scope: NotificationHubModuleIds.habit,
      entityId: habit.id,
      action: () => _habitReminderService.rescheduleHabitReminders(
        habit,
        sourceFlow: sourceFlow,
      ),
    );
  }

  /// Reschedule a single pending notification to a new absolute time.
  ///
  /// Uses the same scheduling path as user snooze to preserve behavior.
  Future<void> reschedulePendingNotification({
    required PendingNotificationInfo info,
    required DateTime scheduledAt,
    String? channelKeyOverride,
  }) async {
    final now = DateTime.now();
    final safeTarget = scheduledAt.isAfter(now.add(const Duration(minutes: 1)))
        ? scheduledAt
        : now.add(const Duration(minutes: 1));
    final minutesFromNow = safeTarget.difference(now).inMinutes;
    final durationMinutes = minutesFromNow <= 0 ? 1 : minutesFromNow;

    await _notificationService.cancelPendingNotificationById(
      notificationId: info.id,
      entityId: info.entityId,
    );

    await _notificationService.snoozeNotification(
      taskId: info.entityId,
      title: info.title,
      body: info.body,
      payload: info.payload,
      customDurationMinutes: durationMinutes,
      priority: info.priority,
      originalNotificationId: info.id,
      notificationKindLabel: info.type == 'habit' ? 'Habit' : 'Task',
      channelKeyOverride: channelKeyOverride ?? info.channelKey,
    );
  }

  /// Handle task completion - cancel reminders.
  Future<void> handleTaskCompleted(
    Task task, {
    String sourceFlow = 'task_completed',
  }) async {
    await cancelRemindersForTask(
      task.id,
      sourceFlow: sourceFlow,
      reason: 'task_completed',
    );
  }

  /// Handle task postpone - reschedule with new date.
  Future<void> handleTaskPostponed(
    Task task, {
    String sourceFlow = 'task_postponed',
  }) async {
    await rescheduleRemindersForTask(task, sourceFlow: sourceFlow);
  }

  /// Handle task deletion with canonical cleanup.
  Future<void> handleTaskDeleted(
    String taskId, {
    String sourceFlow = 'task_deleted',
  }) async {
    await _deleteUniversalTaskDefinitions(taskId);
    await cancelRemindersForTask(
      taskId,
      sourceFlow: sourceFlow,
      reason: 'entity_deleted',
    );
  }

  /// Handle habit deletion/archive with canonical cleanup.
  Future<void> handleHabitDeleted(
    String habitId, {
    String sourceFlow = 'habit_deleted',
  }) async {
    await _deleteUniversalHabitDefinitions(habitId);
    await cancelRemindersForHabit(
      habitId,
      sourceFlow: sourceFlow,
      reason: 'entity_deleted',
    );
  }

  /// Cancel native alarms for an entity (habit/task).
  /// Android AlarmManager has no API to list alarms; we scan our own
  /// AlarmBootReceiver persistence and cancel by payload match.
  Future<void> _cancelNativeAlarmsForEntity(String type, String entityId) async {
    await AlarmService().cancelAlarmsForEntity(type, entityId);
  }

  Future<bool> _hasEnabledUniversalDefinitions({
    required String moduleId,
    required String entityId,
  }) async {
    final repo = UniversalNotificationRepository();
    final definitions = await repo.getAll(
      moduleId: moduleId,
      entityId: entityId,
      enabledOnly: true,
    );
    return definitions.isNotEmpty;
  }

  Future<T> _runEntityLocked<T>({
    required String scope,
    required String entityId,
    required Future<T> Function() action,
  }) async {
    final key = '$scope|$entityId';
    final previous = _entityLocks[key] ?? Future<void>.value();
    final completer = Completer<void>();
    final queued = previous.then((_) => completer.future);
    _entityLocks[key] = queued;

    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
      if (identical(_entityLocks[key], queued)) {
        _entityLocks.remove(key);
      }
    }
  }

  @visibleForTesting
  Future<T> runEntityLockedForTest<T>({
    required String scope,
    required String entityId,
    required Future<T> Function() action,
  }) {
    return _runEntityLocked(
      scope: scope,
      entityId: entityId,
      action: action,
    );
  }

  Future<List<int>> _pendingIdsForEntity({
    required String moduleId,
    required String entityId,
  }) async {
    try {
      final pending = await _notificationService.getDetailedPendingNotifications();
      final ids = <int>{};
      for (final info in pending) {
        final parsed = NotificationHubPayload.tryParse(info.payload);
        final pendingModuleId = parsed?.moduleId ?? info.type;
        final pendingEntityId = parsed?.entityId ?? info.entityId;
        if (pendingModuleId == moduleId && pendingEntityId == entityId) {
          ids.add(info.id);
        }
      }
      final list = ids.toList()..sort();
      return list;
    } catch (_) {
      return const <int>[];
    }
  }

  /// Get reminder descriptions for UI display
  String getReminderDescription(String? reminderString) {
    if (reminderString == null ||
        reminderString.isEmpty ||
        reminderString.toLowerCase() == 'no reminder') {
      return 'No reminder';
    }
    return reminderString;
  }

  /// Test notification - for debugging
  Future<void> testNotification(Task task) async {
    await _notificationService.showImmediateNotification(
      title: '⏰ Test: ${task.title}',
      body: 'This is a test notification for your task',
      payload: task.id,
    );
  }

  /// Get pending notifications count
  Future<int> getPendingNotificationsCount() async {
    final pending = await _notificationService
        .getDetailedPendingNotifications();
    return pending.length;
  }

  /// Get all pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationService.getPendingNotifications();
  }

  /// Get detailed information about all pending notifications
  ///
  /// Returns full diagnostic info including schedule, quiet hours, channel, and build details.
  Future<List<PendingNotificationInfo>>
  getDetailedPendingNotifications() async {
    return await _notificationService.getDetailedPendingNotifications();
  }

  /// Fire a notification EXACTLY as it would fire when scheduled
  ///
  /// This fires the real notification using the same code path as scheduled
  /// notifications. No "test" markers - this IS the real notification.
  ///
  /// [channelOverride] - Optional: Test with a different channel
  /// [soundOverride] - Optional: Test with a different sound
  /// [delaySeconds] - Optional: Delay before firing (for testing app killed/locked)
  Future<void> fireNotificationNow({
    required PendingNotificationInfo info,
    String? channelOverride,
    String? soundOverride,
    int delaySeconds = 2,
  }) async {
    return await _notificationService.fireNotificationNow(
      info: info,
      channelOverride: channelOverride,
      soundOverride: soundOverride,
      delaySeconds: delaySeconds,
    );
  }

  /// Get available delay options for testing
  List<Map<String, dynamic>> getDelayOptions() {
    return [
      {'seconds': 2, 'label': 'Now (2s)', 'description': 'Immediate test'},
      {
        'seconds': 10,
        'label': '10 seconds',
        'description': 'Quick lock screen test',
      },
      {
        'seconds': 30,
        'label': '30 seconds',
        'description': 'Time to lock phone',
      },
      {'seconds': 60, 'label': '1 minute', 'description': 'Time to kill app'},
      {'seconds': 120, 'label': '2 minutes', 'description': 'Extended test'},
      {'seconds': 300, 'label': '5 minutes', 'description': 'Deep sleep test'},
    ];
  }

  /// Get list of available channels for testing
  List<Map<String, String>> getAvailableChannels() {
    return _notificationService.getAvailableChannels();
  }

  /// Get list of available sounds for testing (async - includes user's custom sounds)
  Future<List<Map<String, String>>> getAvailableSoundsAsync() {
    return _notificationService.getAvailableSoundsAsync();
  }

  /// Get list of available sounds for testing (sync - basic sounds only)
  List<Map<String, String>> getAvailableSounds() {
    return _notificationService.getAvailableSounds();
  }
}
