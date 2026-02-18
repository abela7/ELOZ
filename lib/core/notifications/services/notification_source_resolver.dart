import '../models/notification_hub_modules.dart';
import 'universal_notification_repository.dart';

/// Result of source resolution.
class ResolvedNotificationSource {
  final String moduleId;
  final String section;
  final String entityId;
  final String? entityName;

  const ResolvedNotificationSource({
    required this.moduleId,
    required this.section,
    required this.entityId,
    this.entityName,
  });
}

/// Resolves notification source (module, section, entity) from a notification ID.
///
/// Used when a log entry has moduleId 'unknown' (e.g. legacy cancellations,
/// payload parse failure). Tries Universal definitions first, then falls back
/// to range-based module inference.
class NotificationSourceResolver {
  NotificationSourceResolver({UniversalNotificationRepository? repo})
    : _repo = repo ?? UniversalNotificationRepository();

  final UniversalNotificationRepository _repo;

  /// Infer module from notification ID using known ranges.
  static String? moduleIdFromRange(int notificationId) {
    if (notificationId >= NotificationHubIdRanges.taskStart &&
        notificationId <= NotificationHubIdRanges.taskEnd) {
      return NotificationHubModuleIds.task;
    }
    if (notificationId >= NotificationHubIdRanges.habitStart &&
        notificationId <= NotificationHubIdRanges.habitEnd) {
      return NotificationHubModuleIds.habit;
    }
    if (notificationId >= NotificationHubIdRanges.financeStart &&
        notificationId <= NotificationHubIdRanges.financeEnd) {
      return NotificationHubModuleIds.finance;
    }
    if (notificationId >= NotificationHubIdRanges.sleepStart &&
        notificationId <= NotificationHubIdRanges.sleepEnd) {
      return NotificationHubModuleIds.sleep;
    }
    if (notificationId >= NotificationHubIdRanges.mbtMoodStart &&
        notificationId <= NotificationHubIdRanges.mbtMoodEnd) {
      return NotificationHubModuleIds.mbtMood;
    }
    if (notificationId >= NotificationHubIdRanges.behaviorStart &&
        notificationId <= NotificationHubIdRanges.behaviorEnd) {
      return NotificationHubModuleIds.behavior;
    }
    return null;
  }

  /// Resolve source from notification ID. Returns null if not found.
  ///
  /// 1. Scan Universal definitions (supports both old and new ID strategies).
  /// 2. Fallback to module range inference.
  Future<ResolvedNotificationSource?> resolve(int notificationId) async {
    await _repo.init();
    final all = await _repo.getAll();
    for (final n in all) {
      final legacyHash = n.id.hashCode & 0x7FFFFFFF;
      final stableHash = _stableUniversalNotificationId(
        moduleId: n.moduleId,
        entityId: n.entityId,
        universalId: n.id,
        reminderType: n.timing,
        reminderValue: n.timingValue,
        reminderUnit: n.timingUnit,
      );
      if (legacyHash == notificationId || stableHash == notificationId) {
        return ResolvedNotificationSource(
          moduleId: n.moduleId,
          section: n.section,
          entityId: n.entityId,
          entityName: n.entityName.isNotEmpty ? n.entityName : null,
        );
      }
    }

    final rangeModule = moduleIdFromRange(notificationId);
    if (rangeModule != null) {
      return ResolvedNotificationSource(
        moduleId: rangeModule,
        section: '',
        entityId: '',
      );
    }
    return null;
  }

  /// Build a parseable payload from [ResolvedNotificationSource] for logging.
  static String buildPayloadFromResolved(ResolvedNotificationSource r) {
    final parts = [r.moduleId, r.entityId, 'at_time', '0', 'minutes'];
    if (r.section.isNotEmpty) {
      parts.add('section:${r.section}');
    }
    return parts.join('|');
  }

  static int _stableUniversalNotificationId({
    required String moduleId,
    required String entityId,
    required String universalId,
    required String reminderType,
    required int reminderValue,
    required String reminderUnit,
  }) {
    final signature = [
      moduleId,
      '$entityId|$universalId',
      reminderType,
      '$reminderValue',
      reminderUnit,
    ].join('|');
    final hash = signature.hashCode.abs();

    final int rangeStart;
    final int rangeSize;
    if (moduleId == NotificationHubModuleIds.habit) {
      rangeStart = NotificationHubIdRanges.habitStart;
      rangeSize =
          NotificationHubIdRanges.habitEnd -
          NotificationHubIdRanges.habitStart +
          1;
    } else if (moduleId == NotificationHubModuleIds.finance) {
      rangeStart = NotificationHubIdRanges.financeStart;
      rangeSize =
          NotificationHubIdRanges.financeEnd -
          NotificationHubIdRanges.financeStart +
          1;
    } else if (moduleId == NotificationHubModuleIds.sleep) {
      rangeStart = NotificationHubIdRanges.sleepStart;
      rangeSize =
          NotificationHubIdRanges.sleepEnd -
          NotificationHubIdRanges.sleepStart +
          1;
    } else if (moduleId == NotificationHubModuleIds.mbtMood) {
      rangeStart = NotificationHubIdRanges.mbtMoodStart;
      rangeSize =
          NotificationHubIdRanges.mbtMoodEnd -
          NotificationHubIdRanges.mbtMoodStart +
          1;
    } else if (moduleId == NotificationHubModuleIds.behavior) {
      rangeStart = NotificationHubIdRanges.behaviorStart;
      rangeSize =
          NotificationHubIdRanges.behaviorEnd -
          NotificationHubIdRanges.behaviorStart +
          1;
    } else {
      rangeStart = NotificationHubIdRanges.taskStart;
      rangeSize =
          NotificationHubIdRanges.taskEnd -
          NotificationHubIdRanges.taskStart +
          1;
    }
    return rangeStart + (hash % rangeSize);
  }
}
