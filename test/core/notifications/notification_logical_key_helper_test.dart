import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/models/pending_notification_info.dart';
import 'package:life_manager/core/notifications/models/notification_hub_modules.dart';
import 'package:life_manager/core/notifications/services/notification_flow_trace.dart';
import 'package:life_manager/core/notifications/services/notification_logical_key_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationLogicalKeyHelper', () {
    test('builds stable logical key from hub payload', () {
      final info = PendingNotificationInfo(
        id: 42,
        type: 'unknown',
        entityId: '',
        title: 'Test',
        body: 'Body',
        payload: 'task|entity-1|before|5|minutes|sourceFlow:test',
        willFireAt: DateTime(2026, 2, 16, 10, 30),
      );

      final key = NotificationLogicalKeyHelper.logicalKeyFor(info);
      expect(
        key,
        'task|entity-1|before|5|minutes|'
        '${DateTime(2026, 2, 16, 10, 30).millisecondsSinceEpoch}',
      );
    });

    test('falls back to pending fields when payload is not parseable', () {
      final info = PendingNotificationInfo(
        id: 7,
        type: 'habit',
        entityId: 'habit-1',
        title: 'Habit',
        body: '',
        payload: 'legacy_format',
        reminderType: 'at_time',
        reminderValue: 0,
        reminderUnit: 'minutes',
        willFireAt: DateTime(2026, 2, 16, 9, 0),
      );

      final key = NotificationLogicalKeyHelper.logicalKeyFor(info);
      expect(
        key,
        'habit|habit-1|at_time|0|minutes|'
        '${DateTime(2026, 2, 16, 9, 0).millisecondsSinceEpoch}',
      );
    });

    test('validates module ranges', () {
      expect(
        NotificationLogicalKeyHelper.isInModuleRange(
          NotificationHubModuleIds.task,
          NotificationHubIdRanges.taskStart,
        ),
        isTrue,
      );
      expect(
        NotificationLogicalKeyHelper.isInModuleRange(
          NotificationHubModuleIds.task,
          NotificationHubIdRanges.habitStart,
        ),
        isFalse,
      );
      expect(
        NotificationLogicalKeyHelper.isInModuleRange(
          NotificationHubModuleIds.mbtMood,
          NotificationHubIdRanges.mbtMoodStart,
        ),
        isTrue,
      );
      expect(
        NotificationLogicalKeyHelper.isInModuleRange(
          NotificationHubModuleIds.behavior,
          NotificationHubIdRanges.behaviorStart,
        ),
        isTrue,
      );
      expect(NotificationLogicalKeyHelper.isInKnownRange(999999), isFalse);
    });
  });

  group('NotificationFlowTrace', () {
    test('stores recent events with source flow and reason', () {
      NotificationFlowTrace.clearRecentEvents();
      NotificationFlowTrace.log(
        event: 'legacy_cancel_result',
        sourceFlow: 'unit_test',
        moduleId: NotificationHubModuleIds.task,
        entityId: 'task-1',
        reason: 'policy_disabled',
      );

      final events = NotificationFlowTrace.recentEvents(
        event: 'legacy_cancel_result',
        moduleId: NotificationHubModuleIds.task,
        entityId: 'task-1',
      );

      expect(events, isNotEmpty);
      expect(events.last['sourceFlow'], 'unit_test');
      expect(events.last['reason'], 'policy_disabled');
    });
  });
}
