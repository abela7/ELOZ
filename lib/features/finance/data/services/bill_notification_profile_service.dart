import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bill_notification_profile.dart';

class BillNotificationProfileService {
  static const String _prefsKey = 'finance_bill_notification_profiles_v1';

  Future<Map<String, BillNotificationProfile>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsKey) ?? '').trim();
      if (raw.isEmpty) {
        return <String, BillNotificationProfile>{};
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, BillNotificationProfile>{};
      }

      final result = <String, BillNotificationProfile>{};
      decoded.forEach((billId, value) {
        if (billId.trim().isEmpty || value is! Map<String, dynamic>) {
          return;
        }
        final profile = BillNotificationProfile.fromJson(value);
        if (profile.billId.isEmpty) {
          return;
        }
        result[billId] = profile;
      });
      return result;
    } catch (_) {
      return <String, BillNotificationProfile>{};
    }
  }

  Future<BillNotificationProfile?> loadForBill(String billId) async {
    final all = await loadAll();
    return all[billId];
  }

  Future<void> saveProfile(BillNotificationProfile profile) async {
    if (profile.billId.isEmpty) return;
    final all = await loadAll();
    all[profile.billId] = profile;
    await _saveAll(all);
  }

  Future<void> removeProfile(String billId) async {
    final all = await loadAll();
    all.remove(billId);
    await _saveAll(all);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> _saveAll(Map<String, BillNotificationProfile> profiles) async {
    final payload = <String, dynamic>{};
    profiles.forEach((billId, profile) {
      payload[billId] = profile.toJson();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(payload));
  }
}

