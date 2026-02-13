import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wind_down_schedule.dart';

/// Persists wind-down schedule (bedtime per day + reminder offset).
class WindDownScheduleService {
  static const String _enabledKey = 'sleep_winddown_enabled';
  static const String _offsetMinutesKey = 'sleep_winddown_offset_minutes';
  static const String _dayPrefix = 'sleep_winddown_day_';

  static const List<int> _defaultOffsetMinutes = [15, 30, 45, 60, 90, 120];

  /// Preset reminder offsets in minutes (15, 30, 45, 60, 90, 120).
  static List<int> get reminderOffsetPresets => List.unmodifiable(_defaultOffsetMinutes);

  /// Min/max custom offset in minutes (5 min to 4 hours).
  static const int minCustomOffsetMinutes = 5;
  static const int maxCustomOffsetMinutes = 240;

  /// Whether [minutes] is one of the presets.
  static bool isPreset(int minutes) => _defaultOffsetMinutes.contains(minutes);

  Future<bool> getEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<int> getReminderOffsetMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_offsetMinutesKey) ?? 30;
  }

  Future<void> setReminderOffsetMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_offsetMinutesKey, minutes);
  }

  /// Get bedtime for weekday (1=Monday .. 7=Sunday). Returns null if not set.
  Future<TimeOfDay?> getBedtimeForWeekday(int weekday) async {
    if (weekday < 1 || weekday > 7) return null;
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('$_dayPrefix$weekday');
    if (s == null || s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Set bedtime for weekday (1=Monday .. 7=Sunday).
  Future<void> setBedtimeForWeekday(int weekday, TimeOfDay? time) async {
    if (weekday < 1 || weekday > 7) return;
    final prefs = await SharedPreferences.getInstance();
    if (time == null) {
      await prefs.remove('$_dayPrefix$weekday');
    } else {
      await prefs.setString(
        '$_dayPrefix$weekday',
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  /// Load full schedule (all 7 days).
  Future<Map<int, TimeOfDay?>> getFullSchedule() async {
    final result = <int, TimeOfDay?>{};
    for (int w = 1; w <= 7; w++) {
      result[w] = await getBedtimeForWeekday(w);
    }
    return result;
  }

  /// Save full schedule.
  Future<void> saveFullSchedule(Map<int, TimeOfDay?> schedule) async {
    final prefs = await SharedPreferences.getInstance();
    for (int w = 1; w <= 7; w++) {
      final t = schedule[w];
      if (t == null) {
        await prefs.remove('$_dayPrefix$w');
      } else {
        await prefs.setString(
          '$_dayPrefix$w',
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
        );
      }
    }
  }

  /// Build payload for Notification Hub.
  Future<SleepWindDownPayload> buildPayload() async {
    final enabled = await getEnabled();
    final offset = await getReminderOffsetMinutes();
    final schedule = await getFullSchedule();
    final bedtimes = <int, TimeOfDay>{};
    for (final e in schedule.entries) {
      if (e.value != null) bedtimes[e.key] = e.value!;
    }
    return SleepWindDownPayload(
      enabled: enabled,
      bedtimesByWeekday: bedtimes,
      reminderOffsetMinutes: offset,
      titleTemplate: 'Wind Down',
      bodyTemplate: 'Time to prepare for sleep. About $offset min until bedtime.',
    );
  }
}
