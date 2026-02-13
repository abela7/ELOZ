import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/notification_service.dart';

/// Schedules bedtime/wake reminders based on target times from settings.
class SleepReminderService {
  static const String _trackedIdsPrefKey = 'sleep_tracked_reminder_ids_v1';
  static const String _enableRemindersKey = 'sleep_enable_reminders';
  static const String _bedtimeReminderKey = 'sleep_bedtime_reminder_minutes';
  static const String _wakeupReminderKey = 'sleep_wakeup_reminder_minutes';
  static const String _targetBedTimeKey = 'sleep_target_bed_time';
  static const String _targetWakeTimeKey = 'sleep_target_wake_time';

  final NotificationService _notificationService = NotificationService();

  DateTime _normalize(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> refreshUpcomingReminders({int daysAhead = 7}) async {
    await cancelTrackedReminders();

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enableRemindersKey) ?? false;
    if (!enabled) return;

    final bedStr = prefs.getString(_targetBedTimeKey) ?? '22:00';
    final wakeStr = prefs.getString(_targetWakeTimeKey) ?? '06:00';

    final bedTime = _parseTime(bedStr);
    final wakeTime = _parseTime(wakeStr);
    if (bedTime == null || wakeTime == null) return;

    final bedMins = prefs.getInt(_bedtimeReminderKey) ?? 30;
    final wakeMins = prefs.getInt(_wakeupReminderKey) ?? 0;

    final now = DateTime.now();
    final scheduledIds = <int>[];

    for (int i = 0; i <= daysAhead; i++) {
      final date = _normalize(now.add(Duration(days: i)));
      final bedtimeDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        bedTime.hour,
        bedTime.minute,
      );
      var wakeDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        wakeTime.hour,
        wakeTime.minute,
      );
      if (!wakeDateTime.isAfter(bedtimeDateTime)) {
        wakeDateTime = wakeDateTime.add(const Duration(days: 1));
      }

      if (bedMins > 0) {
        final reminderTime = bedtimeDateTime.subtract(Duration(minutes: bedMins));
        if (reminderTime.isAfter(now)) {
          final notificationId = _notificationIdFor(date: date, type: 1);
          final success = await _notificationService.scheduleSimpleReminder(
            notificationId: notificationId,
            title: 'Bedtime Reminder',
            body: 'Time to wind down for sleep.',
            scheduledAt: reminderTime,
            payload: 'sleep_reminder|bed|${date.toIso8601String()}',
          );
          if (success) scheduledIds.add(notificationId);
        }
      }

      if (wakeMins > 0) {
        final reminderTime = wakeDateTime.add(Duration(minutes: wakeMins));
        if (reminderTime.isAfter(now)) {
          final notificationId = _notificationIdFor(date: date, type: 2);
          final success = await _notificationService.scheduleSimpleReminder(
            notificationId: notificationId,
            title: 'Wake-up Check',
            body: 'Time to start your day.',
            scheduledAt: reminderTime,
            payload: 'sleep_reminder|wake|${date.toIso8601String()}',
          );
          if (success) scheduledIds.add(notificationId);
        }
      }
    }

    await prefs.setStringList(
      _trackedIdsPrefKey,
      scheduledIds.map((id) => id.toString()).toList(),
    );
  }

  TimeOfDay? _parseTime(String s) {
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> cancelTrackedReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final rawIds = prefs.getStringList(_trackedIdsPrefKey) ?? const [];

    for (final raw in rawIds) {
      final id = int.tryParse(raw);
      if (id == null) continue;
      await _notificationService.cancelSimpleReminder(id);
    }

    await prefs.remove(_trackedIdsPrefKey);
  }

  int _notificationIdFor({required DateTime date, required int type}) {
    final dayCode = ((date.year % 100) * 10000) + (date.month * 100) + date.day;
    return 54000000 + (dayCode * 10) + type;
  }
}
