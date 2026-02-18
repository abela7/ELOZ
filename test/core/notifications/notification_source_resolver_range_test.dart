import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/notifications/models/notification_hub_modules.dart';
import 'package:life_manager/core/notifications/services/notification_source_resolver.dart';

void main() {
  group('NotificationSourceResolver.moduleIdFromRange', () {
    test('maps known module ID ranges correctly', () {
      expect(
        NotificationSourceResolver.moduleIdFromRange(
          NotificationHubIdRanges.taskStart,
        ),
        NotificationHubModuleIds.task,
      );
      expect(
        NotificationSourceResolver.moduleIdFromRange(
          NotificationHubIdRanges.habitStart,
        ),
        NotificationHubModuleIds.habit,
      );
      expect(
        NotificationSourceResolver.moduleIdFromRange(
          NotificationHubIdRanges.financeStart,
        ),
        NotificationHubModuleIds.finance,
      );
      expect(
        NotificationSourceResolver.moduleIdFromRange(
          NotificationHubIdRanges.sleepStart,
        ),
        NotificationHubModuleIds.sleep,
      );
      expect(
        NotificationSourceResolver.moduleIdFromRange(
          NotificationHubIdRanges.mbtMoodStart,
        ),
        NotificationHubModuleIds.mbtMood,
      );
      expect(
        NotificationSourceResolver.moduleIdFromRange(
          NotificationHubIdRanges.behaviorStart,
        ),
        NotificationHubModuleIds.behavior,
      );
    });

    test('returns null for IDs outside known ranges', () {
      expect(NotificationSourceResolver.moduleIdFromRange(0), isNull);
      expect(NotificationSourceResolver.moduleIdFromRange(330000), isNull);
    });
  });
}
