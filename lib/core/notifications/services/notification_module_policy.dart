import 'package:flutter/foundation.dart';

import '../notification_hub.dart';

/// Canonical scheduling policy for module-level notification enablement.
///
/// This is the single source-of-truth read path used by scheduling/recovery
/// logic to decide whether a module is allowed to schedule notifications.
class NotificationModulePolicy {
  NotificationModulePolicy._();

  static const String reasonEnabled = 'enabled';
  static const String reasonModuleDisabled = 'module_disabled';
  static const String reasonModuleNotificationsDisabled =
      'module_notifications_disabled';
  static const String reasonPolicyError = 'policy_error';

  static Future<NotificationModulePolicyDecision> read(
    String moduleId, {
    bool defaultEnabledOnError = true,
  }) async {
    try {
      final hub = NotificationHub();
      await hub.initialize();

      final moduleEnabled = await hub.isModuleEnabled(moduleId);
      if (!moduleEnabled) {
        return NotificationModulePolicyDecision(
          moduleId: moduleId,
          enabled: false,
          reason: reasonModuleDisabled,
        );
      }

      final settings = await hub.getModuleSettings(moduleId);
      if (settings.notificationsEnabled == false) {
        return NotificationModulePolicyDecision(
          moduleId: moduleId,
          enabled: false,
          reason: reasonModuleNotificationsDisabled,
        );
      }

      return NotificationModulePolicyDecision(
        moduleId: moduleId,
        enabled: true,
        reason: reasonEnabled,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NotificationModulePolicy: failed to read policy for "$moduleId": $e',
        );
      }
      return NotificationModulePolicyDecision(
        moduleId: moduleId,
        enabled: defaultEnabledOnError,
        reason: reasonPolicyError,
      );
    }
  }

  static Future<bool> isSchedulingEnabled(
    String moduleId, {
    bool defaultEnabledOnError = true,
  }) async {
    final decision = await read(
      moduleId,
      defaultEnabledOnError: defaultEnabledOnError,
    );
    return decision.enabled;
  }
}

class NotificationModulePolicyDecision {
  final String moduleId;
  final bool enabled;
  final String reason;

  const NotificationModulePolicyDecision({
    required this.moduleId,
    required this.enabled,
    required this.reason,
  });
}

