import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/models/universal_notification.dart';
import '../../../core/notifications/services/notification_system_refresher.dart';
import '../../../core/notifications/services/universal_notification_repository.dart';
import '../../../core/notifications/services/universal_notification_scheduler.dart';
import 'mbt_notification_contract.dart';

class MbtMoodReminderSettings {
  const MbtMoodReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);
}

/// Owns MBT mood reminder settings and universal definition lifecycle.
class MbtMoodNotificationService {
  MbtMoodNotificationService({
    UniversalNotificationRepository? repository,
    UniversalNotificationScheduler? scheduler,
    Future<SharedPreferences> Function()? preferencesLoader,
    Future<void> Function({required String reason, bool force, bool debounce})?
    resyncRunner,
  }) : _repository = repository,
       _scheduler = scheduler,
       _preferencesLoader = preferencesLoader,
       _resyncRunner = resyncRunner;

  static const String _prefsEnabled = 'mbt_mood_reminder_enabled_v1';
  static const String _prefsHour = 'mbt_mood_reminder_hour_v1';
  static const String _prefsMinute = 'mbt_mood_reminder_minute_v1';
  static const String _definitionId = 'mbt_mood_daily_reminder_v1';

  final UniversalNotificationRepository? _repository;
  final UniversalNotificationScheduler? _scheduler;
  final Future<SharedPreferences> Function()? _preferencesLoader;
  final Future<void> Function({
    required String reason,
    bool force,
    bool debounce,
  })?
  _resyncRunner;

  Future<MbtMoodReminderSettings> loadSettings() async {
    final prefs = await _getPreferences();
    return MbtMoodReminderSettings(
      enabled: prefs.getBool(_prefsEnabled) ?? false,
      hour: prefs.getInt(_prefsHour) ?? 20,
      minute: prefs.getInt(_prefsMinute) ?? 30,
    );
  }

  Future<void> setDailyReminder({
    required bool enabled,
    required TimeOfDay time,
    bool triggerResync = true,
  }) async {
    final prefs = await _getPreferences();
    await prefs.setBool(_prefsEnabled, enabled);
    await prefs.setInt(_prefsHour, time.hour);
    await prefs.setInt(_prefsMinute, time.minute);

    final repo = _repository ?? UniversalNotificationRepository();
    await repo.init();
    final scheduler = _scheduler ?? UniversalNotificationScheduler();
    final existing = await repo.getAll(
      moduleId: MbtNotificationContract.moduleId,
      section: MbtNotificationContract.sectionMoodCheckin,
      entityId: MbtNotificationContract.entityMoodDailyCheckin,
    );

    for (final item in existing.where((n) => n.id != _definitionId)) {
      await scheduler.cancelForNotification(item);
      await repo.delete(item.id);
    }

    var current = await repo.getById(_definitionId);
    if (current == null) {
      for (final item in existing) {
        if (item.id == _definitionId) {
          current = item;
          break;
        }
      }
    }

    if (!enabled) {
      if (current != null) {
        await scheduler.cancelForNotification(current);
        await repo.delete(current.id);
      }
      if (triggerResync) {
        await _runResync(
          reason: 'mbt_mood_reminder_disabled',
          force: true,
          debounce: false,
        );
      }
      return;
    }

    final notification =
        (current ??
                UniversalNotification(
                  id: _definitionId,
                  moduleId: MbtNotificationContract.moduleId,
                  section: MbtNotificationContract.sectionMoodCheckin,
                  entityId: MbtNotificationContract.entityMoodDailyCheckin,
                  entityName: 'Daily Mood Check-in',
                  titleTemplate: 'How was your day today?',
                  bodyTemplate: 'Take a moment to log your mood.',
                  typeId: MbtNotificationContract.typeMoodDailyCheckin,
                  timing: 'on_due',
                  timingValue: 0,
                  timingUnit: 'days',
                  hour: time.hour,
                  minute: time.minute,
                  condition: 'always',
                  enabled: true,
                  actionsEnabled: false,
                ))
            .copyWith(
              moduleId: MbtNotificationContract.moduleId,
              section: MbtNotificationContract.sectionMoodCheckin,
              entityId: MbtNotificationContract.entityMoodDailyCheckin,
              entityName: 'Daily Mood Check-in',
              titleTemplate: 'How was your day today?',
              bodyTemplate: 'Take a moment to log your mood.',
              typeId: MbtNotificationContract.typeMoodDailyCheckin,
              timing: 'on_due',
              timingValue: 0,
              timingUnit: 'days',
              hour: time.hour,
              minute: time.minute,
              condition: 'always',
              enabled: true,
              actionsEnabled: false,
              updatedAt: DateTime.now(),
            );

    await repo.save(notification);

    if (triggerResync) {
      await _runResync(
        reason: 'mbt_mood_reminder_updated',
        force: true,
        debounce: false,
      );
    }
  }

  Future<SharedPreferences> _getPreferences() async {
    final loader = _preferencesLoader;
    if (loader != null) {
      return loader();
    }
    return SharedPreferences.getInstance();
  }

  Future<void> _runResync({
    required String reason,
    required bool force,
    required bool debounce,
  }) async {
    final runner = _resyncRunner;
    if (runner != null) {
      await runner(reason: reason, force: force, debounce: debounce);
      return;
    }
    await NotificationSystemRefresher.instance.resyncAll(
      reason: reason,
      force: force,
      debounce: debounce,
    );
  }
}
