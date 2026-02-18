import '../../../core/notifications/models/notification_hub_modules.dart';

class BehaviorNotificationContract {
  static const String moduleId = NotificationHubModuleIds.behavior;

  static const String sectionDailyReminder = 'behavior_daily_reminder';
  static const String typeDailyReminder = 'behavior_daily_reminder';

  static String entityForWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'behavior_daily_mon';
      case 2:
        return 'behavior_daily_tue';
      case 3:
        return 'behavior_daily_wed';
      case 4:
        return 'behavior_daily_thu';
      case 5:
        return 'behavior_daily_fri';
      case 6:
        return 'behavior_daily_sat';
      case 7:
      default:
        return 'behavior_daily_sun';
    }
  }

  static int? weekdayFromEntity(String entityId) {
    switch (entityId) {
      case 'behavior_daily_mon':
        return 1;
      case 'behavior_daily_tue':
        return 2;
      case 'behavior_daily_wed':
        return 3;
      case 'behavior_daily_thu':
        return 4;
      case 'behavior_daily_fri':
        return 5;
      case 'behavior_daily_sat':
        return 6;
      case 'behavior_daily_sun':
        return 7;
      default:
        return null;
    }
  }

  static String definitionIdForWeekday(int weekday) {
    return 'behavior_daily_reminder_$weekday';
  }
}
