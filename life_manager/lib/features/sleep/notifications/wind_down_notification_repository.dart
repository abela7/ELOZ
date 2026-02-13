import 'dart:async';
import 'package:uuid/uuid.dart';

import '../../../core/notifications/models/universal_notification.dart';
import '../../../core/notifications/services/universal_notification_repository.dart';
import '../../../core/notifications/services/universal_notification_scheduler.dart';
import '../data/models/wind_down_schedule.dart';
import '../data/services/wind_down_schedule_service.dart';

/// Wraps [UniversalNotificationRepository] to expand wind-down reminders
/// into one notification per configured day when saving.
///
/// User configures one reminder (title, body, icon, actions) – this adapter
/// creates sleep_winddown_mon, sleep_winddown_tue, etc. with correct
/// hour/minute from the wind-down schedule.
class WindDownNotificationRepository extends UniversalNotificationRepository {
  WindDownNotificationRepository({UniversalNotificationRepository? delegate})
      : _delegate = delegate ?? UniversalNotificationRepository();

  final UniversalNotificationRepository _delegate;
  final WindDownScheduleService _scheduleService = WindDownScheduleService();
  final Uuid _uuid = const Uuid();

  @override
  Future<void> init() async {
    await _delegate.init();
  }

  @override
  Future<List<UniversalNotification>> getByEntity(String entityId) async {
    return _delegate.getByEntity(entityId);
  }

  @override
  Future<List<UniversalNotification>> getAll({
    String? moduleId,
    String? section,
    String? entityId,
    bool enabledOnly = false,
  }) async {
    return _delegate.getAll(
      moduleId: moduleId,
      section: section,
      entityId: entityId,
      enabledOnly: enabledOnly,
    );
  }

  @override
  Future<UniversalNotification?> getById(String id) async {
    return _delegate.getById(id);
  }

  @override
  Future<void> save(UniversalNotification notification) async {
    if (notification.moduleId == 'sleep' && notification.section == 'winddown') {
      await _saveWindDownExpanded(notification);
      return;
    }
    await _delegate.save(notification);
  }

  Future<void> _saveWindDownExpanded(UniversalNotification template) async {
    await _delegate.init();

    final schedule = await _scheduleService.getFullSchedule();
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];

    final toSave = <UniversalNotification>[];
    for (int w = 1; w <= 7; w++) {
      final time = schedule[w];
      if (time == null) continue;

      final entityId = SleepWindDownPayload.entityIdForWeekday(w);
      final entityName = 'Wind Down ${names[w - 1]}';

      final n = template.copyWith(
        id: _uuid.v4(),
        entityId: entityId,
        entityName: entityName,
        hour: time.hour,
        minute: time.minute,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      toSave.add(n);
    }

    final existing = await _delegate.getAll(
      moduleId: template.moduleId,
      section: template.section,
    );
    final scheduler = UniversalNotificationScheduler();
    await Future.wait(existing.map((e) async {
      await scheduler.cancelForNotification(e);
      await _delegate.delete(e.id);
    }));

    for (final n in toSave) {
      await _delegate.save(n);
    }

    // Sync to OS in background – don't block the UI (Notification Hub's job)
    unawaited(UniversalNotificationScheduler().syncAll());
  }

  @override
  Future<void> delete(String id) async {
    await _delegate.delete(id);
  }

  /// Re-syncs existing wind-down notifications with the current schedule.
  /// Call when the user changes bedtime or reminder offset in Wind-Down settings.
  /// Rebuilds all per-day notifications with correct hour/minute from the schedule.
  Future<void> resyncFromSchedule() async {
    await _delegate.init();

    final existing = await _delegate.getAll(
      moduleId: 'sleep',
      section: 'winddown',
    );
    if (existing.isEmpty) return;

    final offset = await _scheduleService.getReminderOffsetMinutes();
    final template = existing.first.copyWith(
      timingValue: offset,
      timingUnit: 'minutes',
    );
    await _saveWindDownExpanded(template);
  }
}
