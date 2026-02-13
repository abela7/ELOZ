import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hub_module_notification_settings.dart';

class NotificationHubModuleSettingsStore {
  static const String _settingsKey = 'notification_hub_module_settings_v1';
  static const String _moduleSettingsPrefix =
      'notification_hub_module_settings_v1_';

  // ---------------------------------------------------------------------------
  // Module enabled states (existing)
  // ---------------------------------------------------------------------------

  Future<Map<String, bool>> loadEnabledStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_settingsKey) ?? '').trim();
      if (raw.isEmpty) {
        return <String, bool>{};
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, bool>{};
      }

      final result = <String, bool>{};
      decoded.forEach((key, value) {
        if (key.isEmpty || value is! bool) {
          return;
        }
        result[key] = value;
      });
      return result;
    } catch (_) {
      return <String, bool>{};
    }
  }

  Future<void> saveEnabledStates(Map<String, bool> states) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(states));
  }

  // ---------------------------------------------------------------------------
  // Per-module notification settings (new)
  // ---------------------------------------------------------------------------

  /// Loads notification-specific overrides for [moduleId].
  ///
  /// Returns [HubModuleNotificationSettings.empty] when nothing is stored.
  Future<HubModuleNotificationSettings> loadModuleSettings(
    String moduleId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          (prefs.getString('$_moduleSettingsPrefix$moduleId') ?? '').trim();
      if (raw.isEmpty) {
        return HubModuleNotificationSettings.empty;
      }
      return HubModuleNotificationSettings.fromJsonString(raw);
    } catch (_) {
      return HubModuleNotificationSettings.empty;
    }
  }

  /// Persists notification-specific overrides for [moduleId].
  Future<void> saveModuleSettings(
    String moduleId,
    HubModuleNotificationSettings settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_moduleSettingsPrefix$moduleId',
      settings.toJsonString(),
    );
  }

  /// Removes all module-specific overrides for [moduleId].
  Future<void> clearModuleSettings(String moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_moduleSettingsPrefix$moduleId');
  }

  /// Loads settings for all given [moduleIds] at once.
  Future<Map<String, HubModuleNotificationSettings>> loadAllModuleSettings(
    List<String> moduleIds,
  ) async {
    final result = <String, HubModuleNotificationSettings>{};
    for (final id in moduleIds) {
      result[id] = await loadModuleSettings(id);
    }
    return result;
  }
}
