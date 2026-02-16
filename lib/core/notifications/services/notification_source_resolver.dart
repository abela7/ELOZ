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
/// payload parse failure). Tries ID ranges first, then scans Universal repo
/// for hashCode-based IDs (Task/Habit/Sleep wind-down Universal reminders).
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
    return null;
  }

  /// Resolve source from notification ID. Returns null if not found.
  ///
  /// 1. Check ID ranges (task 1–99999, habit 100k–199k, finance 200k–299k,
  ///    sleep 300k–309k).
  /// 2. For other IDs (Universal hashCode-based), scan
  ///    [UniversalNotificationRepository] for matching hashCode.
  Future<ResolvedNotificationSource?> resolve(int notificationId) async {
    final rangeModule = moduleIdFromRange(notificationId);
    if (rangeModule != null) {
      return ResolvedNotificationSource(
        moduleId: rangeModule,
        section: '',
        entityId: '',
      );
    }

    await _repo.init();
    final all = await _repo.getAll();
    for (final n in all) {
      final hash = n.id.hashCode & 0x7FFFFFFF;
      if (hash == notificationId) {
        return ResolvedNotificationSource(
          moduleId: n.moduleId,
          section: n.section,
          entityId: n.entityId,
          entityName: n.entityName.isNotEmpty ? n.entityName : null,
        );
      }
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
}
