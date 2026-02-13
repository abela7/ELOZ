import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/notifications.dart';
import '../../../core/services/notification_service.dart';
import '../../../routing/app_router.dart';
import '../data/services/low_sleep_reminder_service.dart';
import '../data/services/sleep_target_service.dart';
import '../data/services/wind_down_schedule_service.dart';
import 'sleep_notification_contract.dart';

String _formatTimeOfDay(TimeOfDay t) {
  final h = t.hour;
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final m = t.minute.toString().padLeft(2, '0');
  final ampm = h < 12 ? 'AM' : 'PM';
  return '$hour12:$m $ampm';
}

/// Handles Sleep module notification actions (bedtime, wake-up, wind-down).
class SleepNotificationAdapter implements MiniAppNotificationAdapter {
  static const _targetBedTimeKey = 'sleep_target_bed_time';
  static const _targetWakeTimeKey = 'sleep_target_wake_time';

  @override
  List<HubNotificationSection> get sections => [
        HubNotificationSection(
          id: SleepNotificationContract.sectionBedtime,
          displayName: 'Bedtime',
          iconCodePoint: Icons.nightlight_round.codePoint,
          colorValue: Colors.indigo.toARGB32(),
        ),
        HubNotificationSection(
          id: SleepNotificationContract.sectionWakeup,
          displayName: 'Wake Up',
          iconCodePoint: Icons.wb_sunny_rounded.codePoint,
          colorValue: Colors.amber.toARGB32(),
        ),
        HubNotificationSection(
          id: SleepNotificationContract.sectionWinddown,
          displayName: 'Wind-Down',
          iconCodePoint: Icons.bedtime_rounded.codePoint,
          colorValue: Colors.indigo.shade700.toARGB32(),
        ),
        HubNotificationSection(
          id: SleepNotificationContract.sectionLowSleep,
          displayName: 'Low Sleep',
          iconCodePoint: Icons.warning_amber_rounded.codePoint,
          colorValue: Colors.orange.toARGB32(),
        ),
      ];

  @override
  NotificationHubModule get module => NotificationHubModule(
        moduleId: NotificationHubModuleIds.sleep,
        displayName: 'Sleep',
        description: 'Bedtime, wake-up and wind-down reminders',
        idRangeStart: 300000,
        idRangeEnd: 309999,
        iconCodePoint: Icons.nightlight_round.codePoint,
        colorValue: Colors.indigo.toARGB32(),
      );

  @override
  List<HubNotificationType> get customNotificationTypes =>
      const <HubNotificationType>[];

  @override
  Future<void> onNotificationTapped(NotificationHubPayload payload) async {
    await _navigateToSleep();
  }

  @override
  Future<bool> onNotificationAction({
    required String actionId,
    required NotificationHubPayload payload,
    int? notificationId,
  }) async {
    switch (actionId) {
      case 'go_to_sleep':
      case 'view':
      case 'open':
        await _navigateToSleep();
        return true;
      case 'dismiss':
        if (notificationId != null) {
          await NotificationService().cancelPendingNotificationById(
            notificationId: notificationId,
            entityId: payload.entityId,
          );
        }
        return true;
      default:
        return false;
    }
  }

  @override
  Future<void> onNotificationDeleted(NotificationHubPayload payload) async {
    // Sleep reminders are one-shot; no source entity to update.
  }

  static const _windDownWeekdayMap = {
    'sleep_winddown_mon': 1,
    'sleep_winddown_tue': 2,
    'sleep_winddown_wed': 3,
    'sleep_winddown_thu': 4,
    'sleep_winddown_fri': 5,
    'sleep_winddown_sat': 6,
    'sleep_winddown_sun': 7,
  };

  @override
  Future<Map<String, String>> resolveVariablesForEntity(
    String entityId,
    String section,
  ) async {
    if (section == SleepNotificationContract.sectionLowSleep) {
      final hours =
          await LowSleepReminderService().getLastScheduledSleepHoursFormatted();
      return {
        '{goalName}': '7 hours',
        '{bedtime}': '10:00 PM',
        '{wakeTime}': '6:00 AM',
        '{duration}': '6.0h',
        '{sleepHours}': hours,
      };
    }

    final targetService = SleepTargetService();
    final settings = await targetService.getSettings();
    final targetHours = settings.targetHours;
    final duration = '${targetHours.toStringAsFixed(1)}h';
    final goalName = '${targetHours.toStringAsFixed(1)} hours';

    String bedtimeStr;
    String wakeTimeStr;

    if (section == SleepNotificationContract.sectionWinddown) {
      final weekday = _windDownWeekdayMap[entityId];
      TimeOfDay? windDownBedtime;
      if (weekday != null) {
        windDownBedtime =
            await WindDownScheduleService().getBedtimeForWeekday(weekday);
      }
      bedtimeStr = windDownBedtime != null
          ? _formatTimeOfDay(windDownBedtime)
          : '10:00 PM';
      wakeTimeStr = '6:30 AM';
    } else {
      final prefs = await SharedPreferences.getInstance();
      final bedStr = prefs.getString(_targetBedTimeKey) ?? '22:00';
      final wakeStr = prefs.getString(_targetWakeTimeKey) ?? '06:00';

      TimeOfDay? parseTime(String s) {
        final parts = s.split(':');
        if (parts.length < 2) return null;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) return null;
        return TimeOfDay(hour: h, minute: m);
      }

      final bedTime = parseTime(bedStr);
      final wakeTime = parseTime(wakeStr);

      bedtimeStr = bedTime != null ? _formatTimeOfDay(bedTime) : '10:00 PM';
      wakeTimeStr = wakeTime != null ? _formatTimeOfDay(wakeTime) : '6:30 AM';
    }

    return {
      '{goalName}': goalName,
      '{bedtime}': bedtimeStr,
      '{wakeTime}': wakeTimeStr,
      '{duration}': duration,
    };
  }

  Future<void> _navigateToSleep() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    GoRouter.of(context).go('/sleep');
  }
}
