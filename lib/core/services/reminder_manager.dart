import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/reminder.dart';
import '../models/pending_notification_info.dart';
import '../notifications/models/notification_hub_modules.dart';
import '../notifications/notification_hub.dart';
import '../notifications/services/universal_notification_repository.dart';
import '../../data/models/task.dart';
import '../../features/habits/data/models/habit.dart';
import '../../features/habits/services/habit_reminder_service.dart';
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

  /// Schedule reminders for a task
  Future<void> scheduleRemindersForTask(Task task) async {
    print('🔔 ReminderManager: Scheduling reminders for task "${task.title}"');
    print('   Reminders raw: ${task.remindersJson}');

    final reminders = _parseTaskReminders(task);

    print('   Parsed ${reminders.length} reminder(s)');

    if (reminders.isEmpty) {
      print('   No reminders to schedule');
      return;
    }

    // Don't schedule reminders for completed or not_done tasks
    if (task.status == 'completed' || task.status == 'not_done') {
      print('   Task is ${task.status}, skipping reminder');
      return;
    }

    await _notificationService.scheduleMultipleReminders(
      task: task,
      reminders: reminders,
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

  /// Schedule reminders for a habit
  Future<void> scheduleRemindersForHabit(Habit habit) async {
    await _habitReminderService.scheduleHabitReminders(habit);
  }

  /// Cancel reminders for a task
  Future<void> cancelRemindersForTask(String taskId) async {
    await _notificationService.cancelAllTaskReminders(taskId);
  }

  Future<void> _cancelHubRemindersForTask(String taskId) async {
    await NotificationHub().cancelForEntity(
      moduleId: NotificationHubModuleIds.task,
      entityId: taskId,
    );
  }

  Future<void> _deleteUniversalTaskDefinitions(String taskId) async {
    await UniversalNotificationRepository().deleteByEntity(taskId);
  }

  /// Cancel reminders for a habit
  Future<void> cancelRemindersForHabit(String habitId) async {
    await _habitReminderService.cancelHabitReminders(habitId);
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

  /// Reschedule reminders when task is updated
  Future<void> rescheduleRemindersForTask(Task task) async {
    await cancelRemindersForTask(task.id);
    await scheduleRemindersForTask(task);
  }

  /// Reschedule reminders when habit is updated
  Future<void> rescheduleRemindersForHabit(Habit habit) async {
    await _habitReminderService.rescheduleHabitReminders(habit);
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

  /// Handle task completion - cancel reminders
  Future<void> handleTaskCompleted(Task task) async {
    await cancelRemindersForTask(task.id);
    await _cancelHubRemindersForTask(task.id);
  }

  /// Handle task postpone - reschedule with new date
  Future<void> handleTaskPostponed(Task task) async {
    await rescheduleRemindersForTask(task);
  }

  /// Handle task deletion - cancel reminders
  Future<void> handleTaskDeleted(String taskId) async {
    await cancelRemindersForTask(taskId);
    await _cancelHubRemindersForTask(taskId);
    await _deleteUniversalTaskDefinitions(taskId);
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
