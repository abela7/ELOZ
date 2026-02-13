import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/models/notification_hub_schedule_request.dart';
import '../../../core/notifications/notification_hub.dart';
import '../models/sleep_record.dart';
import '../notifications/sleep_notification_contract.dart';

/// Manages low-sleep reminder settings and scheduling.
///
/// When sleep duration is below the user-defined threshold, schedules
/// a one-shot notification to remind them later (e.g. "You slept only X hours").
class LowSleepReminderService {
  static const String _enabledKey = 'sleep_lowsleep_reminder_enabled';
  static const String _thresholdHoursKey = 'sleep_lowsleep_threshold_hours';
  static const String _hoursAfterWakeKey = 'sleep_lowsleep_hours_after_wake';

  static const double _defaultThreshold = 6.0;
  static const double _defaultHoursAfterWake = 2.0;

  /// Supported threshold options in hours.
  static const List<double> thresholdOptions = [4.0, 5.0, 6.0, 7.0, 8.0];

  /// Supported "remind X hours after wake" options.
  static const List<double> hoursAfterWakeOptions = [1.0, 2.0, 3.0, 4.0];

  /// Whether low-sleep reminders are enabled.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Enable or disable low-sleep reminders.
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (!value) {
      await _cancelExistingReminder();
    }
  }

  /// Threshold in hours: notify when sleep is below this.
  Future<double> getThresholdHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_thresholdHoursKey) ?? _defaultThreshold;
  }

  /// Set threshold hours.
  Future<void> setThresholdHours(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_thresholdHoursKey, hours);
  }

  /// Hours after wake time to schedule the reminder.
  Future<double> getHoursAfterWake() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_hoursAfterWakeKey) ?? _defaultHoursAfterWake;
  }

  /// Set hours after wake.
  Future<void> setHoursAfterWake(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_hoursAfterWakeKey, hours);
  }

  /// Check if the record qualifies as low sleep and schedule reminder if enabled.
  ///
  /// Only considers main sleep (not naps). Call after creating a new sleep record.
  Future<void> checkAndSchedule(SleepRecord record) async {
    if (record.isNap) return;
    if (!await isEnabled()) return;

    final threshold = await getThresholdHours();
    final hours = record.actualSleepHours;
    if (hours >= threshold) return;

    final hoursAfterWake = await getHoursAfterWake();
    final scheduledAt = record.wakeTime.add(
      Duration(hours: hoursAfterWake.floor(), minutes: ((hoursAfterWake % 1) * 60).round()),
    );

    if (scheduledAt.isBefore(DateTime.now())) {
      return;
    }

    await _cancelExistingReminder();

    final hub = NotificationHub();
    final result = await hub.schedule(
      NotificationHubScheduleRequest(
        moduleId: SleepNotificationContract.moduleId,
        entityId: SleepNotificationContract.entityLowSleep,
        title: 'Low sleep alert',
        body:
            'You slept only ${hours.toStringAsFixed(1)} hours last night. '
            'Consider an earlier bedtime tonight.',
        scheduledAt: scheduledAt,
        extras: {
          SleepNotificationContract.extraSleepHours: hours.toStringAsFixed(1),
          SleepNotificationContract.extraWakeDate:
              '${record.wakeTime.year}-${record.wakeTime.month.toString().padLeft(2, '0')}-${record.wakeTime.day.toString().padLeft(2, '0')}',
        },
        type: 'regular',
      ),
    );

    if (kDebugMode && result.success) {
      debugPrint(
        'LowSleepReminderService: Scheduled reminder for ${scheduledAt.toIso8601String()} (slept ${hours.toStringAsFixed(1)}h < ${threshold}h)',
      );
    }
  }

  Future<void> _cancelExistingReminder() async {
    final hub = NotificationHub();
    await hub.cancelForEntity(
      moduleId: SleepNotificationContract.moduleId,
      entityId: SleepNotificationContract.entityLowSleep,
    );
  }
}
