import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import '../models/notification_settings.dart';
import '../services/notification_service.dart';
import '../services/android_system_status.dart';

/// Key for storing notification settings in SharedPreferences
const String _notificationSettingsKey = 'notification_settings';

/// Provider for notification settings
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier();
});

/// State notifier for notification settings
class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(NotificationSettings.defaults) {
    _loadSettings();
  }

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_notificationSettingsKey);
    
    if (jsonString != null) {
      state = NotificationSettings.fromJsonString(jsonString);
    }

    // Migration (best-effort):
    // Older builds defaulted urgent channel sound to "alarm", which surprised users when they
    // selected the alarm/urgent channel expecting their chosen tone. If the user has chosen a
    // custom tone (URI) for default notifications, prefer using that for urgent too unless they
    // explicitly changed it later.
    //
    // We only auto-migrate when:
    // - urgentRemindersSound is the legacy default "alarm"
    // - taskRemindersSound is still "default"
    // - defaultSound is a custom URI (meaning user explicitly chose a tone)
    if (Platform.isAndroid) {
      final ds = state.defaultSound.toLowerCase();
      final isCustomTone = ds.startsWith('content://') || ds.startsWith('file://');
      if (state.urgentRemindersSound == 'alarm' &&
          state.taskRemindersSound == 'default' &&
          isCustomTone) {
        state = state.copyWith(urgentRemindersSound: 'default');
        await _saveSettings();
      }
    }
    
    // Update permission states
    await refreshPermissionStates();
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationSettingsKey, state.toJsonString());
    
    // Notify the NotificationService to reload settings
    try {
      await NotificationService().reloadSettings();
    } catch (e) {
      // Ignore - service will reload on next use
    }
  }

  /// Refresh permission states from system
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
        // Check notification permission
        final notificationStatus = await Permission.notification.status;
        hasNotificationPermission = notificationStatus.isGranted;
      } catch (e) {
        print('⚠️ Error checking notification permission: $e');
      }

      try {
        // Check exact alarm permission (Android 12+)
        final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
        hasExactAlarmPermission = exactAlarmStatus.isGranted;
      } catch (e) {
        print('⚠️ Error checking exact alarm permission: $e');
        // On older Android versions, this is always allowed
        hasExactAlarmPermission = true;
      }

      try {
        // Check system alert window (overlay) permission
        final overlayStatus = await Permission.systemAlertWindow.status;
        hasOverlayPermission = overlayStatus.isGranted;
      } catch (e) {
        print('⚠️ Error checking overlay permission: $e');
      }

      try {
        // Battery restrictions (Android P+) + Doze whitelist (Android M+)
        //
        // IMPORTANT: "Unrestricted battery usage" in system UI often maps to
        // background restriction state, not (only) doze optimization whitelist.
        final battery = await AndroidSystemStatus.getBatteryStatus();
        final isBackgroundRestricted = battery['isBackgroundRestricted'] as bool? ?? false;
        final isIgnoringBatteryOptimizations =
            battery['isIgnoringBatteryOptimizations'] as bool? ?? false;

        // Treat "Unrestricted" as an explicit exemption signal.
        // On most devices, "Optimized" still reports NOT background restricted,
        // so we require Doze whitelist to avoid false positives.
        hasBatteryOptimizationExemption =
            isIgnoringBatteryOptimizations && !isBackgroundRestricted;
      } catch (e) {
        print('⚠️ Error checking battery optimization permission: $e');
      }

      // For full screen intent (Android 14+), we need to check via native code
      try {
        // On Android 14+, canUseFullScreenIntent() returns the actual permission state.
        // On older Android, it always returns true.
        hasFullScreenIntentPermission = await AndroidSystemStatus.canUseFullScreenIntent();
      } catch (e) {
        print('⚠️ Error checking full screen intent permission: $e');
        // Assume granted if check fails (older Android or method not available)
        hasFullScreenIntentPermission = true;
      }
    } else if (Platform.isIOS) {
      try {
        final notificationStatus = await Permission.notification.status;
        hasNotificationPermission = notificationStatus.isGranted;
      } catch (e) {
        print('⚠️ Error checking iOS notification permission: $e');
      }
      // iOS doesn't have separate permissions for these
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

  /// Request notification permission.
  ///
  /// When permission is already denied or permanentlyDenied, request() does not
  /// show a dialog. In that case we open notification settings so the user can
  /// enable notifications manually. Same applies on Android < 13 where there
  /// is no runtime permission dialog.
  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        await openNotificationSettings();
        await refreshPermissionStates();
        return state.hasNotificationPermission;
      }
      status = await Permission.notification.request();
      await refreshPermissionStates();
      if (!status.isGranted) {
        await openNotificationSettings();
        await refreshPermissionStates();
      }
      return state.hasNotificationPermission;
    } else if (Platform.isIOS) {
      var status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        await openNotificationSettings();
        await refreshPermissionStates();
        return state.hasNotificationPermission;
      }
      status = await Permission.notification.request();
      await refreshPermissionStates();
      if (!status.isGranted) {
        try {
          await openAppSettings();
        } catch (_) {}
        await refreshPermissionStates();
      }
      return state.hasNotificationPermission;
    }
    return false;
  }

  /// Request exact alarm permission (Android 12+)
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

  /// Request battery optimization exemption
  /// This opens the system settings for the user to grant the exemption
  Future<bool> requestBatteryOptimizationExemption() async {
    if (Platform.isAndroid) {
      try {
        // Open app details so user can set Battery to Unrestricted/Optimized.
        // This is the most reliable entrypoint across OEMs.
        await AndroidSystemStatus.openAppDetailsSettings();

        // Also attempt to request doze whitelist (may show a dialog on some devices).
        // If it doesn't, user can still set battery to Unrestricted in app details.
        try {
          await Permission.ignoreBatteryOptimizations.request();
        } catch (_) {
          // ignore
        }

        await refreshPermissionStates();
        return state.hasBatteryOptimizationExemption;
      } catch (e) {
        print('⚠️ NotificationSettingsProvider: Error requesting battery optimization: $e');
        // Fallback: open battery settings directly
        await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
        await refreshPermissionStates();
        return false;
      }
    }
    return true;
  }

  /// Open system notification settings (app's notification toggle and channels).
  /// Uses native ACTION_APP_NOTIFICATION_SETTINGS on Android for reliability.
  Future<void> openNotificationSettings() async {
    if (Platform.isAndroid) {
      await AndroidSystemStatus.openNotificationSettings();
    } else {
      try {
        await AppSettings.openAppSettings(type: AppSettingsType.notification);
      } catch (e) {
        print('⚠️ NotificationSettingsProvider: Error opening notification settings: $e');
        await AppSettings.openAppSettings();
      }
    }
  }

  /// Open app settings (for permissions)
  Future<void> openAppSettings() async {
    try {
      await AppSettings.openAppSettings();
    } catch (e) {
      print('⚠️ NotificationSettingsProvider: Error opening app settings: $e');
    }
  }

  /// Open battery optimization settings
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
    } catch (e) {
      print('⚠️ NotificationSettingsProvider: Error opening battery settings: $e');
      await AppSettings.openAppSettings();
    }
  }

  /// Open full-screen intent settings (Android 14+)
  /// This is required for alarm-style lock screen overlays
  Future<void> openFullScreenIntentSettings() async {
    if (Platform.isAndroid) {
      await AndroidSystemStatus.openFullScreenIntentSettings();
    } else {
      await openNotificationSettings();
    }
  }

  /// Open channel settings for specific channel
  Future<void> openChannelSettings(String channelId) async {
    if (Platform.isAndroid) {
      // Map logical channel keys to actual Android channel IDs (task_reminders is versioned).
      final resolved = await NotificationService().resolveAndroidChannelId(channelId);
      await AndroidSystemStatus.openChannelSettings(resolved);
    } else {
      await openNotificationSettings();
    }
  }

  /// Preview a sound
  Future<void> previewSound(String soundKey) async {
    await NotificationService().previewSound(soundKey);
  }

  /// Preview a vibration pattern
  Future<void> previewVibration(String patternKey) async {
    await NotificationService().previewVibration(patternKey);
  }

  /// Pick a notification sound from the native Android system picker and
  /// apply it to the app by storing the returned URI and recreating channels.
  Future<void> pickDefaultSoundFromSystem() async {
    if (!Platform.isAndroid) return;

    final lower = state.defaultSound.toLowerCase();
    final currentUri = lower.startsWith('content://')
        ? state.defaultSound
        : null;

    final picked = await AndroidSystemStatus.pickNotificationSound(
      currentUri: currentUri,
    );
    final uri = picked['uri'] as String?;

    if (uri == null || uri.isEmpty) {
      return; // user cancelled
    }

    state = state.copyWith(defaultSound: uri);
    await _saveSettings();
  }

  /// Pick a special task notification sound from the native Android system picker.
  Future<void> pickSpecialTaskSoundFromSystem() async {
    if (!Platform.isAndroid) return;

    final currentUri = state.specialTaskSound.startsWith('content://')
        ? state.specialTaskSound
        : null;

    final picked = await AndroidSystemStatus.pickNotificationSound(
      currentUri: currentUri,
    );
    final uri = picked['uri'] as String?;

    if (uri == null || uri.isEmpty) {
      return; // user cancelled
    }

    state = state.copyWith(specialTaskSound: uri);
    await _saveSettings();
  }

  // === Global Setting Update Methods ===

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

  // === Default Channel Settings ===

  Future<void> setDefaultChannel(String channel) async {
    state = state.copyWith(defaultChannel: channel);
    await _saveSettings();
  }

  Future<void> setDefaultSound(String sound) async {
    state = state.copyWith(defaultSound: sound);
    await _saveSettings();
  }

  Future<void> setDefaultVibrationPattern(String pattern) async {
    state = state.copyWith(defaultVibrationPattern: pattern);
    await _saveSettings();
  }

  // === Alarm Mode Settings ===

  Future<void> setAlarmModeEnabled(bool enabled) async {
    state = state.copyWith(alarmModeEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setAlarmModeForHighPriority(bool enabled) async {
    state = state.copyWith(alarmModeForHighPriority: enabled);
    await _saveSettings();
  }

  Future<void> setBypassDoNotDisturb(bool enabled) async {
    state = state.copyWith(bypassDoNotDisturb: enabled);
    await _saveSettings();
  }

  // === Audio Channel Settings ===

  Future<void> setNotificationAudioStream(String stream) async {
    state = state.copyWith(notificationAudioStream: stream);
    await _saveSettings();
  }

  // === Special Task Settings ===

  Future<void> setAlwaysUseAlarmForSpecialTasks(bool enabled) async {
    state = state.copyWith(alwaysUseAlarmForSpecialTasks: enabled);
    await _saveSettings();
  }

  Future<void> setSpecialTaskSound(String sound) async {
    state = state.copyWith(specialTaskSound: sound);
    await _saveSettings();
  }

  Future<void> setSpecialTaskVibrationPattern(String patternId) async {
    state = state.copyWith(specialTaskVibrationPattern: patternId);
    await _saveSettings();
  }

  Future<void> setSpecialTaskAlarmMode(bool enabled) async {
    state = state.copyWith(specialTaskAlarmMode: enabled);
    await _saveSettings();
  }

  // === Channel-Specific Settings ===

  Future<void> setTaskRemindersEnabled(bool enabled) async {
    state = state.copyWith(taskRemindersEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setTaskRemindersSound(String sound) async {
    state = state.copyWith(taskRemindersSound: sound);
    await _saveSettings();
  }

  Future<void> setUrgentRemindersEnabled(bool enabled) async {
    state = state.copyWith(urgentRemindersEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setUrgentRemindersSound(String sound) async {
    state = state.copyWith(urgentRemindersSound: sound);
    await _saveSettings();
  }

  Future<void> setSilentRemindersEnabled(bool enabled) async {
    state = state.copyWith(silentRemindersEnabled: enabled);
    await _saveSettings();
  }

  // === Task-Specific Defaults ===

  Future<void> setDefaultTaskReminderTime(String reminderTime) async {
    state = state.copyWith(defaultTaskReminderTime: reminderTime);
    await _saveSettings();
  }

  Future<void> setAutoReminderForHighPriority(bool enabled) async {
    state = state.copyWith(autoReminderForHighPriority: enabled);
    await _saveSettings();
  }

  Future<void> setAutoReminderForDueToday(bool enabled) async {
    state = state.copyWith(autoReminderForDueToday: enabled);
    await _saveSettings();
  }

  Future<void> setEarlyMorningReminderHour(int hour) async {
    state = state.copyWith(earlyMorningReminderHour: hour);
    await _saveSettings();
  }

  // === Priority Channel Settings ===

  Future<void> setUseCriticalChannelForHighPriority(bool enabled) async {
    state = state.copyWith(useCriticalChannelForHighPriority: enabled);
    await _saveSettings();
  }

  Future<void> setUseCriticalChannelForSpecial(bool enabled) async {
    state = state.copyWith(useCriticalChannelForSpecial: enabled);
    await _saveSettings();
  }

  // === Snooze Settings ===

  Future<void> setDefaultSnoozeDuration(int minutes) async {
    state = state.copyWith(defaultSnoozeDuration: minutes);
    await _saveSettings();
  }

  Future<void> setSnoozeOptions(List<int> options) async {
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

  // === Quiet Hours ===

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

  Future<void> setAllowUrgentDuringQuietHours(bool enabled) async {
    state = state.copyWith(allowUrgentDuringQuietHours: enabled);
    await _saveSettings();
  }

  Future<void> setQuietHoursDays(List<int> days) async {
    state = state.copyWith(quietHoursDays: days);
    await _saveSettings();
  }

  // === Advanced Notification Behavior ===

  Future<void> setGroupNotifications(bool enabled) async {
    state = state.copyWith(groupNotifications: enabled);
    await _saveSettings();
  }

  Future<void> setShowProgressInNotification(bool enabled) async {
    state = state.copyWith(showProgressInNotification: enabled);
    await _saveSettings();
  }

  Future<void> setShowCategoryInNotification(bool enabled) async {
    state = state.copyWith(showCategoryInNotification: enabled);
    await _saveSettings();
  }

  Future<void> setAutoExpandNotifications(bool enabled) async {
    state = state.copyWith(autoExpandNotifications: enabled);
    await _saveSettings();
  }

  Future<void> setTaskTitleTemplate(String template) async {
    state = state.copyWith(taskTitleTemplate: template);
    await _saveSettings();
  }

  Future<void> setTaskBodyTemplate(String template) async {
    state = state.copyWith(taskBodyTemplate: template);
    await _saveSettings();
  }

  Future<void> setSpecialTaskTitleTemplate(String template) async {
    state = state.copyWith(specialTaskTitleTemplate: template);
    await _saveSettings();
  }

  Future<void> setSpecialTaskBodyTemplate(String template) async {
    state = state.copyWith(specialTaskBodyTemplate: template);
    await _saveSettings();
  }

  Future<void> setNotificationTimeout(int seconds) async {
    state = state.copyWith(notificationTimeout: seconds);
    await _saveSettings();
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    // Preserve permission states
    final currentPermissions = state;
    state = NotificationSettings.defaults.copyWith(
      hasNotificationPermission: currentPermissions.hasNotificationPermission,
      hasExactAlarmPermission: currentPermissions.hasExactAlarmPermission,
      hasFullScreenIntentPermission: currentPermissions.hasFullScreenIntentPermission,
      hasOverlayPermission: currentPermissions.hasOverlayPermission,
      hasBatteryOptimizationExemption: currentPermissions.hasBatteryOptimizationExemption,
    );
    await _saveSettings();
  }

  /// Get the effective channel for a notification based on settings
  String getEffectiveChannel(String? priority, bool isUrgent) {
    if (!state.notificationsEnabled) {
      return 'silent_reminders';
    }

    // Check quiet hours
    if (state.isInQuietHours()) {
      if (isUrgent && state.allowUrgentDuringQuietHours) {
        return 'urgent_reminders';
      }
      return 'silent_reminders';
    }

    // Check if specific channels are enabled
    if (isUrgent || priority == 'High') {
      if (state.urgentRemindersEnabled) {
        return 'urgent_reminders';
      }
      // Fall back to task reminders if urgent is disabled
      if (state.taskRemindersEnabled) {
        return 'task_reminders';
      }
    }

    if (state.taskRemindersEnabled) {
      return state.defaultChannel;
    }

    return 'silent_reminders';
  }

  // === Permission Status Helpers ===

  /// Check if all critical permissions are granted
  bool get hasAllCriticalPermissions =>
      state.hasNotificationPermission && state.hasExactAlarmPermission;

  /// Check if all optional permissions are granted
  bool get hasAllOptionalPermissions =>
      state.hasFullScreenIntentPermission && 
      state.hasOverlayPermission &&
      state.hasBatteryOptimizationExemption;

  /// Check if ALL tracked permissions are granted (Android: 5/5).
  /// This is what the UI should use to hide the permissions section.
  bool get hasAllTrackedPermissions =>
      hasAllCriticalPermissions && hasAllOptionalPermissions;

  /// Get permission status summary
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

  /// Get permission status color
  Color get permissionStatusColor {
    if (hasAllTrackedPermissions) {
      return const Color(0xFF4CAF50); // Green
    } else if (hasAllCriticalPermissions) {
      return const Color(0xFFCDAF56); // Gold
    } else {
      return const Color(0xFFE53935); // Red
    }
  }

  /// Get count of missing permissions
  int get missingPermissionCount {
    int count = 0;
    if (!state.hasNotificationPermission) count++;
    if (!state.hasExactAlarmPermission) count++;
    if (!state.hasFullScreenIntentPermission) count++;
    if (!state.hasOverlayPermission) count++;
    if (!state.hasBatteryOptimizationExemption) count++;
    return count;
  }

  /// Get count of granted permissions
  int get grantedPermissionCount {
    int count = 0;
    if (state.hasNotificationPermission) count++;
    if (state.hasExactAlarmPermission) count++;
    if (state.hasFullScreenIntentPermission) count++;
    if (state.hasOverlayPermission) count++;
    if (state.hasBatteryOptimizationExemption) count++;
    return count;
  }

  /// Total permission count
  int get totalPermissionCount => Platform.isAndroid ? 5 : 1;
}
