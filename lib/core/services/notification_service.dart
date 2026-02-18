import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../models/reminder.dart';
import '../models/notification_settings.dart';
import '../models/pending_notification_info.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/models/task.dart';
import '../../data/models/subtask.dart';
import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import '../../features/habits/data/models/habit.dart';
import '../../features/habits/data/models/habit_notification_settings.dart';
import '../../features/habits/data/repositories/habit_repository.dart';
import 'notification_handler.dart';
import 'sound_player_service.dart';
import 'alarm_service.dart';
import 'icon_bitmap_generator.dart';
import '../notifications/models/notification_hub_modules.dart';
import '../notifications/models/notification_hub_schedule_request.dart';
import '../notifications/services/notification_activity_logger.dart';
import '../notifications/services/notification_flow_trace.dart';
import '../notifications/services/notification_logical_key_helper.dart';
import '../notifications/services/notification_module_policy.dart';

/// Professional notification service with modern features
///
/// Features:
/// - Scheduled notifications with timezone support
/// - Action buttons (Mark Done, Snooze, View)
/// - Custom sounds and vibration patterns
/// - Notification channels for Android
/// - Smart notification grouping
/// - Alarm mode for critical notifications
/// - Quiet hours support
/// - User-configurable settings integration
/// - Smart snooze based on priority
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _prefsTaskChannelIdKey = 'task_reminders_channel_id_v1';
  static const String _prefsHabitChannelIdKey = 'habit_reminders_channel_id_v1';
  static const String _prefsSpecialAlarmIdsPrefix = 'special_alarm_ids_v1_';
  static const String _prefsTrackedNativeAlarmsKey = 'tracked_native_alarms_v1';
  static const String _prefsTrackedFlutterNotificationsKey =
      'tracked_flutter_notifications_v1';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _timezoneDbInitialized = false;

  bool _initialized = false;
  Completer<void>? _initializeCompleter;
  static const String _prefsLastLaunchResponseSignatureKey =
      'last_launch_response_signature_v1';
  static const String _prefsLastLaunchResponseAtMsKey =
      'last_launch_response_at_ms_v1';
  static const Duration _launchResponseReplayWindow = Duration(minutes: 15);

  /// Cached notification settings (loaded from SharedPreferences)
  NotificationSettings _settings = NotificationSettings.defaults;
  HabitNotificationSettings _habitSettings = HabitNotificationSettings.defaults;

  Future<void> _trackSpecialAlarmId(String taskId, int alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsSpecialAlarmIdsPrefix$taskId';
      final raw = (prefs.getString(key) ?? '').trim();
      final List<dynamic> current = raw.isEmpty
          ? <dynamic>[]
          : (jsonDecode(raw) as List<dynamic>);
      final ids = current.map((e) => (e as num).toInt()).toSet();
      ids.add(alarmId);
      await prefs.setString(key, jsonEncode(ids.toList()..sort()));
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _trackNativeAlarmEntry(Map<String, dynamic> entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsTrackedNativeAlarmsKey) ?? '').trim();
      final List<dynamic> decoded = raw.isEmpty
          ? <dynamic>[]
          : (jsonDecode(raw) as List<dynamic>);
      final List<Map<String, dynamic>> entries = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final int id = (entry['id'] as num).toInt();
      // Remove any existing entry with same id
      entries.removeWhere((e) => (e['id'] as num?)?.toInt() == id);
      entries.add(entry);

      await prefs.setString(_prefsTrackedNativeAlarmsKey, jsonEncode(entries));
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService: Tracked native alarm entry (ID: $id, Total tracked: ${entries.length})',
      );
      print('   Title: ${entry['title']}');
      print('   Channel: ${entry['channelKey']}');
      print('   Audio Stream: ${entry['audioStream']}');
      print(
        '   Scheduled for: ${DateTime.fromMillisecondsSinceEpoch(entry['scheduledTimeMs'] as int)}',
      );
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Failed to track native alarm entry: $e',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getTrackedNativeAlarmEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsTrackedNativeAlarmsKey) ?? '').trim();
      if (raw.isEmpty) {
        print('NotificationService: No tracked native alarms found');
        return const <Map<String, dynamic>>[];
      }
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final entries = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      print(
        'NotificationService: Retrieved ${entries.length} tracked native alarm(s)',
      );
      for (final e in entries) {
        final schedMs = e['scheduledTimeMs'] as int?;
        final fireTime = schedMs != null
            ? DateTime.fromMillisecondsSinceEpoch(schedMs)
            : null;
        print('   - ID: ${e['id']}, Title: ${e['title']}, Fires: $fireTime');
      }
      return entries;
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Error loading tracked native alarms: $e',
      );
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> _getTrackedNativeAlarmEntry(int alarmId) async {
    try {
      final entries = await _getTrackedNativeAlarmEntries();
      return entries.firstWhere(
        (e) => (e['id'] as num?)?.toInt() == alarmId,
        orElse: () => <String, dynamic>{},
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeTrackedNativeAlarmEntry(int alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsTrackedNativeAlarmsKey) ?? '').trim();
      if (raw.isEmpty) return;
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<Map<String, dynamic>> entries = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      entries.removeWhere((e) => (e['id'] as num?)?.toInt() == alarmId);
      await prefs.setString(_prefsTrackedNativeAlarmsKey, jsonEncode(entries));
    } catch (_) {}
  }

  Future<void> _removeTrackedNativeAlarmEntriesForTask(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsTrackedNativeAlarmsKey) ?? '').trim();
      if (raw.isEmpty) return;
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<Map<String, dynamic>> entries = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      entries.removeWhere((e) => (e['entityId'] as String?) == taskId);
      await prefs.setString(_prefsTrackedNativeAlarmsKey, jsonEncode(entries));
    } catch (_) {}
  }

  Future<void> _cleanupTrackedNativeAlarmEntries() async {
    try {
      final entries = await _getTrackedNativeAlarmEntries();
      if (entries.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      // Remove entries that are already past due
      final filtered = entries.where((e) {
        final scheduledMs = (e['scheduledTimeMs'] as num?)?.toInt();
        if (scheduledMs == null) return true;
        return scheduledMs >= now;
      }).toList();

      if (filtered.length != entries.length) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _prefsTrackedNativeAlarmsKey,
          jsonEncode(filtered),
        );
      }
    } catch (_) {}
  }

  // ============================================================
  // FLUTTER NOTIFICATION TRACKING (for diagnostics)
  // ============================================================

  Future<void> _trackFlutterNotificationEntry(
    Map<String, dynamic> entry,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsTrackedFlutterNotificationsKey) ?? '')
          .trim();
      final List<dynamic> decoded = raw.isEmpty
          ? <dynamic>[]
          : (jsonDecode(raw) as List<dynamic>);
      final List<Map<String, dynamic>> entries = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final int id = (entry['id'] as num).toInt();
      entries.removeWhere((e) => (e['id'] as num?)?.toInt() == id);
      entries.add(entry);

      await prefs.setString(
        _prefsTrackedFlutterNotificationsKey,
        jsonEncode(entries),
      );
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService: Tracked Flutter notification entry (ID: $id, Total tracked: ${entries.length})',
      );
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Failed to track Flutter notification entry: $e',
      );
    }
  }

  Future<Map<String, dynamic>?> _getTrackedFlutterNotificationEntry(
    int notificationId,
  ) async {
    try {
      final entries = await _getTrackedFlutterNotificationEntries();
      return entries.firstWhere(
        (e) => (e['id'] as num?)?.toInt() == notificationId,
        orElse: () => <String, dynamic>{},
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>>
  _getTrackedFlutterNotificationEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsTrackedFlutterNotificationsKey) ?? '')
          .trim();
      if (raw.isEmpty) return const <Map<String, dynamic>>[];
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final entries = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      print(
        'NotificationService: Retrieved ${entries.length} tracked Flutter notification(s)',
      );
      return entries;
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Error loading tracked Flutter notifications: $e',
      );
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> _removeTrackedFlutterNotificationEntry(
    int notificationId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsTrackedFlutterNotificationsKey) ?? '')
          .trim();
      if (raw.isEmpty) return;
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<Map<String, dynamic>> entries = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      entries.removeWhere((e) => (e['id'] as num?)?.toInt() == notificationId);
      await prefs.setString(
        _prefsTrackedFlutterNotificationsKey,
        jsonEncode(entries),
      );
    } catch (_) {}
  }

  Future<void> _removeTrackedFlutterNotificationEntriesForTask(
    String taskId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsTrackedFlutterNotificationsKey) ?? '')
          .trim();
      if (raw.isEmpty) return;
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<Map<String, dynamic>> entries = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      entries.removeWhere((e) => (e['entityId'] as String?) == taskId);
      await prefs.setString(
        _prefsTrackedFlutterNotificationsKey,
        jsonEncode(entries),
      );
    } catch (_) {}
  }

  Future<void> _cleanupTrackedFlutterNotificationEntries() async {
    try {
      final entries = await _getTrackedFlutterNotificationEntries();
      if (entries.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final filtered = entries.where((e) {
        final scheduledMs = (e['scheduledTimeMs'] as num?)?.toInt();
        if (scheduledMs == null) return true;
        return scheduledMs >= now;
      }).toList();

      if (filtered.length != entries.length) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _prefsTrackedFlutterNotificationsKey,
          jsonEncode(filtered),
        );
        print(
          'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚Â§Ãƒâ€šÃ‚Â¹ NotificationService: Cleaned up ${entries.length - filtered.length} expired Flutter notification entries',
        );
      }
    } catch (_) {}
  }

  Future<List<int>> _getTrackedSpecialAlarmIds(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsSpecialAlarmIdsPrefix$taskId';
      final raw = (prefs.getString(key) ?? '').trim();
      if (raw.isEmpty) return const <int>[];
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return const <int>[];
    }
  }

  Future<void> _clearTrackedSpecialAlarmIds(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsSpecialAlarmIdsPrefix$taskId';
      await prefs.remove(key);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Android 8+ IMPORTANT:
  /// Channel sound is effectively immutable once the user/OS "locks" it.
  /// Some OEMs (and some states) will ignore deleting/recreating the same ID.
  /// To guarantee that the selected tone is applied, we version the *actual*
  /// Android channel ID based on the chosen sound + stream settings.
  String _taskRemindersChannelIdForSettings() {
    final taskSoundKey = _effectiveSoundKeyForTaskChannel();
    final stream = _settings.notificationAudioStream;
    // Bump signature version when channel audio behavior changes.
    final signature =
        'v2|$taskSoundKey|$stream|sound:${_settings.soundEnabled}|vib:${_settings.vibrationEnabled}|led:${_settings.ledEnabled}';
    final hash = signature.hashCode.abs() % 1000000000;
    return 'task_reminders_$hash';
  }

  NotificationSettings _notificationSettingsForHabits() {
    return NotificationSettings(
      notificationsEnabled: _habitSettings.notificationsEnabled,
      soundEnabled: _habitSettings.soundEnabled,
      vibrationEnabled: _habitSettings.vibrationEnabled,
      ledEnabled: _habitSettings.ledEnabled,
      taskRemindersEnabled: _habitSettings.habitRemindersEnabled,
      urgentRemindersEnabled: _habitSettings.urgentRemindersEnabled,
      silentRemindersEnabled: _habitSettings.silentRemindersEnabled,
      defaultSound: _habitSettings.defaultSound,
      taskRemindersSound: _habitSettings.habitRemindersSound,
      urgentRemindersSound: _habitSettings.urgentRemindersSound,
      defaultVibrationPattern: _habitSettings.defaultVibrationPattern,
      defaultChannel: _habitSettings.defaultChannel,
      notificationAudioStream: _habitSettings.notificationAudioStream,
      alwaysUseAlarmForSpecialTasks:
          _habitSettings.alwaysUseAlarmForSpecialHabits,
      specialTaskSound: _habitSettings.specialHabitSound,
      specialTaskVibrationPattern: _habitSettings.specialHabitVibrationPattern,
      specialTaskAlarmMode: _habitSettings.specialHabitAlarmMode,
      allowUrgentDuringQuietHours: _habitSettings.allowSpecialDuringQuietHours,
      quietHoursEnabled: _habitSettings.quietHoursEnabled,
      quietHoursStart: _habitSettings.quietHoursStart,
      quietHoursEnd: _habitSettings.quietHoursEnd,
      quietHoursDays: _habitSettings.quietHoursDays,
      showOnLockScreen: _habitSettings.showOnLockScreen,
      wakeScreen: _habitSettings.wakeScreen,
      persistentNotifications: _habitSettings.persistentNotifications,
      groupNotifications: _habitSettings.groupNotifications,
      notificationTimeout: _habitSettings.notificationTimeout,
      defaultSnoozeDuration: _habitSettings.defaultSnoozeDuration,
      snoozeOptions: _habitSettings.snoozeOptions,
      maxSnoozeCount: _habitSettings.maxSnoozeCount,
      smartSnooze: _habitSettings.smartSnooze,
    );
  }

  String _habitRemindersChannelIdForSettings() {
    final habitSettings = _notificationSettingsForHabits();
    final habitSoundKey = _effectiveSoundKeyForTaskChannel(habitSettings);
    final stream = habitSettings.notificationAudioStream;
    final signature =
        'v1|$habitSoundKey|$stream|sound:${habitSettings.soundEnabled}|vib:${habitSettings.vibrationEnabled}|led:${habitSettings.ledEnabled}';
    final hash = signature.hashCode.abs() % 1000000000;
    return 'habit_reminders_$hash';
  }

  String _resolveAndroidChannelId(String logicalChannelKey) {
    if (logicalChannelKey == 'task_reminders') {
      return _taskRemindersChannelIdForSettings();
    }
    if (logicalChannelKey == 'habit_reminders') {
      return _habitRemindersChannelIdForSettings();
    }
    return logicalChannelKey;
  }

  Future<String> resolveAndroidChannelId(String logicalChannelKey) async {
    if (!_initialized) {
      await initialize();
    } else {
      await _loadSettings();
      await _loadHabitSettings();
    }
    return _resolveAndroidChannelId(logicalChannelKey);
  }

  /// Initialize the notification service
  Future<void> initialize({bool startupOptimized = false}) async {
    if (_initialized) return;
    if (_initializeCompleter != null) {
      return _initializeCompleter!.future;
    }
    _initializeCompleter = Completer<void>();

    try {
      print('NotificationService: Starting initialization...');

      // Load user settings
      await _loadSettings();
      print(
        'NotificationService: Settings loaded - notificationsEnabled: ${_settings.notificationsEnabled}',
      );

      // Load habit notification settings
      await _loadHabitSettings();
      print(
        'NotificationService: Habit settings loaded - notificationsEnabled: ${_habitSettings.notificationsEnabled}',
      );

      // Configure timezone
      await _configureTimezone();

      // Android initialization
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // iOS initialization
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          NotificationHandler().handleNotificationResponse(response);
        },
      );

      print('NotificationService: Plugin initialized');

      // Check if app was launched from a notification.
      // Dedupe to avoid replay on hot restart / duplicate startup init paths.
      final launchDetails = await _notificationsPlugin
          .getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final response = launchDetails.notificationResponse;
        if (response != null &&
            await _shouldProcessLaunchNotificationResponse(response)) {
          NotificationHandler().handleNotificationResponse(response);
        }
      }

      // Request permissions. On app startup we don't block first interaction on this.
      if (startupOptimized) {
        unawaited(_requestPermissions());
        print('NotificationService: Permissions requested (background)');
      } else {
        await _requestPermissions();
        print('NotificationService: Permissions requested');
      }

      // Create notification channels for Android.
      // Avoid force recreation at every app launch because deleting/recreating
      // channels is expensive and can cause startup jank.
      await _createNotificationChannels(forceRecreate: false);
      print('NotificationService: Channels created');

      // SoundPlayerService initializes lazily on first playback request.

      _initialized = true;
      print('NotificationService: Initialization complete');
      _initializeCompleter?.complete();
    } catch (e, st) {
      _initializeCompleter?.completeError(e, st);
      rethrow;
    } finally {
      _initializeCompleter = null;
    }
  }

  Future<bool> _shouldProcessLaunchNotificationResponse(
    NotificationResponse response,
  ) async {
    try {
      final payload = response.payload ?? '';
      final actionId = response.actionId ?? '';
      final id = response.id ?? -1;
      final signature = 'id:$id|action:$actionId|payload:$payload';

      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastSig = prefs.getString(_prefsLastLaunchResponseSignatureKey);
      final lastAt = prefs.getInt(_prefsLastLaunchResponseAtMsKey) ?? 0;

      final isReplay =
          lastSig == signature &&
          (nowMs - lastAt) < _launchResponseReplayWindow.inMilliseconds;
      if (isReplay) {
        print(
          'NotificationService: Skipping duplicate launch notification response',
        );
        return false;
      }

      await prefs.setString(_prefsLastLaunchResponseSignatureKey, signature);
      await prefs.setInt(_prefsLastLaunchResponseAtMsKey, nowMs);
      return true;
    } catch (_) {
      // If persistence fails, do not block valid launch handling.
      return true;
    }
  }

  /// Load notification settings from SharedPreferences
  Future<void> _loadSettings() async {
    final previous = _settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('notification_settings');
      if (jsonString != null) {
        _settings = NotificationSettings.fromJsonString(jsonString);
      }
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Error loading settings: $e',
      );
      _settings = NotificationSettings.defaults;
    }

    // On Android 8+, channel sound/vibration are controlled by channels and
    // cannot be updated unless we recreate the channel. If the user changes
    // tone/vibration/LED toggles, we rebuild channels so changes apply instantly
    // to the next test notification and scheduled notifications.
    if (_initialized && _shouldRecreateAndroidChannels(previous, _settings)) {
      await _createNotificationChannels(forceRecreate: true);
    }
  }

  /// Public accessor that returns the current global [NotificationSettings].
  ///
  /// Reloads from SharedPreferences before returning so callers always get the
  /// most recent values.
  Future<NotificationSettings> loadCurrentSettings() async {
    await _loadSettings();
    return _settings;
  }

  Future<void> _loadHabitSettings() async {
    final previous = _habitSettings;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(habitNotificationSettingsKey);
      if (jsonString != null) {
        _habitSettings = HabitNotificationSettings.fromJsonString(jsonString);
      }
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Error loading habit settings: $e',
      );
      _habitSettings = HabitNotificationSettings.defaults;
    }

    if (_initialized &&
        _shouldRecreateHabitChannels(previous, _habitSettings)) {
      await _createNotificationChannels(forceRecreate: true);
    }
  }

  /// Reload settings (call this when settings change)
  Future<void> reloadSettings() async {
    await _loadSettings();
    await _loadHabitSettings();
  }

  /// Get the current settings
  NotificationSettings get settings => _settings;

  /// Configure timezone
  Future<void> _configureTimezone() async {
    try {
      if (!_timezoneDbInitialized) {
        tz_data.initializeTimeZones();
        _timezoneDbInitialized = true;
      }
      final String timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (e) {
      // Fallback to UTC if timezone detection fails
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  /// Request notification permissions
  ///
  /// Wrapped in try-catch: on Android the plugin may throw
  /// NullPointerException if context is null (e.g. during early init,
  /// hot reload, or when running from a headless engine).
  Future<void> _requestPermissions() async {
    try {
      // Android 13+ permissions
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      // Request full screen intent permission for Android 14+
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission();

      // iOS permissions
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } on PlatformException catch (e) {
      // Context may be null during early init or headless engine (WorkManager)
      if (kDebugMode) {
        debugPrint(
          'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â NotificationService: Permission request skipped (context unavailable): ${e.message}',
        );
      }
    }
  }

  /// Create notification channels for Android
  bool _shouldRecreateAndroidChannels(
    NotificationSettings before,
    NotificationSettings after,
  ) {
    return before.soundEnabled != after.soundEnabled ||
        before.vibrationEnabled != after.vibrationEnabled ||
        before.ledEnabled != after.ledEnabled ||
        before.defaultVibrationPattern != after.defaultVibrationPattern ||
        before.defaultSound != after.defaultSound ||
        before.taskRemindersSound != after.taskRemindersSound ||
        before.urgentRemindersSound != after.urgentRemindersSound ||
        before.notificationAudioStream != after.notificationAudioStream;
  }

  bool _shouldRecreateHabitChannels(
    HabitNotificationSettings before,
    HabitNotificationSettings after,
  ) {
    return before.soundEnabled != after.soundEnabled ||
        before.vibrationEnabled != after.vibrationEnabled ||
        before.ledEnabled != after.ledEnabled ||
        before.defaultVibrationPattern != after.defaultVibrationPattern ||
        before.defaultSound != after.defaultSound ||
        before.habitRemindersSound != after.habitRemindersSound ||
        before.urgentRemindersSound != after.urgentRemindersSound ||
        before.notificationAudioStream != after.notificationAudioStream;
  }

  AudioAttributesUsage _getAudioAttributesUsage(String stream) {
    switch (stream) {
      case 'alarm':
        return AudioAttributesUsage.alarm;
      case 'ring':
        return AudioAttributesUsage.notificationRingtone;
      case 'media':
        return AudioAttributesUsage.media;
      case 'notification':
      default:
        return AudioAttributesUsage.notification;
    }
  }

  String _effectiveSoundKeyForTaskChannel([
    NotificationSettings? settingsOverride,
  ]) {
    final settings = settingsOverride ?? _settings;
    final key = settings.taskRemindersSound == 'default'
        ? settings.defaultSound
        : settings.taskRemindersSound;
    if (!settings.soundEnabled) return 'silent';
    return key;
  }

  String _effectiveSoundKeyForUrgentChannel([
    NotificationSettings? settingsOverride,
  ]) {
    final settings = settingsOverride ?? _settings;
    final key = settings.urgentRemindersSound == 'default'
        ? settings.defaultSound
        : settings.urgentRemindersSound;
    if (!settings.soundEnabled) return 'silent';
    return key;
  }

  bool _isCustomSoundKey(String soundKey) {
    final lower = soundKey.toLowerCase();
    return lower.startsWith('content://') ||
        lower.startsWith('file://') ||
        lower.startsWith('android.resource://');
  }

  AndroidNotificationSound? _androidSoundForKey(String soundKey) {
    // We avoid bundling custom audio files. Instead we use stable system URIs.
    // NOTE: Some OEMs may still map these to the same tone; users can always
    // override per-channel in system settings if desired.
    final lower = soundKey.toLowerCase();
    if (lower.startsWith('content://') || lower.startsWith('file://')) {
      return UriAndroidNotificationSound(soundKey);
    }
    switch (soundKey) {
      case 'silent':
        return null;
      case 'alarm':
        return const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert',
        );
      case 'bell':
        return const UriAndroidNotificationSound(
          'content://settings/system/ringtone',
        );
      case 'gentle':
        return const UriAndroidNotificationSound(
          'content://settings/system/notification_sound',
        );
      case 'chime':
        return const UriAndroidNotificationSound(
          'content://settings/system/notification_sound',
        );
      case 'default':
      default:
        return const UriAndroidNotificationSound(
          'content://settings/system/notification_sound',
        );
    }
  }

  /// Create (or recreate) notification channels for Android.
  ///
  /// On Android 8+, sound/vibration are channel-level settings. If the user
  /// changes these in-app, we delete + recreate the channels so changes take
  /// effect immediately.
  Future<void> _createNotificationChannels({bool forceRecreate = false}) async {
    print(
      'NotificationService: Creating notification channels (forceRecreate: $forceRecreate)',
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return;

    // Resolve actual channel id for task reminders (versioned).
    final resolvedTaskChannelId = _taskRemindersChannelIdForSettings();
    final resolvedHabitChannelId = _habitRemindersChannelIdForSettings();

    // Delete old task channel id if it changed (prevents channel list bloat).
    try {
      final prefs = await SharedPreferences.getInstance();
      final previousTaskChannelId = prefs.getString(_prefsTaskChannelIdKey);
      if (previousTaskChannelId != null &&
          previousTaskChannelId != resolvedTaskChannelId) {
        try {
          await androidPlugin.deleteNotificationChannel(previousTaskChannelId);
          print(
            'NotificationService: Deleted old task channel: $previousTaskChannelId',
          );
        } catch (_) {}
      }
      await prefs.setString(_prefsTaskChannelIdKey, resolvedTaskChannelId);
    } catch (_) {
      // Best-effort; channel versioning still works even if we can't delete old.
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final previousHabitChannelId = prefs.getString(_prefsHabitChannelIdKey);
      if (previousHabitChannelId != null &&
          previousHabitChannelId != resolvedHabitChannelId) {
        try {
          await androidPlugin.deleteNotificationChannel(previousHabitChannelId);
          print(
            'NotificationService: Deleted old habit channel: $previousHabitChannelId',
          );
        } catch (_) {}
      }
      await prefs.setString(_prefsHabitChannelIdKey, resolvedHabitChannelId);
    } catch (_) {
      // Best-effort; channel versioning still works even if we can't delete old.
    }

    if (forceRecreate) {
      // Delete the current task channel id as well (best effort).
      final idsToDelete = <String>[
        resolvedTaskChannelId,
        resolvedHabitChannelId,
        'urgent_reminders',
        'silent_reminders',
        'habit_urgent_reminders',
        'habit_silent_reminders',
        'habit_reminders',
        // Legacy: older builds created a dedicated channel for special-task backups.
        'alarm_backups_v1',
        // Back-compat: older builds used fixed id.
        'task_reminders',
      ];
      for (final id in idsToDelete) {
        try {
          await androidPlugin.deleteNotificationChannel(id);
          print('NotificationService: Deleted channel: $id');
        } catch (_) {
          // Ignore if channel doesn't exist or cannot be deleted on this device.
        }
      }
    }

    // Effective channel-level toggles
    final taskSoundKey = _effectiveSoundKeyForTaskChannel();
    final urgentSoundKey = _effectiveSoundKeyForUrgentChannel();

    final taskPlaySound = _settings.soundEnabled && taskSoundKey != 'silent';
    final urgentPlaySound =
        _settings.soundEnabled && urgentSoundKey != 'silent';

    print('NotificationService: Channel Settings:');
    print('   - Sound Enabled: ${_settings.soundEnabled}');
    print('   - Vibration Enabled: ${_settings.vibrationEnabled}');
    print('   - LED Enabled: ${_settings.ledEnabled}');
    print('   - Task Sound Key: $taskSoundKey (play: $taskPlaySound)');
    print('   - Urgent Sound Key: $urgentSoundKey (play: $urgentPlaySound)');

    final taskVibrationPattern = _settings.vibrationEnabled
        ? _getVibrationPattern(_settings.defaultVibrationPattern)
        : Int64List.fromList([0]);
    final urgentVibrationPattern = _settings.vibrationEnabled
        ? _getVibrationPattern('long')
        : Int64List.fromList([0]);

    final taskAudioUsage = _getAudioAttributesUsage(
      _settings.notificationAudioStream,
    );

    // Task reminders channel (notification-like)
    final defaultChannel = AndroidNotificationChannel(
      resolvedTaskChannelId,
      'Task Reminders',
      description: 'Important task reminder notifications',
      importance: Importance
          .max, // Increased from high to max for better vibration/sound priority
      playSound: taskPlaySound,
      sound: taskPlaySound ? _androidSoundForKey(taskSoundKey) : null,
      enableVibration: _settings.vibrationEnabled,
      vibrationPattern: taskVibrationPattern,
      enableLights: _settings.ledEnabled,
      ledColor: const Color(0xFFCDAF56), // Gold color
      showBadge: true,
      audioAttributesUsage: taskAudioUsage,
    );

    // Urgent channel - for high-priority tasks (alarm-like)
    final urgentChannel = AndroidNotificationChannel(
      'urgent_reminders',
      'Urgent Reminders',
      description: 'Critical task reminders that require immediate attention',
      importance: Importance.max,
      playSound: urgentPlaySound,
      sound: urgentPlaySound ? _androidSoundForKey(urgentSoundKey) : null,
      enableVibration: _settings.vibrationEnabled,
      vibrationPattern: urgentVibrationPattern,
      enableLights: _settings.ledEnabled,
      ledColor: const Color(0xFFD32F2F), // Red for urgent
      showBadge: true,
      audioAttributesUsage: AudioAttributesUsage
          .alarm, // CRITICAL: This allows bypassing silent mode
    );

    // Silent channel - for low-priority or silent reminders
    final silentChannel = AndroidNotificationChannel(
      'silent_reminders',
      'Silent Reminders',
      description: 'Silent task reminders',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      enableLights: _settings.ledEnabled,
    );

    // Habit channels (separate from tasks)
    final habitSettings = _notificationSettingsForHabits();
    final habitSoundKey = _effectiveSoundKeyForTaskChannel(habitSettings);
    final habitUrgentSoundKey = _effectiveSoundKeyForUrgentChannel(
      habitSettings,
    );
    final habitPlaySound =
        habitSettings.soundEnabled && habitSoundKey != 'silent';
    final habitUrgentPlaySound =
        habitSettings.soundEnabled && habitUrgentSoundKey != 'silent';

    final habitVibrationPattern = habitSettings.vibrationEnabled
        ? _getVibrationPattern(habitSettings.defaultVibrationPattern)
        : Int64List.fromList([0]);
    final habitUrgentVibrationPattern = habitSettings.vibrationEnabled
        ? _getVibrationPattern('long')
        : Int64List.fromList([0]);

    final habitAudioUsage = _getAudioAttributesUsage(
      habitSettings.notificationAudioStream,
    );

    final habitChannel = AndroidNotificationChannel(
      resolvedHabitChannelId,
      'Habit Reminders',
      description: 'Habit reminder notifications',
      importance: Importance.max,
      playSound: habitPlaySound,
      sound: habitPlaySound ? _androidSoundForKey(habitSoundKey) : null,
      enableVibration: habitSettings.vibrationEnabled,
      vibrationPattern: habitVibrationPattern,
      enableLights: habitSettings.ledEnabled,
      ledColor: const Color(0xFFCDAF56),
      showBadge: true,
      audioAttributesUsage: habitAudioUsage,
    );

    final habitUrgentChannel = AndroidNotificationChannel(
      'habit_urgent_reminders',
      'Habit Urgent Reminders',
      description: 'Critical habit alerts',
      importance: Importance.max,
      playSound: habitUrgentPlaySound,
      sound: habitUrgentPlaySound
          ? _androidSoundForKey(habitUrgentSoundKey)
          : null,
      enableVibration: habitSettings.vibrationEnabled,
      vibrationPattern: habitUrgentVibrationPattern,
      enableLights: habitSettings.ledEnabled,
      ledColor: const Color(0xFFD32F2F),
      showBadge: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    final habitSilentChannel = AndroidNotificationChannel(
      'habit_silent_reminders',
      'Habit Silent Reminders',
      description: 'Silent habit reminders',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      enableLights: habitSettings.ledEnabled,
    );

    // CRITICAL: We MUST delete the channels first to force audio attribute updates.
    // Android ignores changes to existing channels unless you delete them first.
    try {
      await androidPlugin.deleteNotificationChannel('urgent_reminders');
      await androidPlugin.deleteNotificationChannel('habit_urgent_reminders');
      // We don't necessarily delete the others every time to avoid minor blips,
      // but urgent_reminders MUST be reset to ensure Alarm audio usage applies.
    } catch (e) {
      print('NotificationService: Failed to delete channel: $e');
    }

    await androidPlugin.createNotificationChannel(defaultChannel);
    await androidPlugin.createNotificationChannel(urgentChannel);
    await androidPlugin.createNotificationChannel(silentChannel);
    await androidPlugin.createNotificationChannel(habitChannel);
    await androidPlugin.createNotificationChannel(habitUrgentChannel);
    await androidPlugin.createNotificationChannel(habitSilentChannel);

    print(
      'NotificationService: All channels created successfully (urgent_reminders recreated)',
    );
  }

  /// Schedule a notification for a task
  ///
  /// Uses user notification settings for:
  /// - Channel selection
  /// - Alarm mode (for high priority tasks)
  /// - Sound/vibration preferences
  /// - Quiet hours check
  Future<void> scheduleTaskReminder({
    required Task task,
    required Reminder reminder,
    bool forceAlarmMode = false,
    String sourceFlow = 'task_runtime',
  }) async {
    if (!_initialized) await initialize();
    if (!reminder.enabled) return;

    final policy = await NotificationModulePolicy.read(
      NotificationHubModuleIds.task,
    );
    if (!policy.enabled) {
      NotificationFlowTrace.log(
        event: 'legacy_schedule_skipped',
        sourceFlow: sourceFlow,
        moduleId: NotificationHubModuleIds.task,
        entityId: task.id,
        reason: policy.reason,
      );
      return;
    }

    // Reload settings to get latest
    await _loadSettings();

    final DateTime? taskDueDateTime = _getTaskDueDateTime(task);
    if (taskDueDateTime == null) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Task has no due date/time',
      );
      return;
    }

    final DateTime? reminderTime = reminder.calculateReminderTime(
      taskDueDateTime,
    );
    if (reminderTime == null) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Could not calculate reminder time',
      );
      return;
    }

    var effectiveReminderTime = reminderTime;
    final now = DateTime.now();
    if (reminderTime.isBefore(now)) {
      // Editing around the exact trigger minute can put reminderTime a few
      // seconds behind now. Grace that case instead of dropping the reminder.
      final lag = now.difference(reminderTime);
      if (lag <= const Duration(minutes: 1)) {
        effectiveReminderTime = now.add(const Duration(seconds: 5));
      } else {
        print(
          'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Task reminder time is in the past: $reminderTime',
        );
        return;
      }
    }

    // Check if task is special
    final isSpecialTask = task.isSpecial;

    // QUIET HOURS:
    // - If quiet hours are active at the reminder time, special tasks only proceed when
    //   "Allow Special Task Alerts" is enabled.
    // - For normal tasks, defer to the next allowed slot.
    final isQuietAtReminderTime = _settings.isInQuietHoursAt(
      effectiveReminderTime,
    );
    if (isQuietAtReminderTime &&
        isSpecialTask &&
        !_settings.allowUrgentDuringQuietHours) {
      print(
        'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã¢â‚¬â„¢ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ NotificationService: Quiet hours active ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â blocking special task alert',
      );
      return;
    }
    if (isQuietAtReminderTime && !isSpecialTask) {
      final deferred = _nextAllowedTimeOutsideQuietHours(
        candidate: effectiveReminderTime,
        isInQuietHours: _settings.isInQuietHoursAt,
      );
      if (deferred != effectiveReminderTime) {
        print(
          'NotificationService: Quiet hours active, deferring task reminder '
          'from $effectiveReminderTime to $deferred',
        );
        effectiveReminderTime = deferred;
      }
    }

    final notificationId = _generateNotificationId(
      task.id,
      reminder,
      moduleId: NotificationHubModuleIds.task,
    );
    NotificationFlowTrace.log(
      event: 'legacy_schedule_request',
      sourceFlow: sourceFlow,
      moduleId: NotificationHubModuleIds.task,
      entityId: task.id,
      notificationId: notificationId,
      details: <String, dynamic>{
        'reminderType': reminder.type,
        'reminderValue': reminder.value,
        'reminderUnit': reminder.unit,
      },
    );
    await cancelPendingNotificationById(
      notificationId: notificationId,
      entityId: task.id,
      logActivity: false,
    );
    final forceAlarmForSpecial =
        isSpecialTask && _settings.alwaysUseAlarmForSpecialTasks;

    // Determine if alarm mode should be used
    final isHighPriority = task.priority == 'High';
    final useAlarmMode =
        forceAlarmMode ||
        forceAlarmForSpecial ||
        (_settings.alarmModeEnabled &&
            isHighPriority &&
            _settings.alarmModeForHighPriority) ||
        reminder.soundType == 'urgent';

    // Get appropriate channel based on settings
    final channelKey = forceAlarmForSpecial
        ? 'urgent_reminders'
        : _getChannelKeyWithSettings(task.priority, reminder.soundType);

    // Determine which sound to use
    // Special tasks use their own sound when alwaysUseAlarmForSpecialTasks is ON
    String? customSoundKey;
    if (isSpecialTask && _settings.alwaysUseAlarmForSpecialTasks) {
      customSoundKey = _settings.specialTaskSound;
    }

    // REGULAR TASKS "Sound Channel" (stream):
    // - For Alarm/Ring/Media volume, we must play sound via native code.
    // - For Notification volume, some OEMs silently block custom tone URIs on channels.
    //   In that case, fall back to native playback for reliability.
    final channelSoundKey = channelKey == 'urgent_reminders'
        ? _effectiveSoundKeyForUrgentChannel()
        : _effectiveSoundKeyForTaskChannel();
    final bool useNativePlaybackForStream =
        !isSpecialTask &&
        (_settings.notificationAudioStream != 'notification' ||
            (_settings.notificationAudioStream == 'notification' &&
                _isCustomSoundKey(channelSoundKey)));

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService: Scheduling notification for "${task.title}"',
    );
    print('   Task due: $taskDueDateTime');
    print('   Reminder: ${reminder.getDescription()}');
    print('   Notification will fire at: $effectiveReminderTime');
    print('   Notification ID: $notificationId');
    print('   Is Special: $isSpecialTask');
    print('   Alarm Mode: $useAlarmMode');
    print('   Channel: $channelKey');
    print('   Custom Sound: $customSoundKey');
    print('   Special Task Alarm Mode: ${_settings.specialTaskAlarmMode}');

    // Build notification body with category if enabled
    String body = _buildNotificationBody(task, reminder);
    if (_settings.showCategoryInNotification && task.categoryId != null) {
      body = '${task.categoryId} - $body';
    }

    // Render templates
    final titleTemplate = isSpecialTask
        ? _settings.specialTaskTitleTemplate
        : _settings.taskTitleTemplate;
    final bodyTemplate = isSpecialTask
        ? _settings.specialTaskBodyTemplate
        : _settings.taskBodyTemplate;

    final renderedTitle = await _renderTemplate(titleTemplate, task, reminder);
    final renderedBody = await _renderTemplate(bodyTemplate, task, reminder);

    // CRITICAL: Special tasks ALWAYS use AlarmService for maximum reliability
    if (isSpecialTask) {
      print(
        'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Using AlarmService for special task (ALWAYS for reliability)',
      );
      print(
        '   ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒâ€šÃ‚Â Title: $renderedTitle',
      );
      print(
        '   ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒâ€šÃ‚Â Body: $renderedBody',
      );
      print(
        '   ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒâ€šÃ‚Â Icon: ${task.iconCodePoint}',
      );

      final success = await AlarmService().scheduleSpecialTaskAlarm(
        id: notificationId,
        title: renderedTitle,
        body: renderedBody,
        scheduledTime: effectiveReminderTime,
        // Play the user-chosen special-task sound/vibration (not a hardcoded alarm.mp3).
        soundId: _settings.specialTaskSound,
        vibrationPatternId: _settings.specialTaskVibrationPattern,
        // Respect "Special Task Alarm Mode" (fullscreen UI) setting.
        showFullscreen: _settings.specialTaskAlarmMode,
        iconCodePoint: task.iconCodePoint,
        iconFontFamily: task.iconFontFamily ?? 'MaterialIcons',
        iconFontPackage: task.iconFontPackage,
      );

      if (success) {
        print(
          'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService: Special task alarm scheduled via AlarmService!',
        );
        await _trackSpecialAlarmId(task.id, notificationId);
        await _trackNativeAlarmEntry({
          'id': notificationId,
          'type': 'task',
          'entityId': task.id,
          'title': renderedTitle,
          'body': renderedBody,
          'scheduledTimeMs': effectiveReminderTime.millisecondsSinceEpoch,
          'channelKey': 'urgent_reminders',
          'soundKey': _settings.specialTaskSound,
          'vibrationPattern': _settings.specialTaskVibrationPattern,
          'priority': task.priority,
          'isSpecial': true,
          'useAlarmMode': true,
          'showFullscreen': _settings.specialTaskAlarmMode,
          'payload': _buildPayload(task.id, reminder, isHabit: false),
          'audioStream': 'alarm',
          'oneShot': false,
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await _scheduleNotification(
          id: notificationId,
          title: renderedTitle,
          body: renderedBody,
          scheduledDate: effectiveReminderTime,
          channelKey: 'urgent_reminders',
          payload: _buildPayload(task.id, reminder, isHabit: false),
          useAlarmMode: true,
          priority: task.priority,
          isSpecial: isSpecialTask,
          customSoundKey: 'alarm',
          task: task, // Pass task for category icon
        );
      }
    } else {
      if (useNativePlaybackForStream) {
        // For stream != notification, schedule native one-shot playback that:
        // - uses the chosen stream volume (alarm/ring/media)
        // - plays once (NOT an alarm loop)
        // - works even if the app is killed
        //
        // The foreground-service notification created by native is the single UI notification.
        // (We do NOT schedule a second flutter_local_notifications one to avoid duplicates.)
        if (_settings.isInQuietHoursAt(effectiveReminderTime) &&
            !_settings.allowUrgentDuringQuietHours) {
          final deferred = _nextAllowedTimeOutsideQuietHours(
            candidate: effectiveReminderTime,
            isInQuietHours: _settings.isInQuietHoursAt,
          );
          if (deferred != effectiveReminderTime) {
            print(
              'NotificationService: Quiet hours active, deferring stream-backed '
              'task reminder from $effectiveReminderTime to $deferred',
            );
            effectiveReminderTime = deferred;
          } else {
            return;
          }
        }

        // Pick tone based on chosen channel (task vs urgent), but play it on the chosen stream.
        var soundKey = channelKey == 'urgent_reminders'
            ? _effectiveSoundKeyForUrgentChannel()
            : _effectiveSoundKeyForTaskChannel();
        final displaySoundKey = soundKey;

        // IMPORTANT: Native player expects a real URI string for system tones.
        // - 'alarm' => system alarm tone
        // - 'default' => system notification tone
        if (soundKey == 'alarm') {
          soundKey = 'content://settings/system/alarm_alert';
        } else if (soundKey == 'default') {
          soundKey = 'content://settings/system/notification_sound';
        }

        final vibrationPatternId = _settings.vibrationEnabled
            ? 'default'
            : 'none';
        final iconBytes = await _getTaskIconPng(task);
        final iconPngBase64 = iconBytes == null
            ? null
            : base64Encode(iconBytes);

        final success = await AlarmService().scheduleSpecialTaskAlarm(
          id: notificationId,
          title: renderedTitle,
          body: renderedBody,
          scheduledTime: effectiveReminderTime,
          soundId: soundKey,
          vibrationPatternId: vibrationPatternId,
          showFullscreen: false,
          // NEW: tell native which stream to use + play once.
          audioStream: _settings.notificationAudioStream,
          oneShot: true,
          // Allow native notification tap/actions to open the normal task popup flow.
          payload: _buildPayload(task.id, reminder, isHabit: false),
          iconPngBase64: iconPngBase64,
          iconCodePoint: task.iconCodePoint,
          iconFontFamily: task.iconFontFamily ?? 'MaterialIcons',
          iconFontPackage: task.iconFontPackage,
        );

        if (success) {
          await _trackNativeAlarmEntry({
            'id': notificationId,
            'type': 'task',
            'entityId': task.id,
            'title': renderedTitle,
            'body': renderedBody,
            'scheduledTimeMs': effectiveReminderTime.millisecondsSinceEpoch,
            'channelKey': channelKey,
            'soundKey': displaySoundKey,
            'vibrationPattern': vibrationPatternId,
            'priority': task.priority,
            'isSpecial': false,
            'useAlarmMode': false,
            'showFullscreen': false,
            'payload': _buildPayload(task.id, reminder, isHabit: false),
            'audioStream': _settings.notificationAudioStream,
            'oneShot': true,
            'createdAtMs': DateTime.now().millisecondsSinceEpoch,
          });
        } else {
          print(
            'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Native stream playback failed; falling back to normal notification.',
          );
          await _scheduleNotification(
            id: notificationId,
            title: renderedTitle,
            body: renderedBody,
            scheduledDate: effectiveReminderTime,
            channelKey: channelKey,
            payload: _buildPayload(task.id, reminder, isHabit: false),
            useAlarmMode: useAlarmMode,
            priority: task.priority,
            isSpecial: false,
            customSoundKey: customSoundKey,
            task: task,
          );
        }
      } else {
        await _scheduleNotification(
          id: notificationId,
          title: renderedTitle,
          body: renderedBody,
          scheduledDate: effectiveReminderTime,
          channelKey: channelKey,
          payload: _buildPayload(task.id, reminder, isHabit: false),
          useAlarmMode: useAlarmMode,
          priority: task.priority,
          isSpecial: false,
          customSoundKey: customSoundKey,
          task: task, // Pass task for category icon
        );
      }
    }

    unawaited(
      NotificationActivityLogger().logScheduled(
        moduleId: 'task',
        entityId: task.id,
        title: task.title,
        body: '',
        payload: _buildPayload(task.id, reminder, isHabit: false),
      ),
    );
    print(
      'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService: Notification scheduled successfully!',
    );
  }

  Future<String> renderTemplate(
    String template,
    Task task,
    Reminder reminder,
  ) async {
    return await _renderTemplate(template, task, reminder);
  }

  /// Get task icon as PNG bytes for native/Flutter notifications
  Future<Uint8List?> _getTaskIconPng(Task? task) async {
    if (task == null) return null;

    try {
      // Check if task has its own icon
      if (task.iconCodePoint != null) {
        final iconData = IconData(
          task.iconCodePoint!,
          fontFamily: task.iconFontFamily,
          fontPackage: task.iconFontPackage?.isEmpty == true
              ? null
              : task.iconFontPackage,
        );

        // Generate bitmap with gold color for normal tasks, red for special
        final png = await IconBitmapGenerator.iconToBitmap(
          icon: iconData,
          color: task.isSpecial
              ? const Color(0xFFE53935)
              : const Color(0xFFCDAF56),
          size: 128.0, // Increased from 96 to 128 for larger icon
        );

        if (png != null) {
          return png;
        }
      }

      // Fallback: use category icon if task has no icon
      if (task.categoryId != null) {
        final category = await CategoryRepository().getCategoryById(
          task.categoryId!,
        );
        if (category != null) {
          final iconData = IconData(
            int.parse(category.iconCodePoint),
            fontFamily: category.iconFontFamily,
            fontPackage: category.iconFontPackage.isEmpty
                ? null
                : category.iconFontPackage,
          );

          final png = await IconBitmapGenerator.iconToBitmap(
            icon: iconData,
            color: Color(category.colorValue),
            size: 128.0, // Increased from 96 to 128 for larger icon
          );

          if (png != null) {
            return png;
          }
        }
      }

      return null;
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚ÂÃƒâ€¦Ã¢â‚¬â„¢ NotificationService: Error generating task icon: $e',
      );
      return null;
    }
  }

  /// Get task icon as bitmap for notification large icon
  Future<ByteArrayAndroidBitmap?> _getTaskIconBitmap(Task? task) async {
    final png = await _getTaskIconPng(task);
    if (png == null) return null;
    return ByteArrayAndroidBitmap(png);
  }

  /// Get Hub notification icon bitmap from raw icon params.
  /// Used when task/habit are null but the Hub request has icon data.
  Future<ByteArrayAndroidBitmap?> _getHubIconBitmap({
    required int iconCodePoint,
    required String iconFontFamily,
    String? iconFontPackage,
    required int colorValue,
  }) async {
    try {
      final iconData = IconData(
        iconCodePoint,
        fontFamily: iconFontFamily,
        fontPackage: iconFontPackage?.isEmpty == true ? null : iconFontPackage,
      );
      final png = await IconBitmapGenerator.iconToBitmap(
        icon: iconData,
        color: Color(colorValue),
        size: 128.0,
      );
      if (png == null) return null;
      return ByteArrayAndroidBitmap(png);
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚ÂÃƒâ€¦Ã¢â‚¬â„¢ NotificationService: Error generating hub icon: $e',
      );
      return null;
    }
  }

  /// Get category icon as bitmap for notification large icon
  Future<ByteArrayAndroidBitmap?> _getCategoryIconBitmap(
    String? categoryId,
  ) async {
    if (categoryId == null) return null;

    try {
      // Get category from repository
      final category = await CategoryRepository().getCategoryById(categoryId);
      if (category == null) return null;

      // Convert icon data to IconData
      final iconData = IconData(
        int.parse(category.iconCodePoint),
        fontFamily: category.iconFontFamily,
        fontPackage: category.iconFontPackage.isEmpty
            ? null
            : category.iconFontPackage,
      );

      // Generate bitmap
      final bitmap = await IconBitmapGenerator.iconToBitmap(
        icon: iconData,
        color: Color(category.colorValue),
        size: 96.0, // Larger size for better quality
      );

      if (bitmap == null) return null;

      return ByteArrayAndroidBitmap(bitmap);
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚ÂÃƒâ€¦Ã¢â‚¬â„¢ NotificationService: Error generating category icon: $e',
      );
      return null;
    }
  }

  /// Get habit icon as PNG bytes
  Future<Uint8List?> _getHabitIconPng(Habit? habit) async {
    if (habit == null) return null;

    try {
      // Check if habit has its own icon
      if (habit.iconCodePoint != null) {
        final iconData = IconData(
          habit.iconCodePoint!,
          fontFamily: habit.iconFontFamily,
          fontPackage: habit.iconFontPackage?.isEmpty == true
              ? null
              : habit.iconFontPackage,
        );

        // Generate bitmap with red color for special habits, habit color for normal
        final png = await IconBitmapGenerator.iconToBitmap(
          icon: iconData,
          color: habit.isSpecial
              ? const Color(0xFFE53935)
              : Color(habit.colorValue),
          size: 128.0, // Same size as task icons
        );

        if (png != null) {
          return png;
        }
      }

      // Fallback: use category icon if habit has no icon
      if (habit.categoryId != null) {
        final category = await CategoryRepository().getCategoryById(
          habit.categoryId!,
        );
        if (category != null) {
          final iconData = IconData(
            int.parse(category.iconCodePoint),
            fontFamily: category.iconFontFamily,
            fontPackage: category.iconFontPackage.isEmpty
                ? null
                : category.iconFontPackage,
          );

          final png = await IconBitmapGenerator.iconToBitmap(
            icon: iconData,
            color: Color(category.colorValue),
            size: 128.0, // Same size as task icons
          );

          if (png != null) {
            return png;
          }
        }
      }

      return null;
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚ÂÃƒâ€¦Ã¢â‚¬â„¢ NotificationService: Error generating habit icon: $e',
      );
      return null;
    }
  }

  /// Get habit icon as bitmap for notification large icon
  Future<ByteArrayAndroidBitmap?> _getHabitIconBitmap(Habit? habit) async {
    final png = await _getHabitIconPng(habit);
    if (png == null) return null;
    return ByteArrayAndroidBitmap(png);
  }

  /// Render template with placeholders
  Future<String> _renderTemplate(
    String template,
    Task task,
    Reminder reminder,
  ) async {
    String rendered = template;

    // Replace title
    rendered = rendered.replaceAll('{title}', task.title);

    // Replace category (handle null safely - get actual category name)
    String categoryName = '';
    if (task.categoryId != null && task.categoryId!.isNotEmpty) {
      try {
        // Try to get category name from repository
        final category = await CategoryRepository().getCategoryById(
          task.categoryId!,
        );
        categoryName = category?.name ?? '';
      } catch (e) {
        // If category fetch fails, just use empty string
        categoryName = '';
      }
    }
    rendered = rendered.replaceAll('{category}', categoryName);

    // Replace due time
    final dueDateTime = _getTaskDueDateTime(task);
    if (dueDateTime != null) {
      final timeStr =
          '${dueDateTime.hour.toString().padLeft(2, '0')}:${dueDateTime.minute.toString().padLeft(2, '0')}';
      rendered = rendered.replaceAll('{due_time}', timeStr);
    } else {
      rendered = rendered.replaceAll('{due_time}', '');
    }

    // Replace description
    final description = (task.description ?? '').trim();
    rendered = rendered.replaceAll('{description}', description);

    // Replace priority
    rendered = rendered.replaceAll('{priority}', task.priority);

    // Replace progress
    if (!_settings.showProgressInNotification) {
      rendered = rendered.replaceAll('{progress}', '');
    } else if (task.subtasks != null && task.subtasks!.isNotEmpty) {
      final completed = task.subtasks!.where((s) => s.isCompleted).length;
      rendered = rendered.replaceAll(
        '{progress}',
        '$completed/${task.subtasks!.length}',
      );
    } else {
      rendered = rendered.replaceAll('{progress}', '');
    }

    // Replace subtasks as multi-line text (used by templates + Inbox style)
    if (task.subtasks != null && task.subtasks!.isNotEmpty) {
      // Prefer showing incomplete first, cap to keep notification compact
      final List<Subtask> items = <Subtask>[
        ...task.subtasks!.where((Subtask s) => !s.isCompleted),
        ...task.subtasks!.where((Subtask s) => s.isCompleted),
      ];
      final List<String> lines = items.take(5).map((Subtask s) {
        final prefix = s.isCompleted ? '[x] ' : '- ';
        return '$prefix${s.title}'.trim();
      }).toList();
      rendered = rendered.replaceAll('{subtasks}', lines.join('\n'));
    } else {
      rendered = rendered.replaceAll('{subtasks}', '');
    }

    // Normalize legacy separator corruption and render in plain ASCII.
    rendered = rendered
        .replaceAll('\u00C3\u00A2\u00E2\u201A\u00AC\u00C2\u00A2', ' - ')
        .replaceAll('\u00E2\u20AC\u00A2', ' - ')
        .replaceAll('\u2022', ' - ');

    // Clean up separators when category or time is empty.
    if (categoryName.isEmpty) {
      rendered = rendered.replaceAll(' - {due_time}', '{due_time}');
      rendered = rendered.replaceAll('{category} - ', '');
      rendered = rendered.replaceAll(' - ', ' ');
    }

    // Remove trailing separator artifacts when time is empty.
    if (dueDateTime == null) {
      rendered = rendered.replaceAll('{category} - ', '{category}');
      rendered = rendered.replaceAll(' - ', ' ');
    }

    // Final cleanup of any remaining separators.
    rendered = rendered.replaceAll(' -  - ', ' - ');
    rendered = rendered.replaceAll(' - -', ' - ');
    rendered = rendered.trim();

    // Clean up empty lines that can appear when placeholders are missing
    rendered = rendered.replaceAll(RegExp(r'\n\s*\n+'), '\n').trim();

    return rendered;
  }

  Future<String> _renderHabitTemplate(
    String template,
    Habit habit,
    DateTime habitDateTime,
    Reminder reminder,
  ) async {
    String rendered = template;

    rendered = rendered.replaceAll('{title}', habit.title);

    String categoryName = '';
    if (habit.categoryId != null && habit.categoryId!.isNotEmpty) {
      try {
        final category = await CategoryRepository().getCategoryById(
          habit.categoryId!,
        );
        categoryName = category?.name ?? '';
      } catch (_) {
        categoryName = '';
      }
    }
    rendered = rendered.replaceAll('{category}', categoryName);

    final description = (habit.description ?? '').trim();
    rendered = rendered.replaceAll('{description}', description);

    rendered = rendered.replaceAll('{streak}', habit.currentStreak.toString());
    rendered = rendered.replaceAll(
      '{best_streak}',
      habit.bestStreak.toString(),
    );
    rendered = rendered.replaceAll(
      '{total}',
      habit.totalCompletions.toString(),
    );

    final timeStr =
        '${habitDateTime.hour.toString().padLeft(2, '0')}:${habitDateTime.minute.toString().padLeft(2, '0')}';
    rendered = rendered.replaceAll('{time}', timeStr);

    final frequencyLabel = _formatHabitFrequency(habit);
    rendered = rendered.replaceAll('{frequency}', frequencyLabel);

    final goalLabel = _formatHabitGoal(habit);
    rendered = rendered.replaceAll('{goal}', goalLabel);

    rendered = rendered.replaceAll('{reminder}', reminder.getDescription());

    if (categoryName.isEmpty) {
      rendered = rendered.replaceAll('{category}', '');
    }
    if (description.isEmpty) {
      rendered = rendered.replaceAll('{description}', '');
    }
    if (frequencyLabel.isEmpty) {
      rendered = rendered.replaceAll('{frequency}', '');
    }
    if (goalLabel.isEmpty) {
      rendered = rendered.replaceAll('{goal}', '');
    }

    rendered = rendered
        .replaceAll('\u00C3\u00A2\u00E2\u201A\u00AC\u00C2\u00A2', ' - ')
        .replaceAll('\u00E2\u20AC\u00A2', ' - ')
        .replaceAll('\u2022', ' - ');
    rendered = rendered.replaceAll(RegExp(r'\n\s*\n+'), '\n');
    rendered = rendered.replaceAll(' -  - ', ' - ');
    rendered = rendered.replaceAll(' - -', ' - ');

    return rendered.trim();
  }

  String _formatHabitFrequency(Habit habit) {
    switch (habit.frequencyType) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'xTimesPerWeek':
        return '${habit.targetCount}x per week';
      case 'xTimesPerMonth':
        return '${habit.targetCount}x per month';
      case 'custom':
        if (habit.customIntervalDays != null) {
          return 'Every ${habit.customIntervalDays} days';
        }
        return 'Custom';
      default:
        return habit.frequencyType;
    }
  }

  String _formatHabitGoal(Habit habit) {
    if (habit.completionType == 'numeric' && habit.targetValue != null) {
      final unit = habit.unit == 'custom'
          ? (habit.customUnitName ?? '')
          : (habit.unit ?? '');
      final formattedUnit = unit.isNotEmpty ? ' $unit' : '';
      return '${habit.targetValue}$formattedUnit';
    }

    if (habit.completionType == 'timer' &&
        habit.targetDurationMinutes != null) {
      return '${habit.targetDurationMinutes} min';
    }

    if (habit.targetCount > 0) {
      return '${habit.targetCount}x';
    }

    return '';
  }

  /// Get channel key based on priority, sound type, and user settings
  String _getChannelKeyWithSettings(String? priority, String soundType) {
    // Check if specific channels are enabled
    if (soundType == 'silent') {
      return _settings.silentRemindersEnabled
          ? 'silent_reminders'
          : 'task_reminders';
    }

    if (soundType == 'urgent' || priority == 'High') {
      if (_settings.urgentRemindersEnabled) {
        return 'urgent_reminders';
      }
      // Fall back to task reminders if urgent is disabled
      return _settings.taskRemindersEnabled
          ? 'task_reminders'
          : 'silent_reminders';
    }

    // Default channel based on settings
    if (_settings.taskRemindersEnabled) {
      return _settings.defaultChannel;
    }

    return 'silent_reminders';
  }

  /// Schedule multiple reminders for a task
  Future<void> scheduleMultipleReminders({
    required Task task,
    required List<Reminder> reminders,
    String sourceFlow = 'task_runtime',
  }) async {
    for (final reminder in reminders) {
      await scheduleTaskReminder(
        task: task,
        reminder: reminder,
        sourceFlow: sourceFlow,
      );
    }
  }

  /// Cancel a specific reminder for a task
  Future<void> cancelTaskReminder(String taskId, Reminder reminder) async {
    final notificationId = _generateNotificationId(
      taskId,
      reminder,
      moduleId: NotificationHubModuleIds.task,
    );
    await _notificationsPlugin.cancel(notificationId);
    // Also cancel special-task backup notification (if it exists)
    await _notificationsPlugin.cancel(notificationId + 100000);
    // Also cancel any native alarm (safe no-op if not present)
    await AlarmService().cancelAlarm(notificationId);
    // Remove any tracked native alarm entry (best-effort).
    await _removeTrackedNativeAlarmEntry(notificationId);
    // Remove any tracked Flutter notification entry (best-effort).
    await _removeTrackedFlutterNotificationEntry(notificationId);
    // Remove any tracked special alarm id (best-effort).
    try {
      final ids = await _getTrackedSpecialAlarmIds(taskId);
      final remaining = ids.where((id) => id != notificationId).toList();
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsSpecialAlarmIdsPrefix$taskId';
      if (remaining.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, jsonEncode(remaining..sort()));
      }
    } catch (_) {}
  }

  /// Cancel all reminders for a task
  Future<void> cancelAllTaskReminders(
    String taskId, {
    String sourceFlow = 'task_runtime',
    String reason = 'cancel',
  }) async {
    // Robust cancellation:
    // - Cancel all pending plugin notifications whose payload references this taskId
    // - If any are special-task backup notifications (id + 100000), also cancel the native alarm (id - 100000)
    final pending = await _notificationsPlugin.pendingNotificationRequests();

    int cancelled = 0;
    final cancelledIds = <int>{};
    for (final req in pending) {
      final payload = req.payload ?? '';
      // Payload format: task|<taskId>|...
      if (payload.startsWith('task|$taskId|')) {
        await _notificationsPlugin.cancel(req.id);
        cancelled++;
        cancelledIds.add(req.id);

        // If this is a backup notification (scheduled as id + 100000),
        // cancel the corresponding native alarm as well.
        if (req.id >= 100000) {
          await AlarmService().cancelAlarm(req.id - 100000);
        } else {
          // Also attempt to cancel a native alarm with the same id (safe no-op for normal tasks).
          await AlarmService().cancelAlarm(req.id);
        }
      }
    }

    // Cancel native alarms from tracked entries BEFORE removing the tracking
    // data. This covers non-special one-shot alarms that are not tracked via
    // _trackSpecialAlarmId.
    final nativeEntries = await _getTrackedNativeAlarmEntries();
    for (final entry in nativeEntries) {
      if ((entry['entityId'] as String?) == taskId) {
        final alarmId = (entry['id'] as num?)?.toInt();
        if (alarmId != null) {
          await AlarmService().cancelAlarm(alarmId);
          cancelled++;
          cancelledIds.add(alarmId);
        }
      }
    }
    await _removeTrackedNativeAlarmEntriesForTask(taskId);

    // Also remove any tracked Flutter notifications for this task.
    await _removeTrackedFlutterNotificationEntriesForTask(taskId);

    // Also cancel any native alarms we previously scheduled for this task (special tasks).
    final tracked = await _getTrackedSpecialAlarmIds(taskId);
    for (final alarmId in tracked) {
      await AlarmService().cancelAlarm(alarmId);
      cancelledIds.add(alarmId);
    }
    await _clearTrackedSpecialAlarmIds(taskId);

    NotificationFlowTrace.log(
      event: 'legacy_cancel_result',
      sourceFlow: sourceFlow,
      moduleId: NotificationHubModuleIds.task,
      entityId: taskId,
      reason: reason,
      notificationIds: (cancelledIds.toList()..sort()),
      details: <String, dynamic>{'cancelledCount': cancelled},
    );

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â NotificationService: Cancelled $cancelled pending reminders for task $taskId',
    );
  }

  /// Cancel all reminders for a habit
  Future<void> cancelAllHabitReminders(
    String habitId, {
    String sourceFlow = 'habit_runtime',
    String reason = 'cancel',
  }) async {
    final pending = await _notificationsPlugin.pendingNotificationRequests();

    int cancelled = 0;
    final cancelledIds = <int>{};
    for (final req in pending) {
      final payload = req.payload ?? '';
      // Payload format: habit|<habitId>|...
      if (payload.startsWith('habit|$habitId|')) {
        await _notificationsPlugin.cancel(req.id);
        cancelled++;
        cancelledIds.add(req.id);

        if (req.id >= 100000) {
          await AlarmService().cancelAlarm(req.id - 100000);
        } else {
          await AlarmService().cancelAlarm(req.id);
        }
      }
    }

    // Cancel native alarms from tracked entries BEFORE removing the tracking
    // data. This covers non-special one-shot alarms that are not tracked via
    // _trackSpecialAlarmId.
    final nativeEntries = await _getTrackedNativeAlarmEntries();
    for (final entry in nativeEntries) {
      if ((entry['entityId'] as String?) == habitId) {
        final alarmId = (entry['id'] as num?)?.toInt();
        if (alarmId != null) {
          await AlarmService().cancelAlarm(alarmId);
          cancelled++;
          cancelledIds.add(alarmId);
        }
      }
    }
    await _removeTrackedNativeAlarmEntriesForTask(habitId);
    await _removeTrackedFlutterNotificationEntriesForTask(habitId);

    final tracked = await _getTrackedSpecialAlarmIds(habitId);
    for (final alarmId in tracked) {
      await AlarmService().cancelAlarm(alarmId);
      cancelledIds.add(alarmId);
    }
    await _clearTrackedSpecialAlarmIds(habitId);

    NotificationFlowTrace.log(
      event: 'legacy_cancel_result',
      sourceFlow: sourceFlow,
      moduleId: NotificationHubModuleIds.habit,
      entityId: habitId,
      reason: reason,
      notificationIds: (cancelledIds.toList()..sort()),
      details: <String, dynamic>{'cancelledCount': cancelled},
    );

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â NotificationService: Cancelled $cancelled pending reminders for habit $habitId',
    );
  }

  /// Reschedule reminders after task update
  Future<void> rescheduleTaskReminders({
    required Task task,
    required List<Reminder> reminders,
  }) async {
    // Cancel deterministically by ID first (prevents "double audio" if payload format ever changes)
    // then do a robust sweep by payload as a safety net.
    for (final r in reminders) {
      await cancelTaskReminder(task.id, r);
    }
    await cancelAllTaskReminders(task.id, reason: 'reschedule');
    await scheduleMultipleReminders(
      task: task,
      reminders: reminders,
      sourceFlow: 'task_reschedule',
    );
  }

  // ============================================================
  // SIMPLE REMINDERS (Quick reminders without task overhead)
  // ============================================================

  /// Schedule a simple reminder notification at an absolute time
  ///
  /// Used for lightweight reminders like "call someone back"
  /// Uses the standard task notification channel and settings
  Future<bool> scheduleSimpleReminder({
    required int notificationId,
    required String title,
    String? body,
    required DateTime scheduledAt,
    String? payload,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
  }) async {
    if (!_initialized) await initialize();

    // Reload settings to get latest
    await _loadSettings();

    // Check if notifications are enabled
    if (!_settings.notificationsEnabled) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Notifications disabled - cannot schedule simple reminder',
      );
      return false;
    }

    // Check if scheduled time is in the past (allow a small grace window)
    final now = DateTime.now();
    if (scheduledAt.isBefore(now.subtract(const Duration(seconds: 5)))) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Simple reminder time is in the past: $scheduledAt',
      );
      return false;
    }

    // If scheduled time is "now", bump it slightly so AlarmManager accepts it.
    var effectiveScheduledAt =
        scheduledAt.isBefore(now.add(const Duration(seconds: 2)))
        ? now.add(const Duration(seconds: 2))
        : scheduledAt;

    // Check quiet hours
    if (_settings.isInQuietHoursAt(effectiveScheduledAt) &&
        !_settings.allowUrgentDuringQuietHours) {
      final deferred = _nextAllowedTimeOutsideQuietHours(
        candidate: effectiveScheduledAt,
        isInQuietHours: _settings.isInQuietHoursAt,
      );
      if (deferred != effectiveScheduledAt) {
        print(
          'NotificationService: Quiet hours active, deferring simple reminder '
          'from $effectiveScheduledAt to $deferred',
        );
        effectiveScheduledAt = deferred;
      }
    }
    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService: Scheduling simple reminder',
    );
    print('   Title: $title');
    print('   Body: ${body ?? "(no body)"}');
    print('   Scheduled: $effectiveScheduledAt');
    print('   Notification ID: $notificationId');

    // Build the notification payload
    final reminderPayload = payload ?? 'simple_reminder|$notificationId';

    // Use the same channel logic as regular tasks
    final channelKey = _getChannelKeyWithSettings(null, 'default');

    // Determine sound for channel and whether we need native playback
    final channelSoundKey = channelKey == 'urgent_reminders'
        ? _effectiveSoundKeyForUrgentChannel()
        : _effectiveSoundKeyForTaskChannel();
    final useNativePlaybackForStream =
        _settings.notificationAudioStream != 'notification' ||
        (_settings.notificationAudioStream == 'notification' &&
            _isCustomSoundKey(channelSoundKey));

    if (useNativePlaybackForStream) {
      final isUrgent = channelKey == 'urgent_reminders';
      if (_settings.isInQuietHoursAt(effectiveScheduledAt) &&
          (!isUrgent || !_settings.allowUrgentDuringQuietHours)) {
        final deferred = _nextAllowedTimeOutsideQuietHours(
          candidate: effectiveScheduledAt,
          isInQuietHours: _settings.isInQuietHoursAt,
        );
        if (deferred != effectiveScheduledAt) {
          print(
            'NotificationService: Quiet hours active, deferring stream-backed '
            'simple reminder from $effectiveScheduledAt to $deferred',
          );
          effectiveScheduledAt = deferred;
        } else {
          return false;
        }
      }

      // Pick tone based on chosen channel (task vs urgent), but play it on the chosen stream.
      var soundKey = isUrgent
          ? _effectiveSoundKeyForUrgentChannel()
          : _effectiveSoundKeyForTaskChannel();
      final displaySoundKey = soundKey;

      // IMPORTANT: Native player expects a real URI string for system tones.
      if (soundKey == 'alarm') {
        soundKey = 'content://settings/system/alarm_alert';
      } else if (soundKey == 'default') {
        soundKey = 'content://settings/system/notification_sound';
      }

      final vibrationPatternId = _settings.vibrationEnabled
          ? 'default'
          : 'none';

      final success = await AlarmService().scheduleSpecialTaskAlarm(
        id: notificationId,
        title: title,
        body: body ?? '',
        scheduledTime: effectiveScheduledAt,
        soundId: soundKey,
        vibrationPatternId: vibrationPatternId,
        showFullscreen: false,
        audioStream: _settings.notificationAudioStream,
        oneShot: true,
        payload: reminderPayload,
        iconCodePoint: iconCodePoint,
        iconFontFamily: iconFontFamily ?? 'MaterialIcons',
        iconFontPackage: iconFontPackage,
      );

      if (success) {
        await _trackNativeAlarmEntry({
          'id': notificationId,
          'type': 'simple_reminder',
          'entityId': '',
          'title': title,
          'body': body ?? '',
          'scheduledTimeMs': effectiveScheduledAt.millisecondsSinceEpoch,
          'channelKey': channelKey,
          'soundKey': displaySoundKey,
          'vibrationPattern': vibrationPatternId,
          'priority': 'Medium',
          'isSpecial': false,
          'useAlarmMode': false,
          'showFullscreen': false,
          'payload': reminderPayload,
          'audioStream': _settings.notificationAudioStream,
          'oneShot': true,
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        });

        print(
          'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService: Simple reminder scheduled via native stream playback',
        );
        return true;
      }

      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Native stream playback failed; falling back to normal notification.',
      );
    }

    try {
      await _scheduleNotification(
        id: notificationId,
        title: title,
        body: body ?? '',
        scheduledDate: effectiveScheduledAt,
        channelKey: channelKey,
        payload: reminderPayload,
        useAlarmMode: false,
        priority: 'Medium',
        isSpecial: false,
        customSoundKey: null,
        task: null,
        habit: null,
        hubIconCodePoint: iconCodePoint,
        hubIconFontFamily: iconFontFamily,
        hubIconFontPackage: iconFontPackage,
        hubColorValue: colorValue,
      );

      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService: Simple reminder scheduled successfully',
      );
      return true;
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚ÂÃƒâ€¦Ã¢â‚¬â„¢ NotificationService: Failed to schedule simple reminder: $e',
      );
      return false;
    }
  }

  /// Cancel a simple reminder by its notification ID
  Future<void> cancelSimpleReminder(int notificationId) async {
    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â NotificationService: Cancelling simple reminder $notificationId',
    );
    await _notificationsPlugin.cancel(notificationId);
  }

  /// Reschedule a simple reminder (cancel old one and schedule new)
  Future<bool> rescheduleSimpleReminder({
    required int notificationId,
    required String title,
    String? body,
    required DateTime scheduledAt,
    String? payload,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
  }) async {
    await cancelSimpleReminder(notificationId);
    return scheduleSimpleReminder(
      notificationId: notificationId,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      payload: payload,
      iconCodePoint: iconCodePoint,
      iconFontFamily: iconFontFamily,
      iconFontPackage: iconFontPackage,
      colorValue: colorValue,
    );
  }

  // ---------------------------------------------------------------------------
  // Hub Reminder ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ full-featured scheduling for the Notification Hub
  // ---------------------------------------------------------------------------

  /// Schedule a notification through the hub's full pipeline.
  ///
  /// Unlike [scheduleSimpleReminder] this method supports channel selection,
  /// urgency routing, custom sounds, vibration patterns, alarm-mode,
  /// audio-stream override, special alert routing, and quiet-hours checks.
  Future<bool> scheduleHubReminder({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
    required String channelKey,
    String? soundKey,
    String? vibrationPatternId,
    String audioStream = 'notification',
    bool useAlarmMode = false,
    bool bypassQuietHours = false,
    bool isSpecial = false,
    bool useFullScreenIntent = false,
    String? priority,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    List<HubNotificationAction>? actionButtons,
    NotificationSettings? settingsOverride,
    bool useAlarmClockScheduleMode = false,
  }) async {
    if (!_initialized) await initialize();

    await _loadSettings();
    final settings = settingsOverride ?? _settings;

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Guard: notifications disabled ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    if (!settings.notificationsEnabled) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService.scheduleHubReminder: notifications disabled',
      );
      return false;
    }

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Guard: scheduled time in the past ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    final now = DateTime.now();
    if (scheduledAt.isBefore(now.subtract(const Duration(seconds: 5)))) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService.scheduleHubReminder: time in the past: $scheduledAt',
      );
      return false;
    }

    // Bump "now" times slightly so AlarmManager accepts them.
    var effectiveScheduledAt =
        scheduledAt.isBefore(now.add(const Duration(seconds: 2)))
        ? now.add(const Duration(seconds: 2))
        : scheduledAt;

    // Idempotent scheduling: always replace any existing OS entry for this ID.
    await cancelPendingNotificationById(
      notificationId: notificationId,
      logActivity: false,
    );

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Resolve effective channel ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    String effectiveChannelKey = channelKey;

    bool isUrgentChannel(String key) =>
        key == 'urgent_reminders' || key == 'habit_urgent_reminders';

    bool effectiveIsSpecial = isSpecial;

    if (effectiveIsSpecial &&
        settings.alwaysUseAlarmForSpecialTasks &&
        (channelKey == 'task_reminders' || channelKey == 'habit_reminders')) {
      effectiveChannelKey = channelKey.startsWith('habit_')
          ? 'habit_urgent_reminders'
          : 'urgent_reminders';
    }

    bool isUrgent = isUrgentChannel(effectiveChannelKey);

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Determine alarm mode ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    bool shouldUseAlarmMode =
        useAlarmMode ||
        (settings.alarmModeEnabled &&
            (isUrgent ||
                (priority == 'High' && settings.alarmModeForHighPriority)));

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Determine audio stream ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    // Priority: alarm mode forces alarm stream; otherwise respect the
    // explicitly-passed audioStream (which may come from a Hub per-type
    // override the user configured). Only fall back to 'alarm' for urgent
    // channels when no explicit stream was provided.
    String effectiveAudioStream;
    if (shouldUseAlarmMode) {
      effectiveAudioStream = 'alarm';
    } else if (audioStream != 'notification') {
      // Caller (Hub) explicitly chose a non-default stream ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ respect it.
      effectiveAudioStream = audioStream;
    } else if (isUrgent) {
      // Urgent channel with default stream ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ use alarm
      effectiveAudioStream = 'alarm';
    } else {
      effectiveAudioStream = audioStream;
    }

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Full-screen intent resolution ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    bool effectiveUseFullScreenIntent = useFullScreenIntent;

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Sound key resolution ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    String effectiveSoundKey =
        soundKey ??
        (isUrgent
            ? _effectiveSoundKeyForUrgentChannel(settings)
            : _effectiveSoundKeyForTaskChannel(settings));

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Vibration resolution ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    String effectiveVibrationId =
        vibrationPatternId ??
        (settings.vibrationEnabled
            ? (settings.defaultVibrationPattern.isNotEmpty
                  ? settings.defaultVibrationPattern
                  : 'default')
            : 'none');

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Quiet hours policy (global -> module -> notification privilege) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    //
    // settings.allowUrgentDuringQuietHours is the merged effective module/global
    // switch for hub scheduling (module override on top of global default).
    //
    // Standard behavior: non-bypassed notifications are deferred outside quiet
    // hours. We do not silently downgrade to a silent channel.
    final quietAdjustedAt = _applyHubQuietHoursPolicy(
      scheduledAt: effectiveScheduledAt,
      settings: settings,
      bypassQuietHours: bypassQuietHours,
    );
    if (quietAdjustedAt == null) {
      print(
        '?? NotificationService.scheduleHubReminder: quiet hours active and no defer slot found',
      );
      return false;
    }
    if (quietAdjustedAt != effectiveScheduledAt) {
      print(
        '?? NotificationService.scheduleHubReminder: quiet hours active -> deferring from $effectiveScheduledAt to $quietAdjustedAt',
      );
      effectiveScheduledAt = quietAdjustedAt;
    }

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Check if we need native (AlarmService) playback ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    final needsNativePlayback =
        effectiveAudioStream != 'notification' ||
        _isCustomSoundKey(effectiveSoundKey) ||
        effectiveIsSpecial ||
        shouldUseAlarmMode;

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService.scheduleHubReminder:',
    );
    print('   Title: $title');
    print('   Channel: $effectiveChannelKey');
    print('   Sound: $effectiveSoundKey');
    print('   AudioStream: $effectiveAudioStream');
    print('   AlarmMode: $shouldUseAlarmMode');
    print('   NativePlayback: $needsNativePlayback');
    print('   BypassQuietHours: $bypassQuietHours');
    print('   Scheduled: $effectiveScheduledAt');
    print('   Notification ID: $notificationId');

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Native alarm path ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    if (needsNativePlayback) {
      var nativeSoundKey = effectiveSoundKey;
      if (nativeSoundKey == 'alarm') {
        nativeSoundKey = 'content://settings/system/alarm_alert';
      } else if (nativeSoundKey == 'default') {
        nativeSoundKey = 'content://settings/system/notification_sound';
      }

      // Generate icon PNG for native (Alarm path cannot use codePoint directly)
      String? iconPngBase64;
      if (iconCodePoint != null) {
        final png = await IconBitmapGenerator.iconToBitmap(
          icon: IconData(
            iconCodePoint,
            fontFamily: iconFontFamily ?? 'MaterialIcons',
            fontPackage: iconFontPackage?.isEmpty == true
                ? null
                : iconFontPackage,
          ),
          color: Color(colorValue ?? 0xFFCDAF56),
          size: 128.0,
        );
        if (png != null) {
          iconPngBase64 = base64Encode(png);
        }
      }

      final hasActionButtons =
          actionButtons != null && actionButtons.isNotEmpty;

      // Serialize actions for native alarm path (dynamic View, Pay Now, etc.)
      final buttons = actionButtons ?? <HubNotificationAction>[];
      final actionButtonsJson = buttons.isEmpty
          ? null
          : jsonEncode(
              buttons
                  .map(
                    (a) => <String, dynamic>{
                      'actionId': a.actionId,
                      'label': _normalizeActionLabel(
                        actionId: a.actionId,
                        label: a.label,
                      ),
                    },
                  )
                  .toList(),
            );

      final success = await AlarmService().scheduleSpecialTaskAlarm(
        id: notificationId,
        title: title,
        body: body,
        scheduledTime: effectiveScheduledAt,
        soundId: nativeSoundKey,
        vibrationPatternId: effectiveVibrationId,
        showFullscreen: effectiveUseFullScreenIntent,
        audioStream: effectiveAudioStream,
        oneShot: true,
        payload: payload,
        iconPngBase64: iconPngBase64,
        iconCodePoint: iconCodePoint,
        iconFontFamily: iconFontFamily ?? 'MaterialIcons',
        iconFontPackage: iconFontPackage,
        actionsEnabled: hasActionButtons,
        actionButtonsJson: actionButtonsJson,
      );

      if (success) {
        await _trackNativeAlarmEntry({
          'id': notificationId,
          'type': 'hub_reminder',
          'entityId': '',
          'title': title,
          'body': body,
          'scheduledTimeMs': effectiveScheduledAt.millisecondsSinceEpoch,
          'channelKey': effectiveChannelKey,
          'soundKey': effectiveSoundKey,
          'vibrationPattern': effectiveVibrationId,
          'priority': priority ?? 'Medium',
          'isSpecial': effectiveIsSpecial,
          'useAlarmMode': shouldUseAlarmMode,
          'showFullscreen': effectiveUseFullScreenIntent,
          'payload': payload,
          'audioStream': effectiveAudioStream,
          'oneShot': true,
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        });

        print(
          'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService.scheduleHubReminder: scheduled via native alarm',
        );
        return true;
      }

      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService.scheduleHubReminder: native alarm failed, falling back to standard notification',
      );
    }

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Standard notification path ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    try {
      await _scheduleNotification(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: effectiveScheduledAt,
        channelKey: effectiveChannelKey,
        payload: payload,
        useAlarmMode: shouldUseAlarmMode,
        priority: priority,
        isSpecial: effectiveIsSpecial,
        customSoundKey: effectiveSoundKey,
        task: null,
        habit: null,
        notificationKindLabel: 'Hub',
        audioStreamOverride: effectiveAudioStream,
        settingsOverride: settings,
        hubIconCodePoint: iconCodePoint,
        hubIconFontFamily: iconFontFamily,
        hubIconFontPackage: iconFontPackage,
        hubColorValue: colorValue,
        hubActionButtons: actionButtons,
        enforceQuietHours: false,
        useAlarmClockScheduleMode: useAlarmClockScheduleMode,
      );

      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService.scheduleHubReminder: scheduled via standard notification',
      );
      return true;
    } catch (e) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚ÂÃƒâ€¦Ã¢â‚¬â„¢ NotificationService.scheduleHubReminder: $e',
      );
      return false;
    }
  }

  /// Schedule immediate notification (for testing or instant alerts)
  ///
  /// Uses alarm mode based on user settings
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
    bool useAlarmMode = true,
    String channelKey = 'task_reminders',
    bool forceAlarmBypass =
        false, // When true, ALWAYS use alarm mode (for Special Tasks)
    String notificationKindLabel = 'Task',
  }) async {
    print('NotificationService: showImmediateNotification called:');
    print('   - Title: $title');
    print('   - Channel: $channelKey');
    print('   - Use Alarm Mode: $useAlarmMode');
    print('   - Force Alarm Bypass: $forceAlarmBypass');

    if (!_initialized) {
      print('NotificationService: Not initialized, calling initialize()...');
      await initialize();
    }

    // Reload settings to get latest
    await _loadSettings();
    print(
      'NotificationService: Settings loaded - notificationsEnabled: ${_settings.notificationsEnabled}',
    );

    // Check if notifications are enabled
    if (!_settings.notificationsEnabled) {
      print('NotificationService: Notifications disabled by user');
      return;
    }

    // Determine if we should use alarm mode
    // forceAlarmBypass = true means ALWAYS use alarm mode (for Special Task Alerts)
    final shouldUseAlarmMode =
        forceAlarmBypass || (useAlarmMode && _settings.alarmModeEnabled);
    print(
      'NotificationService: Should use alarm mode: $shouldUseAlarmMode (force: $forceAlarmBypass, setting: ${_settings.alarmModeEnabled})',
    );

    // Get vibration pattern
    final vibrationPattern = _getVibrationPattern(
      _settings.defaultVibrationPattern,
    );
    print(
      'NotificationService: Vibration pattern: ${vibrationPattern.length} values',
    );

    // Determine timeout based on settings
    final timeoutAfter = _settings.notificationTimeout > 0
        ? Duration(seconds: _settings.notificationTimeout)
        : null;

    // For alarm bypass, we MUST use the urgent_reminders channel (which has AudioAttributesUsage.alarm)
    final effectiveChannel = shouldUseAlarmMode
        ? 'urgent_reminders'
        : channelKey;
    final effectiveAndroidChannelId = _resolveAndroidChannelId(
      effectiveChannel,
    );

    // Get the sound for the effective channel
    final soundKey = shouldUseAlarmMode
        ? _settings.urgentRemindersSound
        : _settings.taskRemindersSound;
    final shouldPlaySound =
        _settings.soundEnabled ||
        shouldUseAlarmMode; // Always play sound for alarm mode

    print(
      'NotificationService: Effective channel: $effectiveChannel, Sound: $soundKey, Play: $shouldPlaySound',
    );

    // Create notification with user settings
    final groupKeyBase = notificationKindLabel.toLowerCase() == 'habit'
        ? 'habit_reminders_group'
        : 'task_reminders_group';

    final androidDetails = AndroidNotificationDetails(
      effectiveAndroidChannelId,
      _getChannelName(effectiveChannel),
      channelDescription: shouldUseAlarmMode
          ? 'Critical alerts that bypass silent mode'
          : 'Task reminder notification',
      importance: Importance.max,
      priority: Priority.max,

      // CRITICAL: Set audio attributes to ALARM for silent mode bypass
      audioAttributesUsage: shouldUseAlarmMode
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,

      // SECURITY:
      // Never open the app full-screen for normal tasks (even high priority).
      // Full-screen intents are reserved for SPECIAL task alarms only.
      // forceAlarmBypass=true indicates this is a special task alarm.
      fullScreenIntent: forceAlarmBypass,

      // Category MUST be alarm to bypass silent mode
      category: shouldUseAlarmMode
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,

      // Visibility based on settings
      visibility: _settings.showOnLockScreen
          ? NotificationVisibility.public
          : NotificationVisibility.private,

      // Sound - for alarm mode, ALWAYS play sound
      playSound: shouldPlaySound,
      sound: shouldPlaySound ? _androidSoundForKey(soundKey) : null,

      // Vibration
      enableVibration: _settings.vibrationEnabled || shouldUseAlarmMode,
      vibrationPattern: vibrationPattern,

      // LED light based on settings
      enableLights: _settings.ledEnabled,
      ledColor: shouldUseAlarmMode
          ? const Color(0xFFD32F2F)
          : const Color(0xFFCDAF56),
      ledOnMs: 1000,
      ledOffMs: 500,

      // Ticker
      ticker: shouldUseAlarmMode ? 'ALERT $title' : 'Reminder $title',

      // Style
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: shouldUseAlarmMode ? 'URGENT' : 'Task Reminder',
      ),

      // Actions
      actions: _getNotificationActions(isHabit: false),

      // For alarms: ongoing and no auto-cancel so user must dismiss
      autoCancel: shouldUseAlarmMode
          ? false
          : (!_settings.persistentNotifications),
      ongoing: shouldUseAlarmMode || _settings.persistentNotifications,

      // Timeout - no timeout for alarms
      timeoutAfter: shouldUseAlarmMode ? null : timeoutAfter?.inMilliseconds,

      // Color accent
      color: shouldUseAlarmMode
          ? const Color(0xFFD32F2F)
          : const Color(0xFFCDAF56),

      // Subtext
      subText: shouldUseAlarmMode ? 'Special Alert' : 'Life Manager',
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: _settings.soundEnabled,
      sound: _settings.soundEnabled ? 'default' : null,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    print('NotificationService: Notification shown successfully!');
  }

  /// Show a test notification for display settings (scheduled 5 seconds in future)
  Future<void> showTestDisplayNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();
    await _loadSettings();

    if (!_settings.notificationsEnabled) {
      print('NotificationService: Notifications disabled by user');
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testChannelId = 'lm_test_display_$timestamp';

    final soundKey = _settings.defaultSound;
    final wantSound = _settings.soundEnabled && soundKey != 'silent';
    final enableVibration = _settings.vibrationEnabled;

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Test Display Notification (fires in 5 seconds):',
    );
    print('   Show on Lock Screen: ${_settings.showOnLockScreen}');
    print('   Wake Screen: ${_settings.wakeScreen}');
    print('   LED Enabled: ${_settings.ledEnabled}');
    print('   Persistent: ${_settings.persistentNotifications}');
    print('   Sound: $wantSound ($soundKey)');
    print('   Vibrate: $enableVibration');

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      try {
        await androidPlugin.deleteNotificationChannel(testChannelId);
      } catch (_) {}

      final channel = AndroidNotificationChannel(
        testChannelId,
        'Test Display Settings',
        description: 'Test notification for display settings preview',
        importance: Importance.max,
        playSound: wantSound,
        sound: wantSound ? _androidSoundForKey(soundKey) : null,
        enableVibration: enableVibration,
        vibrationPattern: enableVibration
            ? _getVibrationPattern(_settings.defaultVibrationPattern)
            : null,
        enableLights: _settings.ledEnabled,
        ledColor: const Color(0xFFFFB74D),
        showBadge: true,
      );

      await androidPlugin.createNotificationChannel(channel);
    }

    final androidDetails = AndroidNotificationDetails(
      testChannelId,
      'Test Display Settings',
      channelDescription: 'Test notification for display settings preview',
      importance: Importance.max,
      priority: Priority.max,
      playSound: wantSound,
      sound: wantSound ? _androidSoundForKey(soundKey) : null,
      enableVibration: enableVibration,
      vibrationPattern: enableVibration
          ? _getVibrationPattern(_settings.defaultVibrationPattern)
          : null,
      enableLights: _settings.ledEnabled,
      ledColor: const Color(0xFFFFB74D),
      ledOnMs: 1000,
      ledOffMs: 500,
      ongoing: _settings.persistentNotifications,
      autoCancel: !_settings.persistentNotifications,
      // NOTE: fullScreenIntent opens the app - only used for special task alarms
      // Regular notifications should NOT use fullScreenIntent
      fullScreenIntent: false,
      visibility: _settings.showOnLockScreen
          ? NotificationVisibility.public
          : NotificationVisibility.private,
      // Wake screen is handled by high importance + heads-up display
      category: AndroidNotificationCategory.reminder,
      channelShowBadge: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: wantSound,
      sound: wantSound ? 'default' : null,
    );

    // Schedule 5 seconds in the future
    final scheduledTime = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(seconds: 5));

    await _notificationsPlugin.zonedSchedule(
      timestamp % 100000,
      title,
      body,
      scheduledTime,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    print(
      'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ Test notification scheduled for: $scheduledTime',
    );
  }

  /// Sends a test notification that **always** respects the current Sound/Vibration
  /// toggles and the chosen audio stream (Notification, Alarm, Ring, Media).
  ///
  /// For non-notification streams, we play the sound separately using
  /// SoundPlayerService to ensure it uses the correct volume control.
  ///
  /// Set [useNotificationChannel] to true to always use the regular Notification
  /// volume channel (e.g. for Hub Health test), ignoring the configured stream.
  Future<void> showTestNotification({
    required String title,
    required String body,
    bool useNotificationChannel = false,
  }) async {
    if (!_initialized) await initialize();
    await _loadSettings();

    if (!_settings.notificationsEnabled) {
      print('NotificationService: Notifications disabled by user');
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testChannelId = 'lm_test_$timestamp';

    final soundKey = _settings.defaultSound;
    final wantSound = _settings.soundEnabled && soundKey != 'silent';
    final enableVibration = _settings.vibrationEnabled;
    final audioStream = useNotificationChannel
        ? 'notification'
        : _settings.notificationAudioStream;

    // Determine if we need to play sound separately (for non-notification streams)
    // Android's notification system always uses notification volume, so we must
    // play sounds on other streams (alarm, ring, media) using a separate audio player.
    final useExternalSoundPlayer =
        wantSound && !useNotificationChannel && audioStream != 'notification';

    // If using external player, the notification itself should be silent
    final notificationPlaySound = wantSound && !useExternalSoundPlayer;

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Test Notification [$timestamp]:',
    );
    print('   Sound: $wantSound ($soundKey)');
    print('   Stream: $audioStream');
    print('   Vibrate: $enableVibration');
    print('   External player: $useExternalSoundPlayer');
    print('   Notification sound: $notificationPlaySound');

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      try {
        await androidPlugin.deleteNotificationChannel('lm_test_notifications');
      } catch (_) {}

      // Create channel - silent if we're using external player
      final channel = AndroidNotificationChannel(
        testChannelId,
        'Test Notification (Preview)',
        description: 'Temporary channel for immediate preview',
        importance: Importance.max,
        playSound: notificationPlaySound,
        sound: notificationPlaySound ? _androidSoundForKey(soundKey) : null,
        enableVibration: enableVibration,
        vibrationPattern: enableVibration
            ? _getVibrationPattern(_settings.defaultVibrationPattern)
            : null,
        enableLights: true,
        showBadge: false,
        audioAttributesUsage: _getAudioAttributesUsage(audioStream),
      );

      await androidPlugin.createNotificationChannel(channel);
    }

    // Build notification details
    final streamLabel = NotificationSettings.getAudioStreamDisplayName(
      audioStream,
    );
    final enhancedBody =
        '$body\n\nÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒâ€¦Ã‚Â  Playing on: $streamLabel';

    final androidDetails = AndroidNotificationDetails(
      testChannelId,
      'Test Notification (Preview)',
      channelDescription: 'Temporary channel for immediate preview',
      importance: Importance.max,
      priority: Priority.max,
      playSound: notificationPlaySound,
      sound: notificationPlaySound ? _androidSoundForKey(soundKey) : null,
      enableVibration: enableVibration,
      vibrationPattern: enableVibration
          ? _getVibrationPattern(_settings.defaultVibrationPattern)
          : null,
      audioAttributesUsage: _getAudioAttributesUsage(audioStream),
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: _settings.soundEnabled,
      sound: _settings.soundEnabled ? 'default' : null,
    );

    // Show the notification
    await _notificationsPlugin.show(
      timestamp % 100000,
      title,
      enhancedBody,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );

    // Play sound on the correct stream using external player
    if (useExternalSoundPlayer) {
      // Vibrate FIRST - fires immediately
      if (enableVibration) {
        _vibrateAlarm();
      }

      print(
        'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒâ€¦Ã‚Â  Playing sound on $audioStream stream via SoundPlayerService...',
      );
      await SoundPlayerService().playSound(
        stream: audioStream,
        soundKey: soundKey,
      );
    }

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ Test notification complete!',
    );
  }

  Future<void> showTestHabitNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();
    await _loadHabitSettings();

    if (!_habitSettings.notificationsEnabled) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Habit notifications disabled by user',
      );
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testChannelId = 'lm_habit_test_$timestamp';

    final soundKey = _habitSettings.defaultSound;
    final wantSound = _habitSettings.soundEnabled && soundKey != 'silent';
    final enableVibration = _habitSettings.vibrationEnabled;
    final audioStream = _habitSettings.notificationAudioStream;

    final useExternalSoundPlayer = wantSound && audioStream != 'notification';
    final notificationPlaySound = wantSound && !useExternalSoundPlayer;

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      try {
        await androidPlugin.deleteNotificationChannel(testChannelId);
      } catch (_) {}

      final channel = AndroidNotificationChannel(
        testChannelId,
        'Habit Notification (Preview)',
        description: 'Temporary channel for habit preview',
        importance: Importance.max,
        playSound: notificationPlaySound,
        sound: notificationPlaySound ? _androidSoundForKey(soundKey) : null,
        enableVibration: enableVibration,
        vibrationPattern: enableVibration
            ? _getVibrationPattern(_habitSettings.defaultVibrationPattern)
            : null,
        enableLights: _habitSettings.ledEnabled,
        showBadge: false,
        audioAttributesUsage: _getAudioAttributesUsage(audioStream),
      );

      await androidPlugin.createNotificationChannel(channel);
    }

    final streamLabel = HabitNotificationSettings.getAudioStreamDisplayName(
      audioStream,
    );
    final enhancedBody =
        '$body\n\nÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒâ€¦Ã‚Â  Playing on: $streamLabel';

    final androidDetails = AndroidNotificationDetails(
      testChannelId,
      'Habit Notification (Preview)',
      channelDescription: 'Temporary channel for habit preview',
      importance: Importance.max,
      priority: Priority.max,
      playSound: notificationPlaySound,
      sound: notificationPlaySound ? _androidSoundForKey(soundKey) : null,
      enableVibration: enableVibration,
      vibrationPattern: enableVibration
          ? _getVibrationPattern(_habitSettings.defaultVibrationPattern)
          : null,
      audioAttributesUsage: _getAudioAttributesUsage(audioStream),
      enableLights: _habitSettings.ledEnabled,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: _habitSettings.soundEnabled,
      sound: _habitSettings.soundEnabled ? 'default' : null,
    );

    await _notificationsPlugin.show(
      timestamp % 100000,
      title,
      enhancedBody,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );

    if (useExternalSoundPlayer) {
      if (enableVibration) {
        _vibrateAlarm();
      }
      await SoundPlayerService().playSound(
        stream: audioStream,
        soundKey: soundKey,
      );
    }
  }

  Future<void> showTestSpecialHabitNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();
    await _loadHabitSettings();

    if (!_habitSettings.notificationsEnabled) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Habit notifications disabled by user',
      );
      return;
    }

    await AlarmService().scheduleTestAlarm(
      title: title,
      body: body,
      showFullscreen: false,
      soundId: _habitSettings.specialHabitSound,
      vibrationPatternId: _habitSettings.specialHabitVibrationPattern,
    );
  }

  /// Sends a test notification for SPECIAL TASKS.
  /// Uses SoundPlayerService to play the chosen sound on ALARM stream.
  /// If Alarm Mode is enabled, shows full-screen alarm popup.
  ///
  /// Returns true if alarm mode is enabled (caller should show AlarmScreen).
  /// Test special task notification using the alarm package
  ///
  /// This uses the SAME mechanism as real special task notifications:
  /// - AlarmService with alarm.mp3 asset
  /// - Fires in 3 seconds
  /// - Returns true if alarm mode is enabled (caller should show AlarmScreen)
  Future<bool> showTestSpecialTaskNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();
    await _loadSettings();

    if (!_settings.notificationsEnabled) {
      print('NotificationService: Notifications disabled by user');
      return false;
    }

    final useAlarmMode = _settings.specialTaskAlarmMode;

    print('ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚Â­Ãƒâ€šÃ‚Â Special Task Test:');
    print('   Sound: alarm.mp3 (from assets)');
    print('   Alarm Mode UI: $useAlarmMode');
    print('   Will fire in 3 seconds via AlarmService');

    // Schedule a test alarm using AlarmService (same as real special tasks)
    // showFullscreen: false because alarm mode is OFF - just play sound with notification
    final success = await AlarmService().scheduleTestAlarm(
      title: title,
      body: body,
      showFullscreen:
          false, // Alarm mode OFF - just notification, no full-screen UI
      soundId: _settings.specialTaskSound,
      vibrationPatternId: _settings.specialTaskVibrationPattern,
    );

    if (success) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚Â­Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ Special task test alarm scheduled (fires in 3 seconds)',
      );
    } else {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Failed to schedule test alarm',
      );
    }

    // Return true if alarm mode is enabled so caller can prepare for AlarmScreen
    return useAlarmMode;
  }

  /// Vibrate immediately - bypasses silent mode
  /// Simple single vibration for instant feedback
  void _vibrateAlarm() {
    // Fire immediately - no await, no checks that cause delay
    Vibration.vibrate(duration: 1000);
  }

  /// Internal: Schedule a notification - Uses user settings for behavior
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelKey,
    String? payload,
    bool useAlarmMode = false,
    String? priority,
    bool isSpecial = false,
    String? customSoundKey,
    Task? task,
    Habit? habit,
    String notificationKindLabel = 'Task',
    String? audioStreamOverride,
    NotificationSettings? settingsOverride,
    int? hubIconCodePoint,
    String? hubIconFontFamily,
    String? hubIconFontPackage,
    int? hubColorValue,
    List<HubNotificationAction>? hubActionButtons,
    bool enforceQuietHours = true,
    bool useAlarmClockScheduleMode = false,
  }) async {
    // Reload settings to ensure we have the latest
    await _loadSettings();
    // Also reload habit settings when scheduling a habit notification so that
    // _resolveAndroidChannelId('habit_reminders') returns the correct
    // versioned channel (sound/vibration are baked into the channel on Android).
    if (notificationKindLabel.toLowerCase() == 'habit') {
      await _loadHabitSettings();
    }
    final settings = settingsOverride ?? _settings;

    var effectiveScheduledDate = scheduledDate;

    // Check if notifications are enabled
    if (!settings.notificationsEnabled) {
      print('NotificationService: Notifications disabled by user');
      return;
    }

    // Determine the effective channel.
    //
    // IMPORTANT:
    // We sometimes schedule "internal" silent notifications (e.g. alarm backups) with a dedicated
    // channel id. Those must NOT be force-routed to urgent_reminders, otherwise they can start
    // playing the urgent channel sound and cause double-audio alongside the native alarm.
    String effectiveChannelKey = channelKey;

    // Helper: detect whether a channel is the "normal" (non-urgent) channel
    // for either tasks or habits.
    bool isNormalChannel(String key) =>
        key == 'task_reminders' || key == 'habit_reminders';

    // Helper: detect whether a channel is urgent (task OR habit).
    bool isUrgentChannel(String key) =>
        key == 'urgent_reminders' || key == 'habit_urgent_reminders';

    // Helper: pick the correct urgent channel counterpart.
    String urgentChannelFor(String key) => key.startsWith('habit_')
        ? 'habit_urgent_reminders'
        : 'urgent_reminders';

    // Only auto-upgrade to urgent channel when the caller is using the normal
    // task/habit channel.  If the caller explicitly picked a channel (silent /
    // alarm backups), we respect it.
    if (isSpecial &&
        settings.alwaysUseAlarmForSpecialTasks &&
        isNormalChannel(channelKey)) {
      effectiveChannelKey = urgentChannelFor(channelKey);
    }

    // Determine if this is an urgent notification (task OR habit urgent)
    bool isUrgent = isUrgentChannel(effectiveChannelKey);

    // Use alarm mode if enabled and appropriate
    final shouldUseAlarmMode =
        useAlarmMode ||
        (settings.alarmModeEnabled &&
            (isUrgent ||
                (priority == 'High' && settings.alarmModeForHighPriority)));

    final effectiveAudioStream =
        audioStreamOverride ??
        (shouldUseAlarmMode || isUrgentChannel(effectiveChannelKey)
            ? 'alarm'
            : 'notification');

    // If alarm mode is requested for a normal task/habit channel, upgrade to
    // the corresponding urgent channel so Android uses Alarm audio attributes.
    if (shouldUseAlarmMode && isNormalChannel(effectiveChannelKey)) {
      effectiveChannelKey = urgentChannelFor(effectiveChannelKey);
      isUrgent = true;
    }

    // Resolve to the *actual* Android channel id (versioned for task_reminders).
    final effectiveAndroidChannelId = _resolveAndroidChannelId(
      effectiveChannelKey,
    );

    // Check quiet hours at the scheduled time
    final isQuietAtScheduledTime = settings.isInQuietHoursAt(
      effectiveScheduledDate,
    );
    if (enforceQuietHours && isQuietAtScheduledTime) {
      if (isSpecial) {
        if (!settings.allowUrgentDuringQuietHours) {
          print(
            'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: In quiet hours, skipping special notification',
          );
          return;
        }
      } else {
        if (!isUrgent || !settings.allowUrgentDuringQuietHours) {
          final deferred = _nextAllowedTimeOutsideQuietHours(
            candidate: effectiveScheduledDate,
            isInQuietHours: settings.isInQuietHoursAt,
          );
          if (deferred != effectiveScheduledDate) {
            print(
              'NotificationService: Quiet hours active, deferring notification '
              'from $effectiveScheduledDate to $deferred',
            );
            effectiveScheduledDate = deferred;
          } else {
            return;
          }
        }
      }
    }

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
      effectiveScheduledDate,
      tz.local,
    );

    // Get vibration pattern based on settings
    final vibrationPattern = _getVibrationPattern(
      isUrgent ? 'long' : settings.defaultVibrationPattern,
    );

    // Determine timeout based on settings
    final timeoutAfter = settings.notificationTimeout > 0
        ? Duration(seconds: settings.notificationTimeout)
        : null;

    // Determine which sound to play
    // Priority: customSoundKey > special-task sound > channel default
    String? effectiveSoundKey =
        customSoundKey ??
        (isSpecial && settings.alwaysUseAlarmForSpecialTasks
            ? settings.specialTaskSound
            : null);
    effectiveSoundKey ??= isUrgent
        ? _effectiveSoundKeyForUrgentChannel(settings)
        : _effectiveSoundKeyForTaskChannel(settings);
    final shouldPlaySound =
        settings.soundEnabled && effectiveSoundKey != 'silent';

    // If this is our alarm-backed UI channel, force silence regardless of global toggles.
    // No special silent UI channel for regular tasks; native one-shot playback
    // (when stream != notification) uses its own foreground notification.
    const bool isAlarmUiChannel = false;

    // Determine LED color - gold for normal, red for special
    final ledColor = isSpecial
        ? const Color(0xFFE53935)
        : const Color(0xFFCDAF56);

    // Get icon bitmap for large icon (task, habit, or hub icon params)
    ByteArrayAndroidBitmap? largeIcon;
    if (task != null) {
      largeIcon = await _getTaskIconBitmap(task);
    } else if (habit != null) {
      largeIcon = await _getHabitIconBitmap(habit);
    } else if (hubIconCodePoint != null) {
      largeIcon = await _getHubIconBitmap(
        iconCodePoint: hubIconCodePoint,
        iconFontFamily: hubIconFontFamily ?? 'MaterialIcons',
        iconFontPackage: hubIconFontPackage,
        colorValue: hubColorValue ?? 0xFFCDAF56,
      );
    }

    // Decide notification style:
    // - Regular tasks with subtasks: show subtasks as list lines (smaller font)
    // - Otherwise: Big text (description/template body)
    final StyleInformation styleInformation;
    if (!isSpecial && task?.subtasks != null && task!.subtasks!.isNotEmpty) {
      final List<Subtask> items = <Subtask>[
        ...task.subtasks!.where((Subtask s) => !s.isCompleted),
        ...task.subtasks!.where((Subtask s) => s.isCompleted),
      ];
      final List<String> lines = items.take(5).map((Subtask s) {
        final prefix = s.isCompleted ? '[x] ' : '- ';
        return '$prefix${s.title}'.trim();
      }).toList();

      final summary = (task.description ?? '').trim();
      styleInformation = InboxStyleInformation(
        lines,
        contentTitle: title,
        summaryText: summary.isNotEmpty ? summary : 'Task Reminder',
      );
    } else {
      final summaryText = isSpecial
          ? 'Special $notificationKindLabel'
          : '$notificationKindLabel Reminder';
      styleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: '<b>$title</b>', // Bold for all tasks
        htmlFormatContentTitle: true, // Enable HTML for bold
        summaryText: summaryText,
        htmlFormatSummaryText: false,
      );
    }

    // Grouping key based on notification type
    final groupKeyBase = notificationKindLabel.toLowerCase() == 'habit'
        ? 'habit_reminders_group'
        : 'task_reminders_group';

    // Create Android notification details with user settings
    final androidDetails = AndroidNotificationDetails(
      effectiveAndroidChannelId,
      _getChannelName(effectiveChannelKey),
      channelDescription: isSpecial
          ? 'Special $notificationKindLabel reminder'
          : '$notificationKindLabel reminder notification',
      importance: Importance.max,
      priority: Priority.max,

      // Large icon - task icon (circular, right side)
      largeIcon: largeIcon,

      // SECURITY:
      // Never open the app full-screen for normal tasks (even high priority).
      // Full-screen intents are reserved for SPECIAL task alarms only.
      fullScreenIntent: isSpecial && shouldUseAlarmMode,

      // Category - treat as alarm for special handling when in alarm mode
      category: shouldUseAlarmMode
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,

      // Visibility - based on settings
      visibility: settings.showOnLockScreen
          ? NotificationVisibility.public
          : NotificationVisibility.private,

      // Sound - use custom sound if specified (alarm-ui channel is always silent)
      playSound: isAlarmUiChannel ? false : shouldPlaySound,
      sound: (isAlarmUiChannel || effectiveSoundKey == null)
          ? null
          : _androidSoundForKey(effectiveSoundKey),

      // Vibration pattern based on settings (alarm-ui channel is always silent)
      enableVibration: isAlarmUiChannel ? false : settings.vibrationEnabled,
      vibrationPattern: isAlarmUiChannel
          ? Int64List.fromList([0])
          : vibrationPattern,

      // LED light based on settings
      enableLights: settings.ledEnabled,
      ledColor: ledColor,
      ledOnMs: 1000,
      ledOffMs: 500,

      // Ticker text (shown in status bar briefly)
      ticker: isSpecial
          ? 'Special $notificationKindLabel: $title'
          : '$notificationKindLabel Reminder: $title',

      // Style - Inbox for subtasks, BigText otherwise
      styleInformation: styleInformation,

      // Actions: for Hub notifications use hubActionButtons only (no task/habit defaults).
      // For Task/Habit, use hubActionButtons when provided, else task/habit defaults.
      actions: _resolveNotificationActions(
        settingsOverride: settings,
        isHabit: notificationKindLabel.toLowerCase() == 'habit',
        isHubNotification: notificationKindLabel.toLowerCase() == 'hub',
        hubActionButtons: hubActionButtons,
      ),

      // Auto-cancel based on settings
      autoCancel: !settings.persistentNotifications && !shouldUseAlarmMode,
      ongoing: settings.persistentNotifications,

      // Timeout
      timeoutAfter: timeoutAfter?.inMilliseconds,

      // Show when (time)
      // Regular tasks: keep the UI clean (no scheduled "when" time line)
      // Special/alarm-like: keep timestamp
      showWhen: isSpecial || shouldUseAlarmMode,
      when: (isSpecial || shouldUseAlarmMode)
          ? effectiveScheduledDate.millisecondsSinceEpoch
          : null,

      // Color accent
      color: const Color(0xFFCDAF56),

      // Audio stream ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ ensures the notification plays on the correct volume
      // channel (notification / alarm / ring / media).
      audioAttributesUsage: _getAudioAttributesUsage(effectiveAudioStream),

      // Subtext
      subText: 'Life Manager',

      // Grouping based on settings
      groupKey: settings.groupNotifications ? groupKeyBase : null,
    );

    // iOS notification details - enhanced
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: settings.soundEnabled,
      sound: settings.soundEnabled ? 'default' : null,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final androidScheduleMode = useAlarmClockScheduleMode
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.exactAllowWhileIdle;

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      notificationDetails,
      androidScheduleMode: androidScheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒâ€šÃ‚Â² NotificationService._scheduleNotification: Successfully scheduled!',
    );
    print('   ID: $id, Time: $tzScheduledDate, AlarmMode: $shouldUseAlarmMode');

    // Track this Flutter notification for diagnostics
    final payloadParts = payload?.split('|') ?? <String>[];
    await _trackFlutterNotificationEntry({
      'id': id,
      'type': payloadParts.isNotEmpty ? payloadParts.first : 'unknown',
      'entityId': payloadParts.length >= 2 ? payloadParts[1] : '',
      'title': title,
      'body': body,
      'scheduledTimeMs': effectiveScheduledDate.millisecondsSinceEpoch,
      'channelKey': effectiveChannelKey,
      'soundKey': effectiveSoundKey ?? 'default',
      'vibrationPattern': isUrgent ? 'long' : settings.defaultVibrationPattern,
      'priority': priority,
      'isSpecial': isSpecial,
      'useAlarmMode': shouldUseAlarmMode,
      'showFullscreen': false,
      'payload': payload,
      'audioStream': effectiveAudioStream,
      'oneShot': false,
      'trackedSource': 'flutter_notification',
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Get vibration pattern based on pattern name
  /// Preview a specific vibration pattern
  Future<void> previewVibration(String patternKey) async {
    if (!_initialized) await initialize();

    final pattern = _getVibrationPattern(patternKey);
    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Previewing vibration pattern: $patternKey',
    );

    // On Android 8+, vibration is tied to the channel.
    // To ensure the preview works, we use a temporary channel and delete it after.
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    const channelId = 'preview_vibration_channel';
    if (androidPlugin != null) {
      await androidPlugin.deleteNotificationChannel(channelId);
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Vibration Preview',
      channelDescription: 'Temporary channel for vibration preview',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      vibrationPattern: pattern,
      playSound: false,
      // For Samsung/modern Android, we need to set the usage to ensure it's felt
      audioAttributesUsage: AudioAttributesUsage.notification,
    );

    await _notificationsPlugin.show(
      88888,
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒâ€šÃ‚Â³ Vibration Preview',
      'Pattern: ${patternKey.toUpperCase()}',
      NotificationDetails(android: androidDetails),
    );
  }

  /// Preview a specific notification sound
  Future<void> previewSound(String soundKey) async {
    if (!_initialized) await initialize();

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Previewing sound: $soundKey',
    );
    final sound = _androidSoundForKey(soundKey);

    // Similar to vibration, we use a temporary channel for sound preview
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    const channelId = 'preview_sound_channel';
    if (androidPlugin != null) {
      await androidPlugin.deleteNotificationChannel(channelId);
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Sound Preview',
      channelDescription: 'Temporary channel for sound preview',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: sound,
      enableVibration: false,
      audioAttributesUsage: AudioAttributesUsage.notification,
    );

    await _notificationsPlugin.show(
      99999,
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã‚Â½Ãƒâ€šÃ‚Âµ Sound Preview',
      'Tone: ${soundKey.toUpperCase()}',
      NotificationDetails(android: androidDetails),
    );
  }

  Int64List _getVibrationPattern(String patternName) {
    switch (patternName) {
      case 'short':
        return Int64List.fromList([0, 200, 100, 200]);
      case 'long':
        return Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]);
      case 'pulse':
        return Int64List.fromList([
          0,
          100,
          100,
          100,
          100,
          100,
          100,
          100,
          100,
          100,
        ]);
      case 'silent':
        return Int64List.fromList([0]);
      case 'default':
      default:
        return Int64List.fromList([0, 500, 200, 500, 200, 500]);
    }
  }

  /// Schedule a notification for a habit
  Future<void> scheduleHabitReminder({
    required Habit habit,
    required Reminder reminder,
    DateTime? scheduledDate,
    String? channelKeyOverride,
    String? audioStreamOverride,
    String sourceFlow = 'habit_runtime',
  }) async {
    if (!_initialized) await initialize();
    if (!reminder.enabled) return;

    final policy = await NotificationModulePolicy.read(
      NotificationHubModuleIds.habit,
    );
    if (!policy.enabled) {
      NotificationFlowTrace.log(
        event: 'legacy_schedule_skipped',
        sourceFlow: sourceFlow,
        moduleId: NotificationHubModuleIds.habit,
        entityId: habit.id,
        reason: policy.reason,
      );
      return;
    }

    // Reload habit settings
    await _loadHabitSettings();
    final habitSettings = _habitSettings;
    final habitSettingsAsTask = _notificationSettingsForHabits();

    // If scheduledDate is not provided, use today's occurrence
    final baseDate = scheduledDate ?? DateTime.now();
    final DateTime? habitDueDateTime = _getHabitDueDateTime(habit, baseDate);

    if (habitDueDateTime == null) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Habit has no due time',
      );
      return;
    }

    final DateTime? reminderTime = reminder.calculateReminderTime(
      habitDueDateTime,
    );
    if (reminderTime == null) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Could not calculate habit reminder time',
      );
      return;
    }

    var effectiveReminderTime = reminderTime;
    final now = DateTime.now();
    if (reminderTime.isBefore(now)) {
      // Editing around the exact trigger minute can put reminderTime a few
      // seconds behind now. Grace that case instead of dropping the reminder.
      final lag = now.difference(reminderTime);
      if (lag <= const Duration(minutes: 1)) {
        effectiveReminderTime = now.add(const Duration(seconds: 5));
      } else {
        print(
          'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â NotificationService: Habit reminder time is in the past: $reminderTime',
        );
        return;
      }
    }

    final isSpecialHabit = habit.isSpecial;
    final useSpecialAlertRouting =
        isSpecialHabit &&
        (habitSettings.alwaysUseAlarmForSpecialHabits ||
            habitSettings.specialHabitAlarmMode);
    final effectiveChannelKey =
        channelKeyOverride ??
        (useSpecialAlertRouting
            ? 'habit_urgent_reminders'
            : habitSettings.defaultChannel);
    final effectiveAudioStream =
        audioStreamOverride ?? habitSettings.notificationAudioStream;
    final isQuietAtReminderTime = habitSettings.isInQuietHoursAt(
      effectiveReminderTime,
    );
    if (isQuietAtReminderTime &&
        useSpecialAlertRouting &&
        !habitSettings.allowSpecialDuringQuietHours) {
      print(
        'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã¢â‚¬â„¢ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ NotificationService: Quiet hours active ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â blocking special habit alert',
      );
      return;
    }
    if (isQuietAtReminderTime && !useSpecialAlertRouting) {
      final deferred = _nextAllowedTimeOutsideQuietHours(
        candidate: effectiveReminderTime,
        isInQuietHours: habitSettings.isInQuietHoursAt,
      );
      if (deferred != effectiveReminderTime) {
        print(
          'NotificationService: Quiet hours active, deferring habit reminder '
          'from $effectiveReminderTime to $deferred',
        );
        effectiveReminderTime = deferred;
      }
    }

    final occurrenceKey = scheduledDate ?? habitDueDateTime;
    final notificationId = _generateNotificationId(
      habit.id,
      reminder,
      scheduledDate: occurrenceKey,
      moduleId: NotificationHubModuleIds.habit,
    );
    NotificationFlowTrace.log(
      event: 'legacy_schedule_request',
      sourceFlow: sourceFlow,
      moduleId: NotificationHubModuleIds.habit,
      entityId: habit.id,
      notificationId: notificationId,
      details: <String, dynamic>{
        'reminderType': reminder.type,
        'reminderValue': reminder.value,
        'reminderUnit': reminder.unit,
      },
    );
    await cancelPendingNotificationById(
      notificationId: notificationId,
      entityId: habit.id,
      logActivity: false,
    );
    final payload = _buildPayload(habit.id, reminder, isHabit: true);
    final titleTemplate = useSpecialAlertRouting
        ? habitSettings.specialHabitTitleTemplate
        : habitSettings.habitTitleTemplate;
    final bodyTemplate = useSpecialAlertRouting
        ? habitSettings.specialHabitBodyTemplate
        : habitSettings.habitBodyTemplate;
    final renderedTitle = await _renderHabitTemplate(
      titleTemplate,
      habit,
      habitDueDateTime,
      reminder,
    );
    final renderedBody = await _renderHabitTemplate(
      bodyTemplate,
      habit,
      habitDueDateTime,
      reminder,
    );
    final title = renderedTitle.isEmpty
        ? (useSpecialAlertRouting
              ? 'Special Habit: ${habit.title}'
              : habit.title)
        : renderedTitle;
    final body = renderedBody.isEmpty
        ? (reminder.type == 'at_time'
              ? 'Time for your habit!'
              : 'Reminder: ${reminder.getDescription()}')
        : renderedBody;

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificationService: Scheduling habit notification for "${habit.title}"',
    );
    print('   Habit time: $habitDueDateTime');
    print('   Reminder: ${reminder.getDescription()}');
    print('   Notification will fire at: $effectiveReminderTime');
    print('   Is Special: $isSpecialHabit');
    print('   Special Alert Routing: $useSpecialAlertRouting');
    print('   Channel: $effectiveChannelKey');
    print('   Stream: $effectiveAudioStream');

    if (useSpecialAlertRouting) {
      // Generate icon PNG for native notification (same as task flow)
      final iconBytes = await _getHabitIconPng(habit);
      final iconPngBase64 = iconBytes == null ? null : base64Encode(iconBytes);

      final success = await AlarmService().scheduleSpecialTaskAlarm(
        id: notificationId,
        title: title,
        body: body,
        scheduledTime: effectiveReminderTime,
        soundId: habitSettings.specialHabitSound,
        vibrationPatternId: habitSettings.specialHabitVibrationPattern,
        showFullscreen: habitSettings.specialHabitAlarmMode,
        payload: payload,
        iconPngBase64: iconPngBase64,
        iconCodePoint: habit.iconCodePoint,
        iconFontFamily: habit.iconFontFamily ?? 'MaterialIcons',
        iconFontPackage: habit.iconFontPackage,
      );

      if (success) {
        await _trackSpecialAlarmId(habit.id, notificationId);
        await _trackNativeAlarmEntry({
          'id': notificationId,
          'type': 'habit',
          'entityId': habit.id,
          'title': title,
          'body': body,
          'scheduledTimeMs': effectiveReminderTime.millisecondsSinceEpoch,
          'channelKey': 'habit_urgent_reminders',
          'soundKey': habitSettings.specialHabitSound,
          'vibrationPattern': habitSettings.specialHabitVibrationPattern,
          'priority': null,
          'isSpecial': true,
          'useAlarmMode': habitSettings.specialHabitAlarmMode,
          'showFullscreen': habitSettings.specialHabitAlarmMode,
          'payload': payload,
          'audioStream': 'alarm',
          'oneShot': false,
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        });
        unawaited(
          NotificationActivityLogger().logScheduled(
            moduleId: 'habit',
            entityId: habit.id,
            title: title,
            body: body,
            payload: payload,
          ),
        );
        return;
      }
    }

    // Determine sound key for custom URI check
    final habitChannelSoundKey = effectiveChannelKey == 'habit_urgent_reminders'
        ? _effectiveSoundKeyForUrgentChannel(habitSettingsAsTask)
        : _effectiveSoundKeyForTaskChannel(habitSettingsAsTask);

    final useNativePlaybackForStream =
        (effectiveAudioStream != 'notification' ||
            (effectiveAudioStream == 'notification' &&
                _isCustomSoundKey(habitChannelSoundKey))) &&
        effectiveChannelKey != 'habit_silent_reminders';
    if (useNativePlaybackForStream) {
      if (habitSettings.isInQuietHoursAt(effectiveReminderTime) &&
          !habitSettings.allowSpecialDuringQuietHours) {
        final deferred = _nextAllowedTimeOutsideQuietHours(
          candidate: effectiveReminderTime,
          isInQuietHours: habitSettings.isInQuietHoursAt,
        );
        if (deferred != effectiveReminderTime) {
          print(
            'NotificationService: Quiet hours active, deferring stream-backed '
            'habit reminder from $effectiveReminderTime to $deferred',
          );
          effectiveReminderTime = deferred;
        } else {
          return;
        }
      }

      var soundKey = habitChannelSoundKey;
      final displaySoundKey = soundKey;

      if (soundKey == 'alarm') {
        soundKey = 'content://settings/system/alarm_alert';
      } else if (soundKey == 'default') {
        soundKey = 'content://settings/system/notification_sound';
      }

      final vibrationPatternId = habitSettings.vibrationEnabled
          ? 'default'
          : 'none';

      // Generate icon PNG for native notification (same as task flow)
      final iconBytes = await _getHabitIconPng(habit);
      final iconPngBase64 = iconBytes == null ? null : base64Encode(iconBytes);

      final success = await AlarmService().scheduleSpecialTaskAlarm(
        id: notificationId,
        title: title,
        body: body,
        scheduledTime: effectiveReminderTime,
        soundId: soundKey,
        vibrationPatternId: vibrationPatternId,
        showFullscreen: false,
        audioStream: effectiveAudioStream,
        oneShot: true,
        payload: payload,
        iconPngBase64: iconPngBase64,
        iconCodePoint: habit.iconCodePoint,
        iconFontFamily: habit.iconFontFamily ?? 'MaterialIcons',
        iconFontPackage: habit.iconFontPackage,
      );

      if (success) {
        await _trackNativeAlarmEntry({
          'id': notificationId,
          'type': 'habit',
          'entityId': habit.id,
          'title': title,
          'body': body,
          'scheduledTimeMs': effectiveReminderTime.millisecondsSinceEpoch,
          'channelKey': effectiveChannelKey,
          'soundKey': displaySoundKey,
          'vibrationPattern': vibrationPatternId,
          'priority': null,
          'isSpecial': false,
          'useAlarmMode': false,
          'showFullscreen': false,
          'payload': payload,
          'audioStream': effectiveAudioStream,
          'oneShot': true,
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        });
        unawaited(
          NotificationActivityLogger().logScheduled(
            moduleId: 'habit',
            entityId: habit.id,
            title: title,
            body: body,
            payload: payload,
          ),
        );
        return;
      }
    }

    await _scheduleNotification(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: effectiveReminderTime,
      channelKey: effectiveChannelKey,
      payload: payload,
      useAlarmMode:
          useSpecialAlertRouting && habitSettings.specialHabitAlarmMode,
      isSpecial: useSpecialAlertRouting,
      customSoundKey: useSpecialAlertRouting
          ? habitSettings.specialHabitSound
          : null,
      notificationKindLabel: 'Habit',
      habit: habit,
      audioStreamOverride: effectiveAudioStream,
      settingsOverride: habitSettingsAsTask,
    );
    unawaited(
      NotificationActivityLogger().logScheduled(
        moduleId: 'habit',
        entityId: habit.id,
        title: title,
        body: body,
        payload: payload,
      ),
    );
  }

  /// Schedule multiple reminders for a habit
  Future<void> scheduleMultipleHabitReminders({
    required Habit habit,
    required List<Reminder> reminders,
    String sourceFlow = 'habit_runtime',
  }) async {
    for (final reminder in reminders) {
      await scheduleHabitReminder(
        habit: habit,
        reminder: reminder,
        sourceFlow: sourceFlow,
      );
    }
  }

  /// Get task due date/time as DateTime
  DateTime? _getTaskDueDateTime(Task task) {
    if (task.dueTime != null) {
      return DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
        task.dueTime!.hour,
        task.dueTime!.minute,
      );
    }
    // If no time specified, default to the morning reminder hour from settings
    return DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
      _settings.earlyMorningReminderHour,
      0,
    );
  }

  /// Get habit due date/time as DateTime for a specific day
  DateTime? _getHabitDueDateTime(Habit habit, DateTime date) {
    // For time-based habits, use habitTimeMinutes
    if (habit.hasSpecificTime && habit.habitTimeMinutes != null) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        habit.habitTimeMinutes! ~/ 60,
        habit.habitTimeMinutes! % 60,
      );
    }
    // For all-day habits, use a default time (morning hour from settings) if reminders are enabled
    // This allows anytime habits to still have optional reminders
    if (habit.reminderEnabled && habit.reminderMinutes != null) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        habit.reminderMinutes! ~/ 60,
        habit.reminderMinutes! % 60,
      );
    }
    return null;
  }

  /// Generate unique notification ID
  int _generateNotificationId(
    String id,
    Reminder reminder, {
    DateTime? scheduledDate,
    String moduleId = NotificationHubModuleIds.task,
  }) {
    // IMPORTANT: must be unique across multiple reminders for the same task.
    // For custom reminders, include the absolute timestamp.
    // For relative reminders, include type/value/unit.
    final customMs = reminder.customDateTime?.millisecondsSinceEpoch;
    final base = customMs != null
        ? '$id-${reminder.type}-custom-$customMs'
        : '$id-${reminder.type}-${reminder.value}-${reminder.unit}';
    final dateKey = scheduledDate == null
        ? null
        : '${scheduledDate.year.toString().padLeft(4, '0')}'
              '${scheduledDate.month.toString().padLeft(2, '0')}'
              '${scheduledDate.day.toString().padLeft(2, '0')}';
    final combined = dateKey == null ? base : '$base-$dateKey';
    final hash = combined.hashCode.abs();

    // Keep task/habit IDs inside their reserved Hub ranges so retries,
    // diagnostics, and source resolution remain deterministic.
    final int rangeStart;
    final int rangeSize;
    if (moduleId == NotificationHubModuleIds.habit) {
      rangeStart = NotificationHubIdRanges.habitStart;
      rangeSize =
          NotificationHubIdRanges.habitEnd -
          NotificationHubIdRanges.habitStart +
          1;
    } else if (moduleId == NotificationHubModuleIds.task) {
      rangeStart = NotificationHubIdRanges.taskStart;
      rangeSize =
          NotificationHubIdRanges.taskEnd -
          NotificationHubIdRanges.taskStart +
          1;
    } else {
      return hash % 2147483647;
    }

    return rangeStart + (hash % rangeSize);
  }

  /// Build notification body
  String _buildNotificationBody(Task task, Reminder reminder) {
    final description = reminder.getDescription();

    // Add progress info if enabled
    if (_settings.showProgressInNotification &&
        task.subtasks != null &&
        task.subtasks!.isNotEmpty) {
      final completedCount = task.subtasks!.where((s) => s.isCompleted).length;
      final totalCount = task.subtasks!.length;
      final progressText = '$completedCount/$totalCount subtasks done';

      if (task.description != null && task.description!.isNotEmpty) {
        return '$description - ${task.description} ($progressText)';
      }
      return '$description ($progressText)';
    }

    if (task.description != null && task.description!.isNotEmpty) {
      return '$description - ${task.description}';
    }
    return description;
  }

  /// Build payload for notification action handling
  String _buildPayload(String id, Reminder reminder, {bool isHabit = false}) {
    final prefix = isHabit ? 'habit' : 'task';
    // Include custom timestamp for uniqueness (allows multiple custom reminders per task).
    final customMs = reminder.customDateTime?.millisecondsSinceEpoch;
    if (customMs != null) {
      return '$prefix|$id|${reminder.type}|$customMs|ms';
    }
    return '$prefix|$id|${reminder.type}|${reminder.value}|${reminder.unit}';
  }

  /// Get channel name from key
  String _getChannelName(String channelKey) {
    switch (channelKey) {
      case 'urgent_reminders':
        return 'Urgent Reminders';
      case 'silent_reminders':
        return 'Silent Reminders';
      case 'habit_reminders':
        return 'Habit Reminders';
      case 'habit_urgent_reminders':
        return 'Habit Urgent Reminders';
      case 'habit_silent_reminders':
        return 'Habit Silent Reminders';
      default:
        return 'Task Reminders';
    }
  }

  /// Resolve notification actions: use hub-provided when available,
  /// otherwise task/habit defaults. Android allows max 3 actions.
  /// For Hub notifications, never fall back to task/habit defaults.
  List<AndroidNotificationAction> _resolveNotificationActions({
    NotificationSettings? settingsOverride,
    bool isHabit = false,
    bool isHubNotification = false,
    List<HubNotificationAction>? hubActionButtons,
  }) {
    if (isHubNotification && hubActionButtons != null) {
      // Hub notifications: use exactly what we're given (empty = no actions)
      final take = hubActionButtons.length > 3 ? 3 : hubActionButtons.length;
      return hubActionButtons
          .take(take)
          .map(
            (a) => AndroidNotificationAction(
              a.actionId,
              _normalizeActionLabel(actionId: a.actionId, label: a.label),
              showsUserInterface: a.showsUserInterface,
              cancelNotification: a.cancelNotification,
            ),
          )
          .toList();
    }
    if (hubActionButtons != null && hubActionButtons.isNotEmpty) {
      final take = hubActionButtons.length > 3 ? 3 : hubActionButtons.length;
      return hubActionButtons
          .take(take)
          .map(
            (a) => AndroidNotificationAction(
              a.actionId,
              _normalizeActionLabel(actionId: a.actionId, label: a.label),
              showsUserInterface: a.showsUserInterface,
              cancelNotification: a.cancelNotification,
            ),
          )
          .toList();
    }
    return _getNotificationActions(
      settingsOverride: settingsOverride,
      isHabit: isHabit,
    );
  }

  String _normalizeActionLabel({
    required String actionId,
    required String label,
  }) {
    final cleaned = label
        .replaceAll('\u00E2\u20AC\u00A2', ' - ')
        .replaceAll('\u2022', ' - ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceFirst(RegExp(r'^[^A-Za-z0-9]+'), '')
        .trim();

    switch (actionId) {
      case 'mark_done':
      case 'done':
        return 'Done';
      case 'skip':
        return 'Skip';
      case 'view':
      case 'open':
        return 'View';
      case 'snooze_5':
        return 'Snooze 5m';
      default:
        return cleaned.isEmpty ? 'Action' : cleaned;
    }
  }

  /// Get notification actions with snooze duration from settings
  List<AndroidNotificationAction> _getNotificationActions({
    NotificationSettings? settingsOverride,
    bool isHabit = false,
  }) {
    final settings = settingsOverride ?? _settings;
    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Habit actions: exactly 3 buttons to match native Kotlin builder ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    // [Done, Snooze 5m, Skip]. A 4th button causes Android to hide "Skip".
    if (isHabit) {
      return const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'mark_done',
          'Done',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze_5',
          'Snooze 5m',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'skip',
          'Skip',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ];
    }
    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Task actions: existing logic with optional Snooze-5m shortcut ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    final snoozeDuration = settings.defaultSnoozeDuration;
    final snoozeLabel = snoozeDuration < 60
        ? 'Snooze ${snoozeDuration}m'
        : 'Snooze ${snoozeDuration ~/ 60}h';

    // Professional UX: provide a quick 5-minute snooze option if configured,
    // so users donÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢t rely on AndroidÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢s system-level snooze (which we canÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢t track).
    final snoozeOptions = (settings.snoozeOptions.toSet().toList()..sort());
    final hasFive = snoozeOptions.contains(5);
    final addFiveShortcut = hasFive && snoozeDuration != 5;

    return <AndroidNotificationAction>[
      const AndroidNotificationAction(
        'mark_done',
        'Done',
        // Don't show UI - handle completion in background
        showsUserInterface: false,
        cancelNotification: true,
      ),
      if (addFiveShortcut)
        const AndroidNotificationAction(
          'snooze_5',
          'Snooze 5m',
          // Don't show UI - reschedule notification in background
          showsUserInterface: false,
          cancelNotification: true,
        ),
      AndroidNotificationAction(
        'snooze',
        snoozeLabel,
        // Don't show UI - reschedule notification in background
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];
  }

  /// Get all pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) await initialize();
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Get detailed information about all pending notifications
  ///
  /// Returns a list of [PendingNotificationInfo] objects containing the full
  /// notification "journey" - schedule, quiet hours, channel, and build details.
  /// This is useful for diagnostics and debugging notification issues.
  Future<List<PendingNotificationInfo>>
  getDetailedPendingNotifications() async {
    if (!_initialized) await initialize();
    await _loadSettings();
    await _loadHabitSettings();
    final habitSettingsAsTask = _notificationSettingsForHabits();

    final pending = await _notificationsPlugin.pendingNotificationRequests();
    final results = <PendingNotificationInfo>[];

    // Get task repository for looking up task details
    final taskRepo = TaskRepository();
    final allTasks = await taskRepo.getAllTasks();
    final taskMap = {for (final t in allTasks) t.id: t};

    final habitRepo = HabitRepository();
    final allHabits = await habitRepo.getAllHabits(includeArchived: true);
    final habitMap = {for (final h in allHabits) h.id: h};

    // Load tracked Flutter notification entries for metadata
    await _cleanupTrackedFlutterNotificationEntries();
    final trackedFlutter = await _getTrackedFlutterNotificationEntries();
    final trackedFlutterMap = {
      for (final e in trackedFlutter) (e['id'] as num?)?.toInt(): e,
    };

    for (final req in pending) {
      final payload = req.payload ?? '';

      // Check if we have tracked metadata for this notification
      final trackedEntry = trackedFlutterMap[req.id];

      // If we have tracked metadata, use it (includes scheduled time)
      if (trackedEntry != null) {
        final entryType = trackedEntry['type'] as String?;
        final useHabitSettings = entryType == 'habit';
        final trackedInfo = PendingNotificationInfo.fromTrackedAlarmEntry(
          entry: trackedEntry,
          settings: useHabitSettings ? habitSettingsAsTask : _settings,
        );
        results.add(trackedInfo);
        continue;
      }

      // Fallback: parse from task data (may have unknown fire time)
      // Parse entity ID from payload
      String? entityId;
      String type = 'unknown';
      final parts = payload.split('|');
      if (parts.length >= 2) {
        type = parts[0];
        entityId = parts[1];
      }

      // Look up task to get priority, isSpecial, due time
      Task? task;
      Habit? habit;
      if (entityId != null && type == 'task' && taskMap.containsKey(entityId)) {
        task = taskMap[entityId];
      }
      if (entityId != null &&
          type == 'habit' &&
          habitMap.containsKey(entityId)) {
        habit = habitMap[entityId];
      }

      // Calculate task due time if available
      DateTime? taskDueDateTime;
      if (task != null) {
        if (task.dueTime != null) {
          taskDueDateTime = DateTime(
            task.dueDate.year,
            task.dueDate.month,
            task.dueDate.day,
            task.dueTime!.hour,
            task.dueTime!.minute,
          );
        } else {
          taskDueDateTime = DateTime(
            task.dueDate.year,
            task.dueDate.month,
            task.dueDate.day,
            _settings.earlyMorningReminderHour,
            0,
          );
        }
      }

      DateTime? habitDueDateTime;
      if (habit != null) {
        habitDueDateTime = _getHabitDueDateTime(habit, DateTime.now());
      }

      final settingsForInfo = type == 'habit' ? habitSettingsAsTask : _settings;

      final info = PendingNotificationInfo.fromPendingRequest(
        id: req.id,
        title: req.title,
        body: req.body,
        payload: payload,
        quietHoursEnabled: settingsForInfo.quietHoursEnabled,
        isCurrentlyInQuietHours: settingsForInfo.isInQuietHours(),
        allowUrgentDuringQuietHours:
            settingsForInfo.allowUrgentDuringQuietHours,
        defaultChannel: settingsForInfo.defaultChannel,
        defaultSound: settingsForInfo.taskRemindersSound,
        defaultVibration: settingsForInfo.defaultVibrationPattern,
        alarmModeEnabled: settingsForInfo.alarmModeEnabled,
        audioStream: settingsForInfo.notificationAudioStream,
        isQuietAtScheduledTime: null,
        taskPriority: task?.priority,
        taskIsSpecial: type == 'habit' ? habit?.isSpecial : task?.isSpecial,
        taskDueDateTime: type == 'habit' ? habitDueDateTime : taskDueDateTime,
      );

      results.add(info);
    }

    // Include tracked native alarms (AlarmService-only schedules)
    await _cleanupTrackedNativeAlarmEntries();
    final tracked = await _getTrackedNativeAlarmEntries();
    final existingIds = results.map((e) => e.id).toSet();

    for (final entry in tracked) {
      final id = (entry['id'] as num?)?.toInt();
      if (id == null || existingIds.contains(id)) continue;
      final entryType = entry['type'] as String?;
      final useHabitSettings = entryType == 'habit';
      results.add(
        PendingNotificationInfo.fromTrackedAlarmEntry(
          entry: entry,
          settings: useHabitSettings ? habitSettingsAsTask : _settings,
        ),
      );
    }

    // Sort by fire time (if available), then by ID
    results.sort((a, b) {
      if (a.willFireAt != null && b.willFireAt != null) {
        return a.willFireAt!.compareTo(b.willFireAt!);
      }
      if (a.willFireAt != null) return -1;
      if (b.willFireAt != null) return 1;
      return a.id.compareTo(b.id);
    });

    // Only keep upcoming notifications
    final now = DateTime.now();
    final upcoming = results.where((n) {
      if (n.willFireAt == null) return true;
      return !n.willFireAt!.isBefore(now);
    }).toList();

    return upcoming;
  }

  /// Fire a notification EXACTLY as it would fire when scheduled
  ///
  /// This fires the real notification using the same exact code path as scheduled
  /// notifications. No "test" markers - this IS the real notification, just fired
  /// early for testing purposes.
  ///
  /// [channelOverride] - Optional: Test with a different channel to compare behavior
  /// [soundOverride] - Optional: Test with a different sound
  /// [delaySeconds] - Optional: Delay before firing (for testing app killed/locked scenarios)
  Future<void> fireNotificationNow({
    required PendingNotificationInfo info,
    String? channelOverride,
    String? soundOverride,
    int delaySeconds = 2,
  }) async {
    if (!_initialized) await initialize();
    await _loadSettings();
    await _loadHabitSettings();

    final settingsOverride = info.type == 'habit'
        ? _notificationSettingsForHabits()
        : null;
    final notificationKindLabel = info.type == 'habit' ? 'Habit' : 'Task';

    final effectiveChannel = channelOverride ?? info.channelKey;
    final effectiveSound = soundOverride ?? info.soundKey;

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Firing REAL notification in $delaySeconds seconds: ${info.title}',
    );
    print('   ID: ${info.id}');
    print('   Delay: $delaySeconds seconds');
    print('   Channel: $effectiveChannel (original: ${info.channelKey})');
    print('   Sound: $effectiveSound (original: ${info.soundKey})');
    print('   Is Special: ${info.isSpecial}');
    print('   Alarm Mode: ${info.useAlarmMode}');

    // Get task or habit for icon and full details
    Task? task;
    Habit? habit;
    if (info.type == 'task' && info.entityId.isNotEmpty) {
      try {
        final taskRepo = TaskRepository();
        task = await taskRepo.getTaskById(info.entityId);
      } catch (e) {
        print(
          'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Could not load task: $e',
        );
      }
    }
    if (info.type == 'habit' && info.entityId.isNotEmpty) {
      try {
        final habitRepo = HabitRepository();
        habit = await habitRepo.getHabitById(info.entityId);
      } catch (e) {
        print(
          'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Could not load habit: $e',
        );
      }
    }

    // Determine if we should use AlarmService (special tasks, alarm-mode, or non-notification stream)
    final trackedSource = info.metadata['trackedSource'] as String?;
    final oneShot = info.metadata['oneShot'] == true;
    final effectiveAudioStream =
        (effectiveChannel == 'urgent_reminders' ||
            effectiveChannel == 'habit_urgent_reminders')
        ? 'alarm'
        : info.audioStream;
    final useAlarmService =
        info.isSpecial ||
        (info.useAlarmMode &&
            (effectiveChannel == 'urgent_reminders' ||
                effectiveChannel == 'habit_urgent_reminders')) ||
        effectiveAudioStream != 'notification' ||
        trackedSource == 'native_alarm';

    // Use at least 2 seconds delay for AlarmService (Android requirement)
    final effectiveDelay = delaySeconds < 2 ? 2 : delaySeconds;

    if (useAlarmService) {
      // Use AlarmService - same as real special task
      // Normalize sound ID for native playback
      var alarmSoundId = effectiveSound;
      if (alarmSoundId == 'alarm') {
        alarmSoundId = 'content://settings/system/alarm_alert';
      } else if (alarmSoundId == 'default') {
        alarmSoundId = 'content://settings/system/notification_sound';
      }

      final success = await AlarmService().scheduleSpecialTaskAlarm(
        id: DateTime.now().millisecondsSinceEpoch % 2147483647,
        title: info.title,
        body: info.body,
        scheduledTime: DateTime.now().add(Duration(seconds: effectiveDelay)),
        soundId: alarmSoundId,
        vibrationPatternId: info.vibrationPattern,
        showFullscreen: info.useFullScreenIntent,
        audioStream: effectiveAudioStream ?? _settings.notificationAudioStream,
        oneShot: oneShot,
        iconCodePoint: task?.iconCodePoint ?? habit?.iconCodePoint,
        iconFontFamily:
            task?.iconFontFamily ?? habit?.iconFontFamily ?? 'MaterialIcons',
        iconFontPackage: task?.iconFontPackage ?? habit?.iconFontPackage,
      );

      if (success) {
        print(
          'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ Real notification scheduled via AlarmService (fires in $effectiveDelay seconds)',
        );
      } else {
        print(
          'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â AlarmService failed, using standard notification',
        );
        await _fireStandardNotificationNow(
          info: info,
          task: task,
          habit: habit,
          channelKey: effectiveChannel,
          soundKey: effectiveSound,
          delaySeconds: effectiveDelay,
          settingsOverride: settingsOverride,
          notificationKindLabel: notificationKindLabel,
        );
      }
    } else {
      // Use standard notification - schedule for specified delay
      await _fireStandardNotificationNow(
        info: info,
        task: task,
        habit: habit,
        channelKey: effectiveChannel,
        soundKey: effectiveSound,
        delaySeconds: effectiveDelay,
        settingsOverride: settingsOverride,
        notificationKindLabel: notificationKindLabel,
      );
    }
  }

  /// Internal: Fire a standard notification after specified delay (exactly like scheduled)
  Future<void> _fireStandardNotificationNow({
    required PendingNotificationInfo info,
    Task? task,
    Habit? habit,
    required String channelKey,
    required String soundKey,
    int delaySeconds = 2,
    NotificationSettings? settingsOverride,
    String notificationKindLabel = 'Task',
  }) async {
    // Schedule for specified delay from now - this uses the EXACT same code path
    // as a real scheduled notification
    final fireTime = DateTime.now().add(Duration(seconds: delaySeconds));

    // Use a unique ID for this test fire (don't conflict with real scheduled ones)
    final testId = DateTime.now().millisecondsSinceEpoch % 2147483647;

    // Call the SAME internal method used for real notifications
    await _scheduleNotification(
      id: testId,
      title: info.title,
      body: info.body,
      scheduledDate: fireTime,
      channelKey: channelKey,
      payload: info.payload,
      useAlarmMode: info.useAlarmMode,
      priority: info.priority,
      isSpecial: info.isSpecial,
      customSoundKey: soundKey != 'default' ? soundKey : null,
      task: task,
      habit: habit,
      notificationKindLabel: notificationKindLabel,
      settingsOverride: settingsOverride,
    );

    print(
      'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ Real notification scheduled (fires in $delaySeconds seconds)',
    );
  }

  /// Get list of available channels for testing (from actual settings)
  List<Map<String, String>> getAvailableChannels() {
    // Use the actual channels defined in NotificationSettings
    return NotificationSettings.availableChannels
        .map(
          (key) => {
            'key': key,
            'name': NotificationSettings.getChannelDisplayName(key),
          },
        )
        .toList();
  }

  /// Get list of available sounds for testing (from actual settings)
  /// Includes the user's configured sounds for each channel
  Future<List<Map<String, String>>> getAvailableSoundsAsync() async {
    await _loadSettings();

    final sounds = <Map<String, String>>[];

    // Add the basic sounds
    for (final key in NotificationSettings.availableSounds) {
      sounds.add({
        'key': key,
        'name': NotificationSettings.getSoundDisplayName(key),
      });
    }

    // Add user's configured channel sounds if they're custom
    final userSounds = [
      _settings.taskRemindersSound,
      _settings.urgentRemindersSound,
      _settings.specialTaskSound,
    ];

    for (final sound in userSounds) {
      // Only add if it's a custom sound (not already in basic sounds)
      if (!NotificationSettings.availableSounds.contains(sound) &&
          sound.isNotEmpty &&
          !sounds.any((s) => s['key'] == sound)) {
        sounds.add({
          'key': sound,
          'name': NotificationSettings.getSoundDisplayName(sound),
        });
      }
    }

    return sounds;
  }

  /// Synchronous version for initial load (uses cached settings)
  List<Map<String, String>> getAvailableSounds() {
    final sounds = <Map<String, String>>[];

    // Add the basic sounds
    for (final key in NotificationSettings.availableSounds) {
      sounds.add({
        'key': key,
        'name': NotificationSettings.getSoundDisplayName(key),
      });
    }

    return sounds;
  }

  /// Finds the next time outside quiet hours using a bounded step scan.
  DateTime _nextAllowedTimeOutsideQuietHours({
    required DateTime candidate,
    required bool Function(DateTime time) isInQuietHours,
    Duration step = const Duration(minutes: 15),
    int maxSteps = 7 * 24 * 4, // up to 7 days at 15-minute increments
  }) {
    var next = candidate;
    for (var i = 0; i < maxSteps; i++) {
      if (!isInQuietHours(next)) {
        return next;
      }
      next = next.add(step);
    }
    return candidate;
  }

  DateTime? _applyHubQuietHoursPolicy({
    required DateTime scheduledAt,
    required NotificationSettings settings,
    required bool bypassQuietHours,
  }) {
    if (!settings.isInQuietHoursAt(scheduledAt)) {
      return scheduledAt;
    }

    final allowDeliveryNow =
        settings.allowUrgentDuringQuietHours || bypassQuietHours;
    if (allowDeliveryNow) {
      return scheduledAt;
    }

    final deferred = _nextAllowedTimeOutsideQuietHours(
      candidate: scheduledAt,
      isInQuietHours: settings.isInQuietHoursAt,
    );
    if (deferred == scheduledAt) {
      return null;
    }
    return deferred;
  }

  @visibleForTesting
  DateTime? resolveHubQuietHoursScheduledAtForTest({
    required DateTime scheduledAt,
    required NotificationSettings settings,
    required bool bypassQuietHours,
  }) {
    return _applyHubQuietHoursPolicy(
      scheduledAt: scheduledAt,
      settings: settings,
      bypassQuietHours: bypassQuietHours,
    );
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (!_initialized) await initialize();
    await _notificationsPlugin.cancelAll();
  }

  /// Performs a deep cancellation of all currently pending notifications.
  ///
  /// Unlike [cancelAllNotifications], this routes through
  /// [cancelPendingNotificationById] so native alarm IDs, backup-ID pairs, and
  /// tracked metadata are cleaned consistently.
  ///
  /// Returns the number of unique pending notification IDs observed before
  /// cleanup.
  Future<int> cancelAllPendingNotificationsDeep({
    bool logActivity = false,
  }) async {
    if (!_initialized) await initialize();

    final pending = await getDetailedPendingNotifications();
    final pendingById = <int, PendingNotificationInfo>{};
    for (final info in pending) {
      pendingById[info.id] = info;
    }

    for (final info in pendingById.values) {
      await cancelPendingNotificationById(
        notificationId: info.id,
        entityId: info.entityId,
        logActivity: logActivity,
      );
    }

    // Safety sweep in case any plugin-only entry was not represented above.
    await _notificationsPlugin.cancelAll();
    await clearAllTrackedNotificationState();

    return pendingById.length;
  }

  /// Clears all persisted notification tracking state used for diagnostics and
  /// alarm bookkeeping.
  ///
  /// This does not schedule/cancel anything by itself; pair it with
  /// [cancelAllNotifications] or targeted cancellation when doing a full reset.
  Future<void> clearAllTrackedNotificationState() async {
    if (!_initialized) await initialize();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final removable = keys.where((key) {
      return key == _prefsTrackedNativeAlarmsKey ||
          key == _prefsTrackedFlutterNotificationsKey ||
          key.startsWith(_prefsSpecialAlarmIdsPrefix);
    });
    for (final key in removable) {
      await prefs.remove(key);
    }
  }

  /// Cancel notifications whose IDs are outside known module ranges.
  ///
  /// This is a safety cleanup for stale notifications created by legacy builds
  /// before deterministic module ranges were enforced.
  Future<int> cancelOutOfRangePendingNotifications({
    String sourceFlow = 'out_of_range_cleanup',
  }) async {
    if (!_initialized) await initialize();

    final pending = await getDetailedPendingNotifications();
    var cancelled = 0;
    for (final info in pending) {
      final moduleId = NotificationLogicalKeyHelper.moduleIdFor(info);
      final entityId = NotificationLogicalKeyHelper.entityIdFor(info);
      final inKnownRange = NotificationLogicalKeyHelper.isInKnownRange(info.id);
      final inModuleRange = NotificationLogicalKeyHelper.isInModuleRange(
        moduleId,
        info.id,
      );
      if (inKnownRange && inModuleRange) {
        continue;
      }

      await cancelPendingNotificationById(
        notificationId: info.id,
        entityId: entityId,
        logActivity: false,
      );
      cancelled++;

      NotificationFlowTrace.log(
        event: 'out_of_range_cancelled',
        sourceFlow: sourceFlow,
        moduleId: moduleId,
        entityId: entityId,
        notificationId: info.id,
        reason: inKnownRange ? 'module_range_mismatch' : 'out_of_known_range',
      );
    }

    if (cancelled > 0 && kDebugMode) {
      debugPrint(
        'NotificationService: cancelled $cancelled out-of-range pending notification(s)',
      );
    }
    return cancelled;
  }

  /// Cancel a single pending notification by ID.
  ///
  /// This cancels both plugin and native alarm paths, including the common
  /// backup-ID pattern (`id + 100000`) used by alarm-backed notifications.
  /// If [entityId] is provided, tracked special-alarm IDs are also cleaned.
  Future<void> cancelPendingNotificationById({
    required int notificationId,
    String? entityId,
    bool logActivity = true,
  }) async {
    if (!_initialized) await initialize();

    final idsToCancel = <int>{notificationId};
    if (notificationId >= 100000) {
      idsToCancel.add(notificationId - 100000);
    } else {
      idsToCancel.add(notificationId + 100000);
    }

    for (final id in idsToCancel) {
      await _notificationsPlugin.cancel(id);
      await AlarmService().cancelAlarm(id);
      await _removeTrackedNativeAlarmEntry(id);
      await _removeTrackedFlutterNotificationEntry(id);
    }

    if (entityId != null && entityId.isNotEmpty) {
      try {
        final trackedIds = await _getTrackedSpecialAlarmIds(entityId);
        final remaining = trackedIds
            .where((id) => !idsToCancel.contains(id))
            .toList();
        final prefs = await SharedPreferences.getInstance();
        final key = '$_prefsSpecialAlarmIdsPrefix$entityId';
        if (remaining.isEmpty) {
          await prefs.remove(key);
        } else {
          await prefs.setString(key, jsonEncode(remaining..sort()));
        }
      } catch (_) {
        // Best-effort cleanup.
      }
    }

    // Inform the Hub about the single-notification cancellation.
    if (logActivity && entityId != null && entityId.isNotEmpty) {
      unawaited(
        NotificationActivityLogger().logCancelled(
          moduleId: 'unknown', // caller may not know; entityId is best-effort
          entityId: entityId,
          metadata: <String, dynamic>{
            'notificationId': notificationId,
            'source': 'cancel_by_id',
          },
        ),
      );
    }

    print(
      'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â NotificationService: Cancelled pending notification IDs ${(idsToCancel.toList()..sort())}',
    );
  }

  /// Snooze a notification by scheduling a new one
  ///
  /// CRITICAL: For habits, we reload [_habitSettings] and derive the
  /// authoritative [NotificationSettings] via [_notificationSettingsForHabits]
  /// so the snoozed notification uses the **exact same** channel, sound,
  /// audio stream, and action buttons as the original.
  Future<void> snoozeNotification({
    required String taskId,
    required String title,
    required String body,
    String? payload,
    int? customDurationMinutes,
    String? priority, // Add priority parameter to enable smart snooze
    int?
    originalNotificationId, // If provided, snooze replaces that specific reminder
    NotificationSettings? settingsOverride,
    String notificationKindLabel = 'Task',
    String? channelKeyOverride,
  }) async {
    // Snooze can be triggered while the app is backgrounded/terminated.
    // Ensure plugin + timezone are initialized before scheduling.
    if (!_initialized) {
      await initialize();
    } else {
      await _loadSettings();
    }

    final bool isHabit =
        notificationKindLabel.toLowerCase() == 'habit' ||
        (payload?.startsWith('habit|') ?? false);

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Load authoritative settings ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    // For habits we MUST reload _habitSettings so that
    // _resolveAndroidChannelId('habit_reminders') produces the correct
    // versioned channel id (sound/vibration are baked into the channel).
    if (isHabit) {
      await _loadHabitSettings();
    }
    final NotificationSettings settings = isHabit
        ? _notificationSettingsForHabits()
        : (settingsOverride ?? _settings);

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Look up the original tracked notification entry ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    Map<String, dynamic>? trackedEntry;
    bool trackedIsNativeAlarm = false;
    if (originalNotificationId != null) {
      trackedEntry = await _getTrackedFlutterNotificationEntry(
        originalNotificationId,
      );
      if (trackedEntry == null || trackedEntry.isEmpty) {
        trackedEntry = await _getTrackedNativeAlarmEntry(
          originalNotificationId,
        );
        trackedIsNativeAlarm = trackedEntry != null && trackedEntry.isNotEmpty;
      }
    }

    final trackedChannelKey = trackedEntry?['channelKey'] as String?;
    final trackedSoundKey = trackedEntry?['soundKey'] as String?;
    final trackedAudioStream = trackedEntry?['audioStream'] as String?;
    final trackedOneShot = trackedEntry?['oneShot'] == true;
    final trackedIsSpecial = trackedEntry?['isSpecial'] == true;
    final trackedUseAlarmMode = trackedEntry?['useAlarmMode'] == true;
    final trackedTitle = (trackedEntry?['title'] as String?)?.trim();
    final trackedBody = (trackedEntry?['body'] as String?)?.trim();

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Parse / validate snooze count ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    int currentSnoozeCount = 0;
    if (payload != null && payload.contains('snoozeCount:')) {
      final match = RegExp(r'snoozeCount:(\d+)').firstMatch(payload);
      if (match != null) {
        currentSnoozeCount = int.parse(match.group(1)!);
      }
    }

    print(
      'ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚ÂÃƒâ€šÃ‚Â° Current snooze count: $currentSnoozeCount, Max allowed: ${settings.maxSnoozeCount}',
    );

    // Check if max snooze count reached (999 = unlimited)
    if (settings.maxSnoozeCount != 999 &&
        currentSnoozeCount >= settings.maxSnoozeCount) {
      print(
        'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Max snooze count reached ($currentSnoozeCount/${settings.maxSnoozeCount}). Cannot snooze again.',
      );
      return;
    }

    currentSnoozeCount++;

    // Update payload with new snooze count
    String updatedPayload = payload ?? '';
    if (updatedPayload.contains('snoozeCount:')) {
      updatedPayload = updatedPayload.replaceAll(
        RegExp(r'snoozeCount:\d+'),
        'snoozeCount:$currentSnoozeCount',
      );
    } else {
      updatedPayload = '$updatedPayload|snoozeCount:$currentSnoozeCount';
    }

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Determine snooze duration ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    int snoozeDuration =
        customDurationMinutes ?? settings.defaultSnoozeDuration;

    // Apply Smart Snooze: shorter snooze for high priority tasks
    if (settings.smartSnooze &&
        customDurationMinutes == null &&
        priority != null) {
      if (priority == 'High') {
        snoozeDuration = 5;
        print(
          'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚Â§Ãƒâ€šÃ‚Â  Smart Snooze: High priority ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 5 min',
        );
      } else if (priority == 'Medium') {
        snoozeDuration = 10;
        print(
          'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚Â§Ãƒâ€šÃ‚Â  Smart Snooze: Medium priority ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 10 min',
        );
      } else {
        snoozeDuration = 15;
        print(
          'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚Â§Ãƒâ€šÃ‚Â  Smart Snooze: Low priority ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 15 min',
        );
      }
    }

    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeDuration));

    // Stable fallback id when original id isn't available.
    final fallbackId =
        ((updatedPayload.isNotEmpty
                ? updatedPayload
                : 'snooze|$taskId|${snoozeTime.millisecondsSinceEpoch}')
            .hashCode
            .abs() %
        2147483647);

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Resolve title / body from tracked entry (template parity) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    final effectiveTitle = (trackedTitle != null && trackedTitle.isNotEmpty)
        ? trackedTitle
        : title;
    final effectiveBody = (trackedBody != null && trackedBody.isNotEmpty)
        ? trackedBody
        : body;
    final normalizedBody = effectiveBody
        .replaceAll(
          '\u00C3\u0083\u00C2\u00A2\u00C3\u00A2\u00E2\u201A\u00AC\u0161\u00C3\u201A\u00C2\u00A2',
          ' - ',
        )
        .replaceAll('\u00C3\u00A2\u00E2\u201A\u00AC\u00C2\u00A2', ' - ')
        .replaceAll('\u00E2\u20AC\u00A2', ' - ')
        .replaceAll('\u2022', ' - ');

    // Always include an explicit snooze line so users can see the new delay.
    final snoozeNote = snoozeDuration < 60
        ? 'Snoozed - ${snoozeDuration} min'
        : 'Snoozed - ${snoozeDuration ~/ 60} hr';
    final snoozedBody = normalizedBody.trim().isEmpty
        ? snoozeNote
        : '$normalizedBody\n$snoozeNote';

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Resolve channel / stream ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    final effectiveChannelKey =
        trackedChannelKey ?? channelKeyOverride ?? settings.defaultChannel;
    final effectiveAudioStream =
        trackedAudioStream ?? settings.notificationAudioStream;

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Load the entity ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    Task? task;
    Habit? habit;
    if (isHabit) {
      try {
        habit = await HabitRepository().getHabitById(taskId);
      } catch (_) {}
    } else {
      try {
        task = await TaskRepository().getTaskById(taskId);
      } catch (_) {}
    }

    // Carry over special / alarm-mode from the original notification,
    // or derive from the live entity.
    final bool isSpecial =
        trackedIsSpecial || (isHabit && (habit?.isSpecial ?? false));
    final bool useAlarmMode =
        trackedUseAlarmMode ||
        (isSpecial && settings.alwaysUseAlarmForSpecialTasks);

    // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Decide native vs Flutter scheduling path ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
    // 1. Primary: the original was found in the native alarm tracker.
    // 2. Tracked entry says oneShot with non-notification stream.
    // 3. Live settings say a non-notification audio stream (alarm/media/ring)
    //    or custom sound ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â replicate the same logic scheduleHabitReminder uses
    //    so snooze from the UI popup (which has no originalNotificationId)
    //    also routes through the native path.
    bool liveSettingsNeedNative = false;
    if (isHabit && effectiveChannelKey != 'habit_silent_reminders') {
      final channelSoundKey = effectiveChannelKey == 'habit_urgent_reminders'
          ? _effectiveSoundKeyForUrgentChannel(settings)
          : _effectiveSoundKeyForTaskChannel(settings);
      liveSettingsNeedNative =
          effectiveAudioStream != 'notification' ||
          (effectiveAudioStream == 'notification' &&
              _isCustomSoundKey(channelSoundKey));
    }

    final shouldUseNative =
        trackedIsNativeAlarm ||
        (trackedOneShot && effectiveAudioStream != 'notification') ||
        liveSettingsNeedNative;

    print(
      'ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚ÂÃƒâ€šÃ‚Â° snoozeNotification: isHabit=$isHabit, trackedIsNativeAlarm=$trackedIsNativeAlarm, '
      'trackedOneShot=$trackedOneShot, audioStream=$effectiveAudioStream, '
      'liveSettingsNeedNative=$liveSettingsNeedNative, shouldUseNative=$shouldUseNative, '
      'isSpecial=$isSpecial, useAlarmMode=$useAlarmMode',
    );

    if (shouldUseNative) {
      // Match original native playback path (stream + sound + actions).
      // When no tracked entry, derive the sound key from the channel the same
      // way scheduleHabitReminder / scheduleTaskReminder does.
      String soundKey;
      if (trackedSoundKey != null) {
        soundKey = trackedSoundKey;
      } else if (isHabit) {
        soundKey = effectiveChannelKey == 'habit_urgent_reminders'
            ? _effectiveSoundKeyForUrgentChannel(settings)
            : _effectiveSoundKeyForTaskChannel(settings);
      } else {
        soundKey = settings.defaultSound;
      }
      final displaySoundKey = soundKey; // for tracking (before URI transform)
      if (soundKey == 'alarm') {
        soundKey = 'content://settings/system/alarm_alert';
      } else if (soundKey == 'default') {
        soundKey = 'content://settings/system/notification_sound';
      }

      final vibrationPatternId = settings.vibrationEnabled ? 'default' : 'none';

      final iconBytes = isHabit
          ? await _getHabitIconPng(habit)
          : await _getTaskIconPng(task);
      final iconPngBase64 = iconBytes == null ? null : base64Encode(iconBytes);

      final success = await AlarmService().scheduleSpecialTaskAlarm(
        id: originalNotificationId ?? fallbackId,
        title: effectiveTitle,
        body: snoozedBody,
        scheduledTime: snoozeTime,
        soundId: soundKey,
        vibrationPatternId: vibrationPatternId,
        showFullscreen: false,
        audioStream: effectiveAudioStream,
        oneShot: true,
        payload: updatedPayload,
        iconPngBase64: iconPngBase64,
        iconCodePoint: isHabit ? habit?.iconCodePoint : task?.iconCodePoint,
        iconFontFamily: isHabit ? habit?.iconFontFamily : task?.iconFontFamily,
        iconFontPackage: isHabit
            ? habit?.iconFontPackage
            : task?.iconFontPackage,
      );

      if (success) {
        await _trackNativeAlarmEntry({
          'id': originalNotificationId ?? fallbackId,
          'type': isHabit ? 'habit' : 'task',
          'entityId': taskId,
          'title': effectiveTitle,
          'body': snoozedBody,
          'scheduledTimeMs': snoozeTime.millisecondsSinceEpoch,
          'channelKey': effectiveChannelKey,
          'soundKey': displaySoundKey, // display key (before URI transform)
          'vibrationPattern': vibrationPatternId,
          'priority': priority,
          'isSpecial': isSpecial,
          'useAlarmMode': useAlarmMode,
          'showFullscreen': false,
          'payload': updatedPayload,
          'audioStream': effectiveAudioStream,
          'oneShot': true,
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } else {
      // Flutter-scheduled notification ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ pass the same flags the original
      // scheduleHabitReminder / scheduleTaskReminder would have used.
      await _scheduleNotification(
        id: originalNotificationId ?? fallbackId,
        title: effectiveTitle,
        body: snoozedBody,
        scheduledDate: snoozeTime,
        channelKey: effectiveChannelKey,
        payload: updatedPayload,
        priority: priority,
        isSpecial: isSpecial,
        useAlarmMode: useAlarmMode,
        notificationKindLabel: notificationKindLabel,
        settingsOverride: settings,
        audioStreamOverride: effectiveAudioStream,
        customSoundKey: trackedSoundKey,
        task: task,
        habit: habit,
      );
    }

    print(
      'ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚ÂÃƒâ€šÃ‚Â° NotificationService: Snoozed notification for $snoozeDuration minutes (Count: $currentSnoozeCount/${settings.maxSnoozeCount})',
    );
  }
}
