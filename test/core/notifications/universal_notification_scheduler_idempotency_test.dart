import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/notifications/models/notification_hub_modules.dart';
import 'package:life_manager/core/notifications/models/notification_hub_schedule_request.dart';
import 'package:life_manager/core/notifications/models/notification_hub_schedule_result.dart';
import 'package:life_manager/core/notifications/models/universal_notification.dart';
import 'package:life_manager/core/notifications/services/notification_module_policy.dart';
import 'package:life_manager/core/notifications/services/universal_notification_repository.dart';
import 'package:life_manager/core/notifications/services/universal_notification_scheduler.dart';
import 'package:life_manager/features/mbt/notifications/mbt_notification_contract.dart';

void main() {
  group('UniversalNotificationScheduler idempotency', () {
    test('forced resync keeps MBT pending IDs stable without growth', () async {
      final repo = _FakeUniversalRepo(<UniversalNotification>[
        UniversalNotification(
          id: 'mbt_mood_daily_reminder_v1',
          moduleId: NotificationHubModuleIds.mbtMood,
          section: MbtNotificationContract.sectionMoodCheckin,
          entityId: MbtNotificationContract.entityMoodDailyCheckin,
          entityName: 'Daily Mood Check-in',
          titleTemplate: 'How was your day today?',
          bodyTemplate: 'Take a moment to log your mood.',
          typeId: MbtNotificationContract.typeMoodDailyCheckin,
          timing: 'on_due',
          timingValue: 0,
          timingUnit: 'days',
          hour: 20,
          minute: 30,
          enabled: true,
        ),
      ]);

      final pendingIds = <int>{};
      final scheduledIds = <int>[];

      final scheduler = UniversalNotificationScheduler(
        repo: repo,
        hubInitializerOverride: () async {},
        policyReaderOverride: (moduleId) async =>
            NotificationModulePolicyDecision(
              moduleId: moduleId,
              enabled: true,
              reason: NotificationModulePolicy.reasonEnabled,
            ),
        hubScheduleOverride: (NotificationHubScheduleRequest request) async {
          final id = request.notificationId!;
          pendingIds.add(id);
          scheduledIds.add(id);
          return NotificationHubScheduleResult.ok;
        },
        hubCancelOverride:
            ({
              required int notificationId,
              String? entityId,
              String? payload,
              String? title,
              Map<String, dynamic>? metadata,
            }) async {
              pendingIds.remove(notificationId);
            },
      );

      final first = await scheduler.syncAllWithMetrics();
      final second = await scheduler.syncAllWithMetrics();

      expect(first.processed, 1);
      expect(first.scheduled, 1);
      expect(second.processed, 1);
      expect(second.scheduled, 1);

      expect(scheduledIds.length, 2);
      expect(scheduledIds[0], scheduledIds[1]);
      expect(
        scheduledIds[0],
        inInclusiveRange(
          NotificationHubIdRanges.mbtMoodStart,
          NotificationHubIdRanges.mbtMoodEnd,
        ),
      );
      expect(
        pendingIds.length,
        1,
        reason: 'Forced resync should not grow pending notification count.',
      );
    });
  });
}

class _FakeUniversalRepo extends UniversalNotificationRepository {
  _FakeUniversalRepo(List<UniversalNotification> seed) {
    for (final item in seed) {
      _store[item.id] = item;
    }
  }

  final Map<String, UniversalNotification> _store =
      <String, UniversalNotification>{};

  @override
  Future<void> init() async {}

  @override
  Future<List<UniversalNotification>> getAll({
    String? moduleId,
    String? section,
    String? entityId,
    bool enabledOnly = false,
  }) async {
    var list = _store.values.toList();
    if (moduleId != null) {
      list = list.where((item) => item.moduleId == moduleId).toList();
    }
    if (section != null) {
      list = list.where((item) => item.section == section).toList();
    }
    if (entityId != null) {
      list = list.where((item) => item.entityId == entityId).toList();
    }
    if (enabledOnly) {
      list = list.where((item) => item.enabled).toList();
    }
    return list;
  }

  @override
  Future<UniversalNotification?> getById(String id) async => _store[id];

  @override
  Future<void> save(UniversalNotification notification) async {
    _store[notification.id] = notification;
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
  }
}
