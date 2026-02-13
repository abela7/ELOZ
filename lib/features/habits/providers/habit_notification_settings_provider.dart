import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/android_system_status.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/color_schemes.dart';
import '../data/models/habit_notification_settings.dart';
import '../services/habit_reminder_service.dart';

final habitNotificationSettingsProvider = StateNotifierProvider<
    HabitNotificationSettingsNotifier, HabitNotificationSettings>((ref) {
  return HabitNotificationSettingsNotifier();
});

class HabitNotificationSettingsNotifier extends StateNotifier<HabitNotificationSettings> {
  HabitNotificationSettingsNotifier() : super(HabitNotificationSettings.defaults) {
    _loadSettings();
  }

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(habitNotificationSettingsKey);
    if (jsonString != null) {
      state = HabitNotificationSettings.fromJsonString(jsonString);
    }
    await refreshPermissionStates();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(habitNotificationSettingsKey, state.toJsonString());
    // Invalidate the cached copy in HabitReminderService so the next
    // scheduling run picks up the fresh values immediately.
    HabitReminderService().invalidateSettingsCache();
    try {
      await NotificationService().reloadSettings();
    } catch (_) {
      // Ignore, will reload on next use.
    }
  }

  Future<void> refreshPermissionStates() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    bool hasNotificationPermission = false;
    bool hasExactAlarmPermission = false;
    bool hasFullScreenIntentPermission = false;
    bool hasOverlayPermission = false;
    bool hasBatteryOptimizationExemption = false;

    if (Platform.isAndroid) {
      try {
        final notificationStatus = await Permission.notification.status;
        hasNotificationPermission = notificationStatus.isGranted;
      } catch (e) {
        print('⚠️ HabitNotificationSettingsProvider: Error checking notification permission: $e');
      }

      try {
        final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
        hasExactAlarmPermission = exactAlarmStatus.isGranted;
      } catch (e) {
        print('⚠️ HabitNotificationSettingsProvider: Error checking exact alarm permission: $e');
        hasExactAlarmPermission = true;
      }

      try {
        final overlayStatus = await Permission.systemAlertWindow.status;
        hasOverlayPermission = overlayStatus.isGranted;
      } catch (e) {
        print('⚠️ HabitNotificationSettingsProvider: Error checking overlay permission: $e');
      }

      try {
        final battery = await AndroidSystemStatus.getBatteryStatus();
        final isBackgroundRestricted = battery['isBackgroundRestricted'] as bool? ?? false;
        final isIgnoringBatteryOptimizations =
            battery['isIgnoringBatteryOptimizations'] as bool? ?? false;
        hasBatteryOptimizationExemption =
            isIgnoringBatteryOptimizations && !isBackgroundRestricted;
      } catch (e) {
        print('⚠️ HabitNotificationSettingsProvider: Error checking battery status: $e');
      }

      try {
        hasFullScreenIntentPermission = await AndroidSystemStatus.canUseFullScreenIntent();
      } catch (e) {
        print('⚠️ HabitNotificationSettingsProvider: Error checking full screen intent: $e');
        hasFullScreenIntentPermission = true;
      }
    } else if (Platform.isIOS) {
      try {
        final notificationStatus = await Permission.notification.status;
        hasNotificationPermission = notificationStatus.isGranted;
      } catch (e) {
        print('⚠️ HabitNotificationSettingsProvider: Error checking iOS notification permission: $e');
      }
      hasExactAlarmPermission = true;
      hasFullScreenIntentPermission = true;
      hasOverlayPermission = true;
      hasBatteryOptimizationExemption = true;
    }

    state = state.copyWith(
      hasNotificationPermission: hasNotificationPermission,
      hasExactAlarmPermission: hasExactAlarmPermission,
      hasFullScreenIntentPermission: hasFullScreenIntentPermission,
      hasOverlayPermission: hasOverlayPermission,
      hasBatteryOptimizationExemption: hasBatteryOptimizationExemption,
    );
  }

  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.notification.request();
      await refreshPermissionStates();
      return status.isGranted;
    }
    return false;
  }

  Future<bool> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestExactAlarmsPermission();
        await refreshPermissionStates();
        return granted ?? false;
      }
    }
    return true;
  }

  Future<bool> requestBatteryOptimizationExemption() async {
    if (Platform.isAndroid) {
      try {
        await AndroidSystemStatus.openAppDetailsSettings();
        try {
          await Permission.ignoreBatteryOptimizations.request();
        } catch (_) {}
        await refreshPermissionStates();
        return state.hasBatteryOptimizationExemption;
      } catch (e) {
        print('⚠️ HabitNotificationSettingsProvider: Error requesting battery optimization: $e');
        await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
        await refreshPermissionStates();
        return false;
      }
    }
    return true;
  }

  Future<void> openNotificationSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } catch (e) {
      print('⚠️ HabitNotificationSettingsProvider: Error opening notification settings: $e');
      await AppSettings.openAppSettings();
    }
  }

  Future<void> openAppSettings() async {
    try {
      await AppSettings.openAppSettings();
    } catch (e) {
      print('⚠️ HabitNotificationSettingsProvider: Error opening app settings: $e');
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
    } catch (e) {
      print('⚠️ HabitNotificationSettingsProvider: Error opening battery settings: $e');
      await AppSettings.openAppSettings();
    }
  }

  Future<void> openFullScreenIntentSettings() async {
    if (Platform.isAndroid) {
      await AndroidSystemStatus.openFullScreenIntentSettings();
    } else {
      await openNotificationSettings();
    }
  }

  Future<void> openChannelSettings(String channelId) async {
    if (Platform.isAndroid) {
      final resolved = await NotificationService().resolveAndroidChannelId(channelId);
      await AndroidSystemStatus.openChannelSettings(resolved);
    } else {
      await openNotificationSettings();
    }
  }

  Future<void> previewSound(String soundKey) async {
    await NotificationService().previewSound(soundKey);
  }

  Future<void> previewVibration(String patternKey) async {
    await NotificationService().previewVibration(patternKey);
  }

  Future<void> pickDefaultSoundFromSystem() async {
    if (!Platform.isAndroid) return;

    final lower = state.defaultSound.toLowerCase();
    final currentUri = lower.startsWith('content://') ? state.defaultSound : null;

    final picked = await AndroidSystemStatus.pickNotificationSound(
      currentUri: currentUri,
    );
    final uri = picked['uri'] as String?;
    if (uri == null || uri.isEmpty) return;

    state = state.copyWith(defaultSound: uri);
    await _saveSettings();
  }

  Future<void> pickSpecialHabitSoundFromSystem() async {
    if (!Platform.isAndroid) return;

    final currentUri = state.specialHabitSound.startsWith('content://')
        ? state.specialHabitSound
        : null;

    final picked = await AndroidSystemStatus.pickNotificationSound(
      currentUri: currentUri,
    );
    final uri = picked['uri'] as String?;
    if (uri == null || uri.isEmpty) return;

    state = state.copyWith(specialHabitSound: uri);
    await _saveSettings();
  }

  Future<void> resetToDefaults() async {
    state = HabitNotificationSettings.defaults;
    await _saveSettings();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    state = state.copyWith(soundEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    state = state.copyWith(vibrationEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setLedEnabled(bool enabled) async {
    state = state.copyWith(ledEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setHabitRemindersEnabled(bool enabled) async {
    state = state.copyWith(habitRemindersEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setUrgentRemindersEnabled(bool enabled) async {
    state = state.copyWith(urgentRemindersEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setSilentRemindersEnabled(bool enabled) async {
    state = state.copyWith(silentRemindersEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setDefaultUrgency(String urgency) async {
    state = state.copyWith(defaultUrgency: urgency);
    await _saveSettings();
  }

  Future<void> setDefaultSound(String sound) async {
    state = state.copyWith(defaultSound: sound);
    await _saveSettings();
  }

  Future<void> setHabitRemindersSound(String sound) async {
    state = state.copyWith(habitRemindersSound: sound);
    await _saveSettings();
  }

  Future<void> setUrgentRemindersSound(String sound) async {
    state = state.copyWith(urgentRemindersSound: sound);
    await _saveSettings();
  }

  Future<void> setDefaultVibrationPattern(String pattern) async {
    state = state.copyWith(defaultVibrationPattern: pattern);
    await _saveSettings();
  }

  Future<void> setDefaultChannel(String channel) async {
    state = state.copyWith(defaultChannel: channel);
    await _saveSettings();
  }

  Future<void> setNotificationAudioStream(String stream) async {
    state = state.copyWith(notificationAudioStream: stream);
    await _saveSettings();
  }

  Future<void> setAlwaysUseAlarmForSpecialHabits(bool enabled) async {
    state = state.copyWith(alwaysUseAlarmForSpecialHabits: enabled);
    await _saveSettings();
  }

  Future<void> setSpecialHabitSound(String sound) async {
    state = state.copyWith(specialHabitSound: sound);
    await _saveSettings();
  }

  Future<void> setSpecialHabitVibrationPattern(String pattern) async {
    state = state.copyWith(specialHabitVibrationPattern: pattern);
    await _saveSettings();
  }

  Future<void> setSpecialHabitAlarmMode(bool enabled) async {
    state = state.copyWith(specialHabitAlarmMode: enabled);
    await _saveSettings();
  }

  Future<void> setAllowSpecialDuringQuietHours(bool enabled) async {
    state = state.copyWith(allowSpecialDuringQuietHours: enabled);
    await _saveSettings();
  }

  Future<void> setQuietHoursEnabled(bool enabled) async {
    state = state.copyWith(quietHoursEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setQuietHoursStart(int minutes) async {
    state = state.copyWith(quietHoursStart: minutes);
    await _saveSettings();
  }

  Future<void> setQuietHoursEnd(int minutes) async {
    state = state.copyWith(quietHoursEnd: minutes);
    await _saveSettings();
  }

  Future<void> setQuietHoursDays(List<int> days) async {
    state = state.copyWith(quietHoursDays: days);
    await _saveSettings();
  }

  Future<void> setShowOnLockScreen(bool enabled) async {
    state = state.copyWith(showOnLockScreen: enabled);
    await _saveSettings();
  }

  Future<void> setWakeScreen(bool enabled) async {
    state = state.copyWith(wakeScreen: enabled);
    await _saveSettings();
  }

  Future<void> setPersistentNotifications(bool enabled) async {
    state = state.copyWith(persistentNotifications: enabled);
    await _saveSettings();
  }

  Future<void> setGroupNotifications(bool enabled) async {
    state = state.copyWith(groupNotifications: enabled);
    await _saveSettings();
  }

  Future<void> setNotificationTimeout(int seconds) async {
    state = state.copyWith(notificationTimeout: seconds);
    await _saveSettings();
  }

  Future<void> setHabitTitleTemplate(String template) async {
    state = state.copyWith(habitTitleTemplate: template);
    await _saveSettings();
  }

  Future<void> setHabitBodyTemplate(String template) async {
    state = state.copyWith(habitBodyTemplate: template);
    await _saveSettings();
  }

  Future<void> setSpecialHabitTitleTemplate(String template) async {
    state = state.copyWith(specialHabitTitleTemplate: template);
    await _saveSettings();
  }

  Future<void> setSpecialHabitBodyTemplate(String template) async {
    state = state.copyWith(specialHabitBodyTemplate: template);
    await _saveSettings();
  }

  Future<void> setDefaultHabitReminderTime(String reminderTime) async {
    state = state.copyWith(defaultHabitReminderTime: reminderTime);
    await _saveSettings();
  }

  Future<void> setDefaultSnoozeDuration(int minutes) async {
    state = state.copyWith(defaultSnoozeDuration: minutes);
    await _saveSettings();
  }

  Future<void> setSnoozeOptions(List<int> options) async {
    if (options.isEmpty) return;
    state = state.copyWith(snoozeOptions: options);
    await _saveSettings();
  }

  Future<void> setMaxSnoozeCount(int count) async {
    state = state.copyWith(maxSnoozeCount: count);
    await _saveSettings();
  }

  Future<void> setSmartSnooze(bool enabled) async {
    state = state.copyWith(smartSnooze: enabled);
    await _saveSettings();
  }

  Future<void> setEarlyMorningReminderEnabled(bool enabled) async {
    state = state.copyWith(earlyMorningReminderEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setEarlyMorningReminderHour(int hour) async {
    state = state.copyWith(earlyMorningReminderHour: hour);
    await _saveSettings();
  }

  Future<void> setRollingWindowDays(int days) async {
    final safeDays = days < 1 ? HabitNotificationSettings.defaults.rollingWindowDays : days;
    state = state.copyWith(rollingWindowDays: safeDays);
    await _saveSettings();
  }

  // === Permission status helpers ===

  bool get hasAllCriticalPermissions =>
      state.hasNotificationPermission && state.hasExactAlarmPermission;

  bool get hasAllOptionalPermissions =>
      state.hasFullScreenIntentPermission &&
      state.hasOverlayPermission &&
      state.hasBatteryOptimizationExemption;

  bool get hasAllTrackedPermissions => hasAllCriticalPermissions && hasAllOptionalPermissions;

  String get permissionStatusSummary {
    if (hasAllTrackedPermissions) {
      return 'All permissions granted';
    } else if (hasAllCriticalPermissions) {
      return 'Core permissions granted';
    } else if (!state.hasNotificationPermission) {
      return 'Notifications disabled';
    } else {
      return 'Some permissions missing';
    }
  }

  Color get permissionStatusColor {
    if (hasAllTrackedPermissions) {
      return AppColorSchemes.success;
    } else if (hasAllCriticalPermissions) {
      return AppColorSchemes.primaryGold;
    } else {
      return AppColorSchemes.error;
    }
  }

  int get missingPermissionCount {
    int count = 0;
    if (!state.hasNotificationPermission) count++;
    if (!state.hasExactAlarmPermission) count++;
    if (!state.hasFullScreenIntentPermission) count++;
    if (!state.hasOverlayPermission) count++;
    if (!state.hasBatteryOptimizationExemption) count++;
    return count;
  }

  int get grantedPermissionCount {
    int count = 0;
    if (state.hasNotificationPermission) count++;
    if (state.hasExactAlarmPermission) count++;
    if (state.hasFullScreenIntentPermission) count++;
    if (state.hasOverlayPermission) count++;
    if (state.hasBatteryOptimizationExemption) count++;
    return count;
  }

  int get totalPermissionCount => Platform.isAndroid ? 5 : 1;
}
