import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/notifications/models/notification_hub_modules.dart';
import 'package:life_manager/core/services/reminder_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderManager entity lock', () {
    test('serializes operations for the same entity key', () async {
      final manager = ReminderManager();
      final timeline = <String>[];

      Future<void> run(String label, int delayMs) {
        return manager.runEntityLockedForTest<void>(
          scope: NotificationHubModuleIds.task,
          entityId: 'task-lock-test',
          action: () async {
            timeline.add('start-$label');
            await Future<void>.delayed(Duration(milliseconds: delayMs));
            timeline.add('end-$label');
          },
        );
      }

      final f1 = run('a', 30);
      final f2 = run('b', 10);
      final f3 = run('c', 1);
      await Future.wait<void>(<Future<void>>[f1, f2, f3]);

      expect(
        timeline,
        <String>[
          'start-a',
          'end-a',
          'start-b',
          'end-b',
          'start-c',
          'end-c',
        ],
      );
    });

    test('allows parallel operations for different entity keys', () async {
      final manager = ReminderManager();
      var firstRunning = false;
      var secondStartedWhileFirstRunning = false;

      final first = manager.runEntityLockedForTest<void>(
        scope: NotificationHubModuleIds.task,
        entityId: 'task-lock-a',
        action: () async {
          firstRunning = true;
          await Future<void>.delayed(const Duration(milliseconds: 40));
          firstRunning = false;
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));

      final second = manager.runEntityLockedForTest<void>(
        scope: NotificationHubModuleIds.task,
        entityId: 'task-lock-b',
        action: () async {
          if (firstRunning) {
            secondStartedWhileFirstRunning = true;
          }
        },
      );

      await Future.wait<void>(<Future<void>>[first, second]);
      expect(secondStartedWhileFirstRunning, isTrue);
    });
  });
}
