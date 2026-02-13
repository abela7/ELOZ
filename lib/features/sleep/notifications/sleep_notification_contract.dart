import '../../../core/notifications/models/notification_hub_modules.dart';

/// Notification contract for Sleep module.
///
/// Type IDs, section IDs, extras keys, and entity IDs used by
/// the Notification Hub for sleep reminders.
class SleepNotificationContract {
  static const String moduleId = NotificationHubModuleIds.sleep;

  /// Notification type IDs
  static const String typeReminder = 'regular';
  static const String typeWindDown = 'sleep_winddown';

  /// Section IDs (for grouping in Hub UI)
  static const String sectionBedtime = 'bedtime';
  static const String sectionWakeup = 'wakeup';
  static const String sectionWinddown = 'winddown';
  static const String sectionLowSleep = 'lowsleep';

  /// Entity IDs for single daily reminders
  static const String entityBedtime = 'sleep_bedtime';
  static const String entityWakeup = 'sleep_wakeup';
  static const String entityLowSleep = 'sleep_lowsleep';

  /// Extras for low-sleep reminder
  static const String extraSleepHours = 'sleepHours';
  static const String extraWakeDate = 'wakeDate';

  /// Entity ID prefix for wind-down (per weekday): sleep_winddown_mon, etc.
  static String windDownEntityIdForWeekday(int weekday) {
    const suffixes = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return 'sleep_winddown_${suffixes[(weekday - 1).clamp(0, 6)]}';
  }

  /// Extras keys (metadata in payloads)
  static const String extraTargetDate = 'targetDate';

  /// Conditions
  static const String conditionAlways = 'always';
}
