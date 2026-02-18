import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/android_system_status.dart';
import 'notification_recovery_service.dart';

/// Central service to refresh notification schedules on app lifecycle events.
///
/// [resyncAll] is the canonical entrypoint and should be called for startup,
/// resume, and restore flows. Resume calls are debounced to avoid excessive
/// work while still recovering reliably from real-world schedule drift.
class NotificationSystemRefresher {
  NotificationSystemRefresher._();
  static final NotificationSystemRefresher instance =
      NotificationSystemRefresher._();

  static const Duration minResyncInterval = Duration(seconds: 45);
  static const String _prefsLastSettingsSignatureKey =
      'notification_resync_last_settings_signature_v1';
  static const String _prefsGlobalSettingsKey = 'notification_settings';
  static const String _prefsHabitSettingsKey = 'habit_notification_settings';
  static const String _prefsHubEnabledStatesKey =
      'notification_hub_module_settings_v1';
  static const String _prefsHubModuleSettingsPrefix =
      'notification_hub_module_settings_v1_';

  DateTime? _lastResyncAt;
  bool _refreshInProgress = false;

  /// Call when app resumes. Runs debounced sync, and forces sync when
  /// Android reports a pending timezone/time change resync flag.
  Future<void> onAppResumed() async {
    if (_refreshInProgress) return;

    final pendingSystemResync = await _consumeSystemPendingResyncFlag();
    if (pendingSystemResync) {
      await resyncAll(
        reason: 'app_resume_timezone_change',
        force: true,
        debounce: false,
      );
      return;
    }

    await resyncAll(reason: 'app_resume');
  }

  /// Canonical app-runtime resync entry point.
  ///
  /// Use this for real-world recovery cases:
  /// - app start
  /// - app resume (debounced)
  /// - backup/restore completion
  Future<NotificationRecoveryResult?> resyncAll({
    required String reason,
    bool force = false,
    bool debounce = true,
  }) async {
    final now = DateTime.now();
    if (_refreshInProgress) {
      if (kDebugMode) {
        debugPrint(
          'NotificationSystemRefresher: skip resync ($reason) - already in progress',
        );
      }
      return null;
    }

    final signatureSnapshot = await _readSettingsSignatureSnapshot();
    final shouldFastSkip =
        !force &&
        !_reasonRequiresHardResync(reason) &&
        !signatureSnapshot.settingsChangedSinceLastSync;
    if (shouldFastSkip) {
      if (kDebugMode) {
        debugPrint(
          'NotificationSystemRefresher: fast-skip resync ($reason) - '
          'settings/rules unchanged since last sync',
        );
      }
      _lastResyncAt = now;
      return null;
    }

    if (!force && debounce && _lastResyncAt != null) {
      final sinceLastRun = now.difference(_lastResyncAt!);
      if (sinceLastRun < minResyncInterval) {
        if (signatureSnapshot.settingsChangedSinceLastSync) {
          if (kDebugMode) {
            debugPrint(
              'NotificationSystemRefresher: bypass debounce ($reason) - '
              'settings/rules changed since last sync',
            );
          }
        } else {
          if (kDebugMode) {
            debugPrint(
              'NotificationSystemRefresher: debounced resync ($reason), '
              'last run ${sinceLastRun.inSeconds}s ago',
            );
          }
          return null;
        }
      }
    }

    _refreshInProgress = true;

    try {
      final result = await _refreshSchedules(reason: reason);
      if (result.success) {
        await _persistLastSettingsSignature(signatureSnapshot.currentSignature);
      }
      return result;
    } catch (e, st) {
      debugPrint('NotificationSystemRefresher: refresh failed: $e');
      debugPrintStack(stackTrace: st);
      return null;
    } finally {
      _lastResyncAt = DateTime.now();
      _refreshInProgress = false;
    }
  }

  Future<NotificationRecoveryResult> _refreshSchedules({
    required String reason,
  }) async {
    debugPrint(
      'NotificationSystemRefresher: refreshing schedules (reason=$reason)',
    );

    final result = await NotificationRecoveryService.runRecovery(
      bootstrapForBackground: false,
      sourceFlow: reason,
    );

    if (kDebugMode && result.success) {
      debugPrint(
        'NotificationSystemRefresher: sync complete - '
        'Duration: ${result.durationMs}ms, '
        'Finance: ${result.financeScheduled} scheduled, '
        '${result.financeCancelled} cleared, '
        'Universal: ${result.universalScheduled} scheduled '
        '(${result.universalSkipped} skipped, ${result.universalFailed} failed)',
      );
    }
    return result;
  }

  Future<bool> _consumeSystemPendingResyncFlag() async {
    try {
      return await AndroidSystemStatus.getAndClearPendingNotificationResync();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'NotificationSystemRefresher: failed reading pending system resync flag: $e',
        );
        debugPrintStack(stackTrace: st);
      }
      return false;
    }
  }

  bool _reasonRequiresHardResync(String reason) {
    return reason.contains('timezone_change') ||
        reason.contains('backup_restore');
  }

  Future<_SettingsSignatureSnapshot> _readSettingsSignatureSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_prefsLastSettingsSignatureKey);
    final current = _computeSettingsSignature(prefs);
    return _SettingsSignatureSnapshot(
      currentSignature: current,
      settingsChangedSinceLastSync: previous == null || previous != current,
    );
  }

  String _computeSettingsSignature(SharedPreferences prefs) {
    final keys = <String>[
      _prefsGlobalSettingsKey,
      _prefsHabitSettingsKey,
      _prefsHubEnabledStatesKey,
      ...prefs.getKeys().where(
        (key) => key.startsWith(_prefsHubModuleSettingsPrefix),
      ),
    ]..sort();

    final buffer = StringBuffer();
    for (final key in keys) {
      final value = prefs.get(key);
      buffer
        ..write(key)
        ..write('=')
        ..write(_serializePreferenceValue(value))
        ..write(';');
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  String _serializePreferenceValue(Object? value) {
    if (value == null) return '<null>';
    if (value is String || value is num || value is bool) {
      return value.toString();
    }
    if (value is List<String>) {
      return jsonEncode(value);
    }
    return value.toString();
  }

  Future<void> _persistLastSettingsSignature(String signature) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastSettingsSignatureKey, signature);
  }
}

class _SettingsSignatureSnapshot {
  final String currentSignature;
  final bool settingsChangedSinceLastSync;

  const _SettingsSignatureSnapshot({
    required this.currentSignature,
    required this.settingsChangedSinceLastSync,
  });
}
