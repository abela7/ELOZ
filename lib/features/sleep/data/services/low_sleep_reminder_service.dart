import 'package:shared_preferences/shared_preferences.dart';

import '../../notifications/sleep_notification_contract.dart';

/// Manages low-sleep reminder settings.
///
/// Scheduling is done by [UniversalNotificationScheduler] (sync-driven,
/// like wind-down). This service only persists user preferences and
/// last-scheduled sleep hours for variable resolution.
class LowSleepReminderService {
  static const String _enabledKey = 'sleep_lowsleep_reminder_enabled';
  static const String _thresholdHoursKey = 'sleep_lowsleep_threshold_hours';
  static const String _hoursAfterWakeKey = 'sleep_lowsleep_hours_after_wake';
  static const String _lastScheduledHoursKey = 'sleep_lowsleep_last_scheduled_hours';

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

  /// Last sleep hours when a low-sleep reminder was scheduled.
  /// Used by the adapter for {sleepHours} variable resolution.
  Future<void> setLastScheduledSleepHours(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lastScheduledHoursKey, hours);
  }

  /// Get last scheduled sleep hours (for variable resolution).
  Future<String> getLastScheduledSleepHoursFormatted() async {
    final prefs = await SharedPreferences.getInstance();
    final h = prefs.getDouble(_lastScheduledHoursKey);
    return h != null ? h.toStringAsFixed(1) : '0';
  }
}
