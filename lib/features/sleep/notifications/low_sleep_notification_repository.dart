import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/notifications/models/universal_notification.dart';
import '../../../core/notifications/services/universal_notification_repository.dart';
import '../../../core/notifications/services/universal_notification_scheduler.dart';
import '../data/services/low_sleep_reminder_service.dart';
import 'sleep_notification_contract.dart';

/// Saves one low-sleep reminder definition to the Universal Notification system.
///
/// Like [WindDownNotificationRepository], low-sleep uses the Universal flow:
/// user enables + configures → we save a definition → syncAll schedules it.
/// The scheduler computes due from the latest sleep record (wake time if low).
class LowSleepNotificationRepository {
  final UniversalNotificationRepository _delegate =
      UniversalNotificationRepository();
  final LowSleepReminderService _service = LowSleepReminderService();
  final Uuid _uuid = const Uuid();

  Future<void> init() async {
    await _delegate.init();
  }

  /// Get existing low-sleep reminder definitions.
  Future<List<UniversalNotification>> getAll() async {
    await _delegate.init();
    return _delegate.getAll(
      moduleId: SleepNotificationContract.moduleId,
      section: SleepNotificationContract.sectionLowSleep,
    );
  }

  /// Save or update the low-sleep reminder definition.
  /// Call when user enables and configures in Low Sleep Settings.
  Future<void> save(UniversalNotification template) async {
    await _delegate.init();

    final existing =
        await _delegate.getAll(
          moduleId: SleepNotificationContract.moduleId,
          section: SleepNotificationContract.sectionLowSleep,
        );

    final scheduler = UniversalNotificationScheduler(repo: _delegate);
    for (final n in existing) {
      await scheduler.cancelForNotification(n);
      await _delegate.delete(n.id);
    }

    final hoursAfterWake = await _service.getHoursAfterWake();

    final n = template.copyWith(
      id: _uuid.v4(),
      entityId: SleepNotificationContract.entityLowSleep,
      entityName: 'Low Sleep Reminder',
      timing: 'after_due',
      timingValue: hoursAfterWake.floor(),
      timingUnit: 'hours',
      hour: 0,
      minute: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _delegate.save(n);

    unawaited(UniversalNotificationScheduler(repo: _delegate).syncAll());
  }

  /// Delete all low-sleep reminders (when user disables).
  Future<void> deleteAll() async {
    await _delegate.init();

    final existing =
        await _delegate.getAll(
          moduleId: SleepNotificationContract.moduleId,
          section: SleepNotificationContract.sectionLowSleep,
        );

    final scheduler = UniversalNotificationScheduler(repo: _delegate);
    for (final n in existing) {
      await scheduler.cancelForNotification(n);
      await _delegate.delete(n.id);
    }
  }
}
