import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/models/universal_notification.dart';
import '../../../core/notifications/services/notification_system_refresher.dart';
import '../../../core/notifications/services/universal_notification_repository.dart';
import '../../../core/notifications/services/universal_notification_scheduler.dart';
import 'behavior_notification_contract.dart';

class BehaviorReminderSettings {
  const BehaviorReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.daysOfWeek,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final Set<int> daysOfWeek;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);
}

class BehaviorNotificationService {
  BehaviorNotificationService({
    UniversalNotificationRepository? repository,
    UniversalNotificationScheduler? scheduler,
    Future<SharedPreferences> Function()? preferencesLoader,
    Future<void> Function({required String reason, bool force, bool debounce})?
    resyncRunner,
  }) : _repository = repository,
       _scheduler = scheduler,
       _preferencesLoader = preferencesLoader,
       _resyncRunner = resyncRunner;

  static const String _prefsEnabled = 'behavior_reminder_enabled_v1';
  static const String _prefsHour = 'behavior_reminder_hour_v1';
  static const String _prefsMinute = 'behavior_reminder_minute_v1';
  static const String _prefsDays = 'behavior_reminder_days_v1';

  final UniversalNotificationRepository? _repository;
  final UniversalNotificationScheduler? _scheduler;
  final Future<SharedPreferences> Function()? _preferencesLoader;
  final Future<void> Function({
    required String reason,
    bool force,
    bool debounce,
  })?
  _resyncRunner;

  Future<BehaviorReminderSettings> loadSettings() async {
    final prefs = await _getPreferences();
    final rawDays = prefs.getStringList(_prefsDays) ?? const <String>[];
    final parsedDays = <int>{};
    for (final item in rawDays) {
      final day = int.tryParse(item);
      if (day == null || day < 1 || day > 7) continue;
      parsedDays.add(day);
    }
    final days = parsedDays.isEmpty ? <int>{1, 2, 3, 4, 5, 6, 7} : parsedDays;
    return BehaviorReminderSettings(
      enabled: prefs.getBool(_prefsEnabled) ?? false,
      hour: prefs.getInt(_prefsHour) ?? 20,
      minute: prefs.getInt(_prefsMinute) ?? 0,
      daysOfWeek: days,
    );
  }

  Future<void> setDailyReminder({
    required bool enabled,
    required TimeOfDay time,
    Set<int>? daysOfWeek,
    bool triggerResync = true,
  }) async {
    final selectedDays = _normalizeDays(daysOfWeek);
    final prefs = await _getPreferences();
    await prefs.setBool(_prefsEnabled, enabled);
    await prefs.setInt(_prefsHour, time.hour);
    await prefs.setInt(_prefsMinute, time.minute);
    await prefs.setStringList(
      _prefsDays,
      (selectedDays.toList()..sort()).map((day) => '$day').toList(),
    );

    final repo = _repository ?? UniversalNotificationRepository();
    await repo.init();
    final scheduler = _scheduler ?? UniversalNotificationScheduler();

    final existing = await repo.getAll(
      moduleId: BehaviorNotificationContract.moduleId,
      section: BehaviorNotificationContract.sectionDailyReminder,
    );
    final existingById = <String, UniversalNotification>{
      for (final item in existing) item.id: item,
    };

    if (!enabled) {
      for (final item in existing) {
        await scheduler.cancelForNotification(item);
        await repo.delete(item.id);
      }
      if (triggerResync) {
        await _runResync(
          reason: 'behavior_daily_reminder_disabled',
          force: true,
          debounce: false,
        );
      }
      return;
    }

    for (final weekday in selectedDays) {
      final id = BehaviorNotificationContract.definitionIdForWeekday(weekday);
      final entityId = BehaviorNotificationContract.entityForWeekday(weekday);
      final name = _weekdayLabel(weekday);
      final current = existingById[id];
      final next =
          (current ??
                  UniversalNotification(
                    id: id,
                    moduleId: BehaviorNotificationContract.moduleId,
                    section: BehaviorNotificationContract.sectionDailyReminder,
                    entityId: entityId,
                    entityName: 'Behavior reminder ($name)',
                    titleTemplate: 'Log your behavior for today',
                    bodyTemplate: 'Take a moment to record what happened.',
                    typeId: BehaviorNotificationContract.typeDailyReminder,
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
                moduleId: BehaviorNotificationContract.moduleId,
                section: BehaviorNotificationContract.sectionDailyReminder,
                entityId: entityId,
                entityName: 'Behavior reminder ($name)',
                titleTemplate: 'Log your behavior for today',
                bodyTemplate: 'Take a moment to record what happened.',
                typeId: BehaviorNotificationContract.typeDailyReminder,
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
      await repo.save(next);
    }

    final selectedIds = selectedDays
        .map(BehaviorNotificationContract.definitionIdForWeekday)
        .toSet();
    for (final item in existing) {
      if (selectedIds.contains(item.id)) continue;
      await scheduler.cancelForNotification(item);
      await repo.delete(item.id);
    }

    if (triggerResync) {
      await _runResync(
        reason: 'behavior_daily_reminder_updated',
        force: true,
        debounce: false,
      );
    }
  }

  Set<int> _normalizeDays(Set<int>? daysOfWeek) {
    final input = daysOfWeek ?? <int>{1, 2, 3, 4, 5, 6, 7};
    final out = <int>{};
    for (final day in input) {
      if (day < 1 || day > 7) continue;
      out.add(day);
    }
    if (out.isEmpty) {
      return <int>{1, 2, 3, 4, 5, 6, 7};
    }
    return out;
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
      default:
        return 'Sunday';
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
