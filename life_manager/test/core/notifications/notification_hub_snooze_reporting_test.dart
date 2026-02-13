import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/notifications/models/notification_lifecycle_event.dart';
import 'package:life_manager/core/notifications/models/notification_log_entry.dart';
import 'package:life_manager/core/notifications/services/notification_activity_logger.dart';
import 'package:life_manager/core/notifications/services/notification_hub_log_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Hub snooze reporting', () {
    late NotificationHubLogStore store;
    late NotificationActivityLogger logger;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = NotificationHubLogStore();
      logger = NotificationActivityLogger();
      await store.clear();
    });

    test('logs snoozed event with duration metadata', () async {
      await logger.logSnoozed(
        moduleId: 'task',
        entityId: 'task-1',
        title: 'Pay rent',
        payload: 'task|task-1|at_time|0|minutes',
        snoozeDurationMinutes: 15,
      );

      final entries = await store.query(
        moduleId: 'task',
        event: NotificationLifecycleEvent.snoozed,
      );

      expect(entries.length, 1);
      expect(entries.first.event, NotificationLifecycleEvent.snoozed);
      expect(entries.first.entityId, 'task-1');
      expect(entries.first.metadata['snoozeDurationMinutes'], 15);
    });

    test('event filter separates snoozed from tapped/action', () async {
      await logger.logTapped(
        moduleId: 'habit',
        entityId: 'habit-1',
        title: 'Hydration',
      );
      await logger.logAction(
        moduleId: 'habit',
        entityId: 'habit-1',
        actionId: 'mark_done',
      );
      await logger.logSnoozed(
        moduleId: 'habit',
        entityId: 'habit-1',
        snoozeDurationMinutes: 5,
      );

      final snoozedOnly = await store.query(
        event: NotificationLifecycleEvent.snoozed,
      );
      final tappedOnly = await store.query(event: NotificationLifecycleEvent.tapped);
      final actionOnly = await store.query(event: NotificationLifecycleEvent.action);

      expect(snoozedOnly.length, 1);
      expect(snoozedOnly.first.event, NotificationLifecycleEvent.snoozed);
      expect(tappedOnly.length, 1);
      expect(actionOnly.length, 1);
    });

    test('date range query includes only events inside window', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      await store.append(
        NotificationLogEntry.create(
          moduleId: 'task',
          entityId: 'task-old',
          event: NotificationLifecycleEvent.snoozed,
          timestamp: yesterday,
          metadata: const <String, dynamic>{'snoozeDurationMinutes': 10},
        ),
      );
      await store.append(
        NotificationLogEntry.create(
          moduleId: 'task',
          entityId: 'task-now',
          event: NotificationLifecycleEvent.snoozed,
          timestamp: now,
          metadata: const <String, dynamic>{'snoozeDurationMinutes': 20},
        ),
      );

      final from = now.subtract(const Duration(hours: 1));
      final to = now.add(const Duration(hours: 1));

      final inWindow = await store.query(
        event: NotificationLifecycleEvent.snoozed,
        from: from,
        to: to,
      );

      expect(inWindow.length, 1);
      expect(inWindow.first.entityId, 'task-now');
      expect(inWindow.first.metadata['snoozeDurationMinutes'], 20);
    });
  });
}
