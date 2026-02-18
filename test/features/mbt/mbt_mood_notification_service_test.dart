import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/notifications/models/universal_notification.dart';
import 'package:life_manager/core/notifications/services/universal_notification_repository.dart';
import 'package:life_manager/core/notifications/services/universal_notification_scheduler.dart';
import 'package:life_manager/features/mbt/notifications/mbt_mood_notification_service.dart';
import 'package:life_manager/features/mbt/notifications/mbt_notification_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MbtMoodNotificationService', () {
    test(
      'keeps one universal definition and updates time idempotently',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final fakeRepo = _FakeUniversalRepo();
        final fakeScheduler = _FakeUniversalScheduler();
        final resyncReasons = <String>[];

        await fakeRepo.save(
          UniversalNotification(
            id: 'legacy_extra',
            moduleId: MbtNotificationContract.moduleId,
            section: MbtNotificationContract.sectionMoodCheckin,
            entityId: MbtNotificationContract.entityMoodDailyCheckin,
            entityName: 'Legacy',
            titleTemplate: 'Old',
            bodyTemplate: 'Old',
            typeId: MbtNotificationContract.typeMoodDailyCheckin,
          ),
        );

        final service = MbtMoodNotificationService(
          repository: fakeRepo,
          scheduler: fakeScheduler,
          resyncRunner:
              ({required reason, force = false, debounce = false}) async {
                resyncReasons.add(reason);
              },
        );

        await service.setDailyReminder(
          enabled: true,
          time: const TimeOfDay(hour: 20, minute: 30),
        );
        await service.setDailyReminder(
          enabled: true,
          time: const TimeOfDay(hour: 21, minute: 15),
        );

        final defs = await fakeRepo.getAll(
          moduleId: MbtNotificationContract.moduleId,
        );
        expect(defs.length, 1);
        expect(defs.first.id, 'mbt_mood_daily_reminder_v1');
        expect(defs.first.hour, 21);
        expect(defs.first.minute, 15);
        expect(defs.first.enabled, isTrue);

        expect(fakeScheduler.cancelledIds, contains('legacy_extra'));
        expect(resyncReasons, <String>[
          'mbt_mood_reminder_updated',
          'mbt_mood_reminder_updated',
        ]);
      },
    );

    test('disable removes definition and persists settings', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final fakeRepo = _FakeUniversalRepo();
      final fakeScheduler = _FakeUniversalScheduler();
      final resyncReasons = <String>[];

      final service = MbtMoodNotificationService(
        repository: fakeRepo,
        scheduler: fakeScheduler,
        resyncRunner:
            ({required reason, force = false, debounce = false}) async {
              resyncReasons.add(reason);
            },
      );

      await service.setDailyReminder(
        enabled: true,
        time: const TimeOfDay(hour: 19, minute: 45),
      );
      await service.setDailyReminder(
        enabled: false,
        time: const TimeOfDay(hour: 19, minute: 45),
      );

      final defs = await fakeRepo.getAll(
        moduleId: MbtNotificationContract.moduleId,
      );
      expect(defs, isEmpty);
      expect(
        fakeScheduler.cancelledIds,
        contains('mbt_mood_daily_reminder_v1'),
      );
      expect(resyncReasons, <String>[
        'mbt_mood_reminder_updated',
        'mbt_mood_reminder_disabled',
      ]);

      final settings = await service.loadSettings();
      expect(settings.enabled, isFalse);
      expect(settings.hour, 19);
      expect(settings.minute, 45);
    });

    test('can skip resync when triggerResync is false', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final fakeRepo = _FakeUniversalRepo();
      final fakeScheduler = _FakeUniversalScheduler();
      var resyncCount = 0;

      final service = MbtMoodNotificationService(
        repository: fakeRepo,
        scheduler: fakeScheduler,
        resyncRunner:
            ({required reason, force = false, debounce = false}) async {
              resyncCount++;
            },
      );

      await service.setDailyReminder(
        enabled: true,
        time: const TimeOfDay(hour: 18, minute: 0),
        triggerResync: false,
      );

      expect(resyncCount, 0);
      final defs = await fakeRepo.getAll(
        moduleId: MbtNotificationContract.moduleId,
      );
      expect(defs.length, 1);
    });
  });
}

class _FakeUniversalRepo extends UniversalNotificationRepository {
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
    var items = _store.values.toList();
    if (moduleId != null) {
      items = items.where((item) => item.moduleId == moduleId).toList();
    }
    if (section != null) {
      items = items.where((item) => item.section == section).toList();
    }
    if (entityId != null) {
      items = items.where((item) => item.entityId == entityId).toList();
    }
    if (enabledOnly) {
      items = items.where((item) => item.enabled).toList();
    }
    return items;
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

class _FakeUniversalScheduler extends UniversalNotificationScheduler {
  final List<String> cancelledIds = <String>[];

  @override
  Future<void> cancelForNotification(UniversalNotification n) async {
    cancelledIds.add(n.id);
  }
}
