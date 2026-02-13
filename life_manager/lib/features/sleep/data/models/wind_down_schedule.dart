import 'package:flutter/material.dart';

/// Wind-down schedule for notification hub handoff.
///
/// Contains all data needed by the Notification Hub to schedule
/// wind-down reminders for each day.
class SleepWindDownPayload {
  final bool enabled;
  final Map<int, TimeOfDay> bedtimesByWeekday;
  final int reminderOffsetMinutes;
  final String titleTemplate;
  final String bodyTemplate;

  const SleepWindDownPayload({
    this.enabled = false,
    this.bedtimesByWeekday = const {},
    this.reminderOffsetMinutes = 30,
    this.titleTemplate = 'Wind Down',
    this.bodyTemplate = 'Time to prepare for sleep.',
  });

  /// Entity IDs for Notification Hub: sleep_winddown_mon, sleep_winddown_tue, etc.
  static String entityIdForWeekday(int weekday) {
    const suffixes = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return 'sleep_winddown_${suffixes[(weekday - 1).clamp(0, 6)]}';
  }

  /// One reminder definition per enabled day. Use when configuring Notification Hub.
  List<Map<String, dynamic>> toUniversalNotificationDefinitions() {
    final list = <Map<String, dynamic>>[];
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (final e in bedtimesByWeekday.entries) {
      final t = e.value;
      list.add({
        'moduleId': 'sleep',
        'section': 'winddown',
        'entityId': entityIdForWeekday(e.key),
        'entityName': 'Wind Down ${names[(e.key - 1).clamp(0, 6)]}',
        'titleTemplate': titleTemplate,
        'bodyTemplate': bodyTemplate,
        'timing': 'before',
        'timingValue': reminderOffsetMinutes,
        'timingUnit': 'minutes',
        'hour': t.hour,
        'minute': t.minute,
        'enabled': enabled,
      });
    }
    return list;
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'bedtimesByWeekday': bedtimesByWeekday.map(
          (k, v) => MapEntry(k.toString(), '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}'),
        ),
        'reminderOffsetMinutes': reminderOffsetMinutes,
        'titleTemplate': titleTemplate,
        'bodyTemplate': bodyTemplate,
      };

  static SleepWindDownPayload fromJson(Map<String, dynamic> json) {
    final raw = json['bedtimesByWeekday'] as Map<String, dynamic>? ?? {};
    final bedtimes = <int, TimeOfDay>{};
    for (final e in raw.entries) {
      final k = int.tryParse(e.key.toString());
      if (k == null || k < 1 || k > 7) continue;
      final parts = (e.value as String?).toString().split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          bedtimes[k] = TimeOfDay(hour: h, minute: m);
        }
      }
    }
    return SleepWindDownPayload(
      enabled: json['enabled'] as bool? ?? false,
      bedtimesByWeekday: bedtimes,
      reminderOffsetMinutes: json['reminderOffsetMinutes'] as int? ?? 30,
      titleTemplate: json['titleTemplate'] as String? ?? 'Wind Down',
      bodyTemplate: json['bodyTemplate'] as String? ?? 'Time to prepare for sleep.',
    );
  }
}
