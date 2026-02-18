import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/notifications/models/notification_hub_modules.dart';
import 'package:life_manager/core/notifications/notification_hub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationHub.generateNotificationId', () {
    final hub = NotificationHub();

    test('is deterministic for identical inputs', () {
      final scheduledAt = DateTime(2026, 2, 16, 9, 30, 0);
      final idA = hub.generateNotificationId(
        moduleId: NotificationHubModuleIds.task,
        entityId: 'task-42',
        reminderType: 'before',
        reminderValue: 15,
        reminderUnit: 'minutes',
        scheduledAt: scheduledAt,
      );
      final idB = hub.generateNotificationId(
        moduleId: NotificationHubModuleIds.task,
        entityId: 'task-42',
        reminderType: 'before',
        reminderValue: 15,
        reminderUnit: 'minutes',
        scheduledAt: scheduledAt,
      );

      expect(idA, idB);
    });

    test('includes scheduledAt seconds in signature', () {
      final idA = hub.generateNotificationId(
        moduleId: NotificationHubModuleIds.task,
        entityId: 'task-42',
        reminderType: 'at_time',
        scheduledAt: DateTime(2026, 2, 16, 9, 30, 0),
      );
      final idB = hub.generateNotificationId(
        moduleId: NotificationHubModuleIds.task,
        entityId: 'task-42',
        reminderType: 'at_time',
        scheduledAt: DateTime(2026, 2, 16, 9, 30, 30),
      );

      expect(idA, isNot(idB));
    });

    test('falls inside reserved ranges even without adapter registration', () {
      final taskId = hub.generateNotificationId(
        moduleId: NotificationHubModuleIds.task,
        entityId: 'task-1',
      );
      final habitId = hub.generateNotificationId(
        moduleId: NotificationHubModuleIds.habit,
        entityId: 'habit-1',
      );
      final financeId = hub.generateNotificationId(
        moduleId: NotificationHubModuleIds.finance,
        entityId: 'bill-1',
      );
      final sleepId = hub.generateNotificationId(
        moduleId: NotificationHubModuleIds.sleep,
        entityId: 'sleep_winddown_mon',
      );
      final mbtId = hub.generateNotificationId(
        moduleId: NotificationHubModuleIds.mbtMood,
        entityId: 'mbt_mood_daily_checkin',
      );
      final behaviorId = hub.generateNotificationId(
        moduleId: NotificationHubModuleIds.behavior,
        entityId: 'behavior_daily_mon',
      );

      expect(
        taskId,
        inInclusiveRange(
          NotificationHubIdRanges.taskStart,
          NotificationHubIdRanges.taskEnd,
        ),
      );
      expect(
        habitId,
        inInclusiveRange(
          NotificationHubIdRanges.habitStart,
          NotificationHubIdRanges.habitEnd,
        ),
      );
      expect(
        financeId,
        inInclusiveRange(
          NotificationHubIdRanges.financeStart,
          NotificationHubIdRanges.financeEnd,
        ),
      );
      expect(
        sleepId,
        inInclusiveRange(
          NotificationHubIdRanges.sleepStart,
          NotificationHubIdRanges.sleepEnd,
        ),
      );
      expect(
        mbtId,
        inInclusiveRange(
          NotificationHubIdRanges.mbtMoodStart,
          NotificationHubIdRanges.mbtMoodEnd,
        ),
      );
      expect(
        behaviorId,
        inInclusiveRange(
          NotificationHubIdRanges.behaviorStart,
          NotificationHubIdRanges.behaviorEnd,
        ),
      );
    });
  });
}
