import '../../models/pending_notification_info.dart';
import '../models/notification_hub_modules.dart';
import '../models/notification_hub_payload.dart';

/// Canonical logical-key helper for pending notifications.
///
/// Used by diagnostics and robustness tooling to detect duplicate pending
/// notifications consistently across legacy payloads and universal/hub payloads.
class NotificationLogicalKeyHelper {
  NotificationLogicalKeyHelper._();

  static String moduleIdFor(PendingNotificationInfo info) {
    final parsed = NotificationHubPayload.tryParse(info.payload);
    if (parsed != null && parsed.moduleId.isNotEmpty) {
      return parsed.moduleId;
    }
    if (info.type.isNotEmpty) {
      return info.type;
    }
    return 'unknown';
  }

  static String entityIdFor(PendingNotificationInfo info) {
    final parsed = NotificationHubPayload.tryParse(info.payload);
    if (parsed != null && parsed.entityId.isNotEmpty) {
      return parsed.entityId;
    }
    return info.entityId;
  }

  static String reminderTypeFor(PendingNotificationInfo info) {
    final parsed = NotificationHubPayload.tryParse(info.payload);
    if (parsed != null && parsed.reminderType.isNotEmpty) {
      return parsed.reminderType;
    }
    return info.reminderType ?? 'unknown';
  }

  static String reminderValueFor(PendingNotificationInfo info) {
    final parsed = NotificationHubPayload.tryParse(info.payload);
    if (parsed != null && parsed.reminderValue.isNotEmpty) {
      return parsed.reminderValue;
    }
    return '${info.reminderValue ?? 0}';
  }

  static String reminderUnitFor(PendingNotificationInfo info) {
    final parsed = NotificationHubPayload.tryParse(info.payload);
    if (parsed != null && parsed.reminderUnit.isNotEmpty) {
      return parsed.reminderUnit;
    }
    return info.reminderUnit ?? 'minutes';
  }

  static DateTime? fireTimeFor(PendingNotificationInfo info) {
    return info.willFireAt ?? info.scheduledAt;
  }

  /// Logical identity key:
  /// `module|entity|reminderType|reminderValue|reminderUnit|fireTimeMs`
  ///
  /// This intentionally ignores notification ID so collisions in the same
  /// logical key are treated as duplicates.
  static String logicalKeyFor(PendingNotificationInfo info) {
    final fireTimeMs = fireTimeFor(info)?.millisecondsSinceEpoch ?? -1;
    return [
      moduleIdFor(info),
      entityIdFor(info),
      reminderTypeFor(info),
      reminderValueFor(info),
      reminderUnitFor(info),
      '$fireTimeMs',
    ].join('|');
  }

  static bool isInKnownRange(int notificationId) {
    return _inRange(
          notificationId,
          NotificationHubIdRanges.taskStart,
          NotificationHubIdRanges.taskEnd,
        ) ||
        _inRange(
          notificationId,
          NotificationHubIdRanges.habitStart,
          NotificationHubIdRanges.habitEnd,
        ) ||
        _inRange(
          notificationId,
          NotificationHubIdRanges.financeStart,
          NotificationHubIdRanges.financeEnd,
        ) ||
        _inRange(
          notificationId,
          NotificationHubIdRanges.sleepStart,
          NotificationHubIdRanges.sleepEnd,
        ) ||
        _inRange(
          notificationId,
          NotificationHubIdRanges.mbtMoodStart,
          NotificationHubIdRanges.mbtMoodEnd,
        ) ||
        _inRange(
          notificationId,
          NotificationHubIdRanges.behaviorStart,
          NotificationHubIdRanges.behaviorEnd,
        );
  }

  static bool isInModuleRange(String moduleId, int notificationId) {
    switch (moduleId) {
      case NotificationHubModuleIds.task:
        return _inRange(
          notificationId,
          NotificationHubIdRanges.taskStart,
          NotificationHubIdRanges.taskEnd,
        );
      case NotificationHubModuleIds.habit:
        return _inRange(
          notificationId,
          NotificationHubIdRanges.habitStart,
          NotificationHubIdRanges.habitEnd,
        );
      case NotificationHubModuleIds.finance:
        return _inRange(
          notificationId,
          NotificationHubIdRanges.financeStart,
          NotificationHubIdRanges.financeEnd,
        );
      case NotificationHubModuleIds.sleep:
        return _inRange(
          notificationId,
          NotificationHubIdRanges.sleepStart,
          NotificationHubIdRanges.sleepEnd,
        );
      case NotificationHubModuleIds.mbtMood:
        return _inRange(
          notificationId,
          NotificationHubIdRanges.mbtMoodStart,
          NotificationHubIdRanges.mbtMoodEnd,
        );
      case NotificationHubModuleIds.behavior:
        return _inRange(
          notificationId,
          NotificationHubIdRanges.behaviorStart,
          NotificationHubIdRanges.behaviorEnd,
        );
      default:
        return true;
    }
  }

  static bool _inRange(int value, int start, int end) {
    return value >= start && value <= end;
  }
}
