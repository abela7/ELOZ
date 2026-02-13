import 'package:shared_preferences/shared_preferences.dart';

import '../models/finance_notification_settings.dart';

class FinanceNotificationSettingsService {
  static const String _prefsKey = 'finance_notification_settings_v1';

  Future<FinanceNotificationSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsKey) ?? '').trim();
      if (raw.isEmpty) {
        return FinanceNotificationSettings.defaults;
      }
      return FinanceNotificationSettings.fromJsonString(raw);
    } catch (_) {
      return FinanceNotificationSettings.defaults;
    }
  }

  Future<void> save(FinanceNotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, settings.toJsonString());
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
