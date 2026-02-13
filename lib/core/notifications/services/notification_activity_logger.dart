import '../models/notification_lifecycle_event.dart';
import '../models/notification_log_entry.dart';
import 'notification_hub_log_store.dart';

/// Logs notification lifecycle events for activity stats (Scheduled, Tapped,
/// Actions, Failed). Used when notifications are scheduled or handled outside
/// the hub (e.g. Task/Habit via ReminderManager/NotificationService).
///
/// The hub dashboard "Activity Today" counts events from the log store. The
/// hub's own schedule/tap/action handlers already append; this logger ensures
/// Task and Habit flows (which bypass the hub) also get counted.
class NotificationActivityLogger {
  static final NotificationActivityLogger _instance =
      NotificationActivityLogger._internal();
  factory NotificationActivityLogger() => _instance;
  NotificationActivityLogger._internal();

  final NotificationHubLogStore _logStore = NotificationHubLogStore();

  /// Log a scheduled event (e.g. when NotificationService schedules task/habit).
  Future<void> logScheduled({
    required String moduleId,
    required String entityId,
    String title = '',
    String body = '',
    String? payload,
  }) async {
    await _logStore.append(
      NotificationLogEntry.create(
        moduleId: moduleId,
        entityId: entityId,
        title: title,
        body: body,
        payload: payload,
        event: NotificationLifecycleEvent.scheduled,
      ),
    );
  }

  /// Log a tap event (e.g. when user taps task/habit notification via legacy path).
  Future<void> logTapped({
    required String moduleId,
    required String entityId,
    String title = '',
    String body = '',
    String? payload,
  }) async {
    await _logStore.append(
      NotificationLogEntry.create(
        moduleId: moduleId,
        entityId: entityId,
        title: title,
        body: body,
        payload: payload,
        event: NotificationLifecycleEvent.tapped,
      ),
    );
  }
}
