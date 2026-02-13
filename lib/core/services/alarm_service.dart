import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../models/notification_settings.dart' as app_notif;
import 'sound_player_service.dart';

/// Service for scheduling alarms that bypass silent mode and work when app is killed.
/// 
/// Uses NATIVE Android implementation that:
/// - Uses AlarmManager for reliable scheduling (even when app killed)
/// - Uses USAGE_ALARM audio stream (bypasses silent mode)
/// - Respects user's alarm volume setting (not forced to max)
/// - Uses Foreground Service for reliable playback
/// 
/// This is the correct way to implement alarms on Android - exactly how
/// the stock Clock app works.
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  static const MethodChannel _channel = MethodChannel('com.eloz.life_manager/native_alarm');
  static const String _iconStorageKey = 'alarm_icon_data_';

  bool _initialized = false;
  
  /// Callback for when alarm rings (for showing custom UI)
  /// Note: This only fires when the app is in foreground.
  /// When the app is killed, the native service handles everything.
  /// Parameters: alarmId, title, body, iconCodePoint, iconFontFamily, iconFontPackage
  Function(int alarmId, String title, String body, int? iconCodePoint, String? iconFontFamily, String? iconFontPackage)? onAlarmRing;

  /// Initialize the alarm service
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Set up method call handler to receive alarm events from native
    _channel.setMethodCallHandler(_handleMethodCall);
    
    _initialized = true;
    print('🔔 AlarmService: Initialized (Native Android implementation)');
  }

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAlarmRing':
        final alarmId = call.arguments['alarmId'] as int;
        final title = call.arguments['title'] as String;
        final body = call.arguments['body'] as String;
        print('🔔 AlarmService: Received alarm ring event from native');
        
        // Retrieve stored icon data for this alarm
        final iconData = await _getIconData(alarmId);
        onAlarmRing?.call(
          alarmId, 
          title, 
          body, 
          iconData['codePoint'] as int?,
          iconData['fontFamily'] as String?,
          iconData['fontPackage'] as String?,
        );
        
        // Clean up stored icon data
        await _clearIconData(alarmId);
        break;
      default:
        print('⚠️ AlarmService: Unknown method call: ${call.method}');
    }
  }
  
  /// Store icon data for an alarm
  Future<void> _storeIconData(int alarmId, int? codePoint, String? fontFamily, String? fontPackage) async {
    if (codePoint == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_iconStorageKey}${alarmId}_codePoint', codePoint);
    if (fontFamily != null) {
      await prefs.setString('${_iconStorageKey}${alarmId}_fontFamily', fontFamily);
    }
    if (fontPackage != null) {
      await prefs.setString('${_iconStorageKey}${alarmId}_fontPackage', fontPackage);
    }
  }
  
  /// Retrieve icon data for an alarm (private)
  Future<Map<String, dynamic>> _getIconData(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'codePoint': prefs.getInt('${_iconStorageKey}${alarmId}_codePoint'),
      'fontFamily': prefs.getString('${_iconStorageKey}${alarmId}_fontFamily'),
      'fontPackage': prefs.getString('${_iconStorageKey}${alarmId}_fontPackage'),
    };
  }
  
  /// Get stored icon data for an alarm (public API)
  Future<Map<String, dynamic>> getStoredIconData(int alarmId) async {
    return _getIconData(alarmId);
  }
  
  /// Clear stored icon data for an alarm
  Future<void> _clearIconData(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_iconStorageKey}${alarmId}_codePoint');
    await prefs.remove('${_iconStorageKey}${alarmId}_fontFamily');
    await prefs.remove('${_iconStorageKey}${alarmId}_fontPackage');
  }

  /// Schedule a special task alarm
  /// 
  /// This creates an alarm that:
  /// - Fires at the scheduled time even if app is killed
  /// - Plays on ALARM audio stream (bypasses silent mode)
  /// - Respects user's alarm volume setting (not max)
  /// - Shows full-screen notification
  /// 
  /// Uses native Android AlarmManager + Foreground Service.
  Future<bool> scheduleSpecialTaskAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    // Can be a raw resource name (e.g. "alarm") OR a content/file URI string.
    // This matches what the settings store.
    String soundId = 'alarm',
    String vibrationPatternId = 'default',
    bool showFullscreen = true,
    // NEW:
    // For non-special reminders we may want to play the sound on a different stream
    // (alarm/ring/media/notification) and optionally play only once.
    String audioStream = 'alarm',
    bool oneShot = false,
    String? payload,
    String? iconPngBase64,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    bool actionsEnabled = true,
    /// JSON array of {"actionId": "...", "label": "..."} for dynamic action buttons.
    /// When set and non-empty, native uses these instead of hardcoded task actions.
    String? actionButtonsJson,
  }) async {
    if (!_initialized) await initialize();
    
    // Don't schedule alarms in the past
    if (scheduledTime.isBefore(DateTime.now())) {
      print('⚠️ AlarmService: Cannot schedule alarm in the past');
      return false;
    }

    print('🔔 AlarmService: Scheduling special task alarm...');
    print('   ID: $id');
    print('   Title: $title');
    print('   Time: $scheduledTime');
    print('   Icon: $iconCodePoint');

    try {
      // Store icon data for retrieval when alarm fires
      await _storeIconData(id, iconCodePoint, iconFontFamily, iconFontPackage);
      
      final result = await _channel.invokeMethod<bool>('scheduleAlarm', {
        'alarmId': id,
        'triggerTimeMillis': scheduledTime.millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'soundId': soundId,
        'vibrationPatternId': vibrationPatternId,
        'showFullscreen': showFullscreen,
        'audioStream': audioStream,
        'oneShot': oneShot,
        'payload': payload,
        'iconPngBase64': iconPngBase64,
        'actionsEnabled': actionsEnabled,
        if (actionButtonsJson != null && actionButtonsJson.isNotEmpty)
          'actionButtonsJson': actionButtonsJson,
      });
      
      if (result == true) {
        print('✅ AlarmService: Scheduled alarm $id for $scheduledTime');
        print('   ✓ Uses native AlarmManager (works when app killed)');
        print('   ✓ Uses USAGE_ALARM stream (bypasses silent mode)');
        print('   ✓ Respects user alarm volume');
        print('   ✓ Icon data stored for retrieval');
        return true;
      } else {
        print('⚠️ AlarmService: Failed to schedule alarm $id');
        await _clearIconData(id); // Clean up on failure
        return false;
      }
    } catch (e) {
      print('❌ AlarmService: Error scheduling alarm: $e');
      return false;
    }
  }

  /// Schedule a test alarm (fires immediately)
  /// 
  /// This tests that the native alarm service is working correctly.
  /// 
  /// @param showFullscreen If true, shows full-screen AlarmScreen UI. If false, just notification.
  /// @param soundId The ID of the sound to play (e.g., "alarm", "sound_1", "sound_2")
  /// @param vibrationPatternId The ID of the vibration pattern (e.g., "default", "short", "pulse")
  /// @param iconCodePoint The icon code point to show in the alarm UI
  Future<bool> scheduleTestAlarm({
    required String title,
    required String body,
    bool showFullscreen = false,
    String soundId = 'alarm',
    String vibrationPatternId = 'default',
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
  }) async {
    if (!_initialized) await initialize();

    print('🔔 AlarmService: Starting test alarm (fullscreen: $showFullscreen, sound: $soundId, vibration: $vibrationPatternId)...');

    // Use a fixed test alarm ID for storing icon data
    // This must match what native side uses
    const testAlarmId = 0;
    await _storeIconData(testAlarmId, iconCodePoint, iconFontFamily, iconFontPackage);

    try {
      final result = await _channel.invokeMethod<bool>('playTestAlarm', {
        'alarmId': testAlarmId,
        'title': title,
        'body': body,
        'showFullscreen': showFullscreen,
        'soundId': soundId,
        'vibrationPatternId': vibrationPatternId,
      });
      
      if (result == true) {
        print('✅ AlarmService: Test alarm started');
        print('   ✓ Should play on ALARM stream');
        print('   ✓ Should use your alarm volume setting');
        return true;
      } else {
        print('⚠️ AlarmService: Failed to start test alarm');
        return await _fallbackTestAlarm(title: title, body: body);
      }
    } catch (e) {
      print('⚠️ AlarmService: Error starting test alarm: $e');
      return await _fallbackTestAlarm(title: title, body: body);
    }
  }
  
  /// Fallback when native fails - use SoundPlayerService
  Future<bool> _fallbackTestAlarm({
    required String title,
    required String body,
  }) async {
    print('🔔 AlarmService: Using fallback alarm');
    
    // Immediate vibration
    Vibration.vibrate(duration: 1000);
    
    // Play sound using SoundPlayerService
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('notification_settings');
      String soundKey = 'content://settings/system/alarm_alert';
      
      if (jsonString != null) {
        final settings = app_notif.NotificationSettings.fromJsonString(jsonString);
        soundKey = settings.specialTaskSound;
      }
      
      await SoundPlayerService().playSound(
        stream: 'alarm',
        soundKey: soundKey,
      );
    } catch (e) {
      print('⚠️ Fallback sound error: $e');
    }
    
    return true;
  }

  /// Cancel all native alarms whose payload matches the given entity.
  /// Use when deleting a habit/task to clear alarms in AlarmBootReceiver
  /// storage (Android has no API to list AlarmManager alarms; we must
  /// cancel by scanning our own persistence).
  Future<int> cancelAlarmsForEntity(String type, String entityId) async {
    if (entityId.isEmpty) return 0;
    try {
      final alarms = await getScheduledAlarmsFromNative();
      var cancelled = 0;
      final prefix = '$type|$entityId|';
      for (final alarm in alarms) {
        final payload = alarm['payload'] as String? ?? '';
        if (payload.startsWith(prefix) || payload == '$type|$entityId') {
          final id = (alarm['id'] as num?)?.toInt();
          if (id != null) {
            await cancelAlarm(id);
            cancelled++;
          }
        }
      }
      return cancelled;
    } catch (e) {
      print('⚠️ AlarmService: Error cancelling alarms for $type/$entityId: $e');
      return 0;
    }
  }

  /// Get alarms scheduled in native storage (for reboot restoration).
  /// Android AlarmManager has no public API to list alarms; we read our own
  /// persistence. Use this for orphan detection (alarms for deleted entities).
  Future<List<Map<String, dynamic>>> getScheduledAlarmsFromNative() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getScheduledAlarms');
      if (result == null) return [];
      return result
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      print('⚠️ AlarmService: Error getting scheduled alarms: $e');
      return [];
    }
  }

  /// Cancel a specific alarm
  Future<bool> cancelAlarm(int id) async {
    try {
      final result = await _channel.invokeMethod<bool>('cancelAlarm', {
        'alarmId': id,
      });
      print('🔔 AlarmService: Cancelled alarm $id: $result');
      return result ?? false;
    } catch (e) {
      print('⚠️ AlarmService: Error cancelling alarm: $e');
      return false;
    }
  }

  /// Cancel all alarms
  Future<void> cancelAllAlarms() async {
    // Note: This would require tracking all scheduled IDs
    // For now, we don't have a native implementation of this
    print('🔔 AlarmService: cancelAllAlarms not implemented in native');
  }

  /// Check if an alarm is currently ringing/playing
  Future<bool> isRinging(int id) async {
    try {
      final result = await _channel.invokeMethod<bool>('isAlarmPlaying');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Get information about the currently ringing alarm
  /// Returns null if no alarm is ringing, or a map with alarmId, title, body
  Future<Map<String, dynamic>?> getCurrentRingingAlarm() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getCurrentRingingAlarm');
      if (result == null) return null;
      
      return {
        'alarmId': result['alarmId'] as int?,
        'title': result['title'] as String?,
        'body': result['body'] as String?,
      };
    } catch (e) {
      print('⚠️ AlarmService: Error getting current ringing alarm: $e');
      return null;
    }
  }

  /// Stop the currently ringing alarm
  Future<bool> stopRinging(int id) async {
    try {
      final result = await _channel.invokeMethod<bool>('stopAlarm');
      print('🔔 AlarmService: Stopped alarm: $result');
      return result ?? false;
    } catch (e) {
      print('⚠️ AlarmService: Error stopping alarm: $e');
      return false;
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    // No resources to dispose in native implementation
  }
}
