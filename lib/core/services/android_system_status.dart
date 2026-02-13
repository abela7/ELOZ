import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only system status bridge.
///
/// We use this because Android's "Unrestricted/Optimized/Restricted" battery
/// mode does not map cleanly to `permission_handler`'s battery optimization
/// permission status across devices/OEMs.
class AndroidSystemStatus {
  static const MethodChannel _channel = MethodChannel('com.eloz.life_manager/system');

  /// Returns true if timezone/time change set a pending resync flag (and clears it).
  /// Used by NotificationRecoveryService on app startup.
  static Future<bool> getAndClearPendingNotificationResync() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('getAndClearPendingNotificationResync');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Returns a map with:
  /// - isBackgroundRestricted: bool (Android P+)
  /// - isIgnoringBatteryOptimizations: bool (Android M+)
  /// - sdkInt: int
  static Future<Map<String, dynamic>> getBatteryStatus() async {
    if (!Platform.isAndroid) {
      return <String, dynamic>{
        'isBackgroundRestricted': false,
        'isIgnoringBatteryOptimizations': true,
        'sdkInt': 0,
      };
    }

    final result = await _channel.invokeMethod<dynamic>('getBatteryStatus');
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    return <String, dynamic>{
      'isBackgroundRestricted': false,
      'isIgnoringBatteryOptimizations': false,
      'sdkInt': 0,
    };
  }

  /// Opens the app's system settings page (user can access Battery from there).
  static Future<void> openAppDetailsSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openAppDetailsSettings');
  }

  /// Opens the app's notification settings (Notifications toggle, channels).
  /// Uses ACTION_APP_NOTIFICATION_SETTINGS for direct access.
  static Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (e) {
      debugPrint('⚠️ Error opening notification settings: $e');
      await openAppDetailsSettings();
    }
  }

  /// Opens the Android system settings page for a specific notification channel.
  static Future<void> openChannelSettings(String channelId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openChannelSettings', {'channelId': channelId});
    } catch (e) {
      debugPrint('⚠️ Error opening channel settings: $e');
      // If channel settings fail, fall back to general app details
      await openAppDetailsSettings();
    }
  }

  /// Opens the native Android sound picker (notification tones) and returns:
  /// - uri: String? (content://... or null if cancelled)
  /// - title: String? (human-readable name, best-effort)
  static Future<Map<String, dynamic>> pickNotificationSound({String? currentUri}) async {
    if (!Platform.isAndroid) {
      return <String, dynamic>{'uri': null, 'title': null};
    }
    final result = await _channel.invokeMethod<dynamic>(
      'pickNotificationSound',
      <String, dynamic>{'currentUri': currentUri},
    );
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return <String, dynamic>{'uri': null, 'title': null};
  }

  /// Checks if the app has Do Not Disturb (DND) access.
  /// This is REQUIRED on many devices to bypass silent mode with alarm notifications.
  static Future<bool> hasDndAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<dynamic>('getDndAccessStatus');
      if (result is Map) {
        return result['hasAccess'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking DND access: $e');
      return false;
    }
  }

  /// Opens the system DND access settings where user can grant permission.
  static Future<void> openDndAccessSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openDndAccessSettings');
    } catch (e) {
      debugPrint('⚠️ Error opening DND settings: $e');
      await openAppDetailsSettings();
    }
  }

  /// Play an alarm sound using Android's ALARM audio stream.
  /// This BYPASSES silent mode - exactly like the Clock app alarm!
  /// 
  /// - [soundUri]: Optional content:// URI for a specific sound. If null, uses default alarm.
  /// - [vibrate]: Whether to also vibrate.
  static Future<void> playAlarmSound({String? soundUri, bool vibrate = true}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('playAlarmSound', {
        'soundUri': soundUri,
        'vibrate': vibrate,
      });
      debugPrint('🔔 Alarm sound playing on ALARM stream');
    } catch (e) {
      debugPrint('⚠️ Error playing alarm sound: $e');
    }
  }

  /// Stop the currently playing alarm sound and vibration.
  static Future<void> stopAlarmSound() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopAlarmSound');
      debugPrint('🔕 Alarm sound stopped');
    } catch (e) {
      debugPrint('⚠️ Error stopping alarm sound: $e');
    }
  }

  /// Check if the app can use full-screen intents (Android 14+).
  /// 
  /// On Android 14 (API 34+), full-screen intents for alarm-style lock screen
  /// overlays require explicit user permission. Without this, the alarm UI
  /// will NOT appear on top of the lock screen.
  static Future<bool> canUseFullScreenIntent() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('canUseFullScreenIntent');
      return result ?? true;
    } catch (e) {
      debugPrint('⚠️ Error checking canUseFullScreenIntent: $e');
      // If check fails (older API), assume granted
      return true;
    }
  }

  /// Opens the system settings to grant full-screen intent permission (Android 14+).
  /// 
  /// This opens Settings → Apps → [Your App] → Full-screen intents toggle.
  static Future<void> openFullScreenIntentSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openFullScreenIntentSettings');
    } catch (e) {
      debugPrint('⚠️ Error opening full-screen intent settings: $e');
      // Fallback to general app settings
      await openAppDetailsSettings();
    }
  }
}

