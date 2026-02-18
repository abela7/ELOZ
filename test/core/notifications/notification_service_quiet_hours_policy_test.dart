import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/models/notification_settings.dart';
import 'package:life_manager/core/services/notification_service.dart';

void main() {
  group('NotificationService hub quiet-hours policy', () {
    final service = NotificationService();

    test('defers non-bypassed reminders outside quiet hours', () {
      final settings = NotificationSettings.defaults.copyWith(
        quietHoursEnabled: true,
        quietHoursStart: 22 * 60, // 22:00
        quietHoursEnd: 7 * 60, // 07:00
        allowUrgentDuringQuietHours: false,
      );
      final scheduledAt = DateTime(2026, 2, 17, 23, 30);

      final resolved = service.resolveHubQuietHoursScheduledAtForTest(
        scheduledAt: scheduledAt,
        settings: settings,
        bypassQuietHours: false,
      );

      expect(resolved, isNotNull);
      expect(resolved!.isAfter(scheduledAt), isTrue);
      expect(settings.isInQuietHoursAt(resolved), isFalse);
    });

    test('keeps time when bypassQuietHours is true', () {
      final settings = NotificationSettings.defaults.copyWith(
        quietHoursEnabled: true,
        quietHoursStart: 22 * 60,
        quietHoursEnd: 7 * 60,
        allowUrgentDuringQuietHours: false,
      );
      final scheduledAt = DateTime(2026, 2, 17, 23, 30);

      final resolved = service.resolveHubQuietHoursScheduledAtForTest(
        scheduledAt: scheduledAt,
        settings: settings,
        bypassQuietHours: true,
      );

      expect(resolved, scheduledAt);
    });

    test('keeps time when module allows quiet-hours delivery', () {
      final settings = NotificationSettings.defaults.copyWith(
        quietHoursEnabled: true,
        quietHoursStart: 22 * 60,
        quietHoursEnd: 7 * 60,
        allowUrgentDuringQuietHours: true,
      );
      final scheduledAt = DateTime(2026, 2, 17, 23, 30);

      final resolved = service.resolveHubQuietHoursScheduledAtForTest(
        scheduledAt: scheduledAt,
        settings: settings,
        bypassQuietHours: false,
      );

      expect(resolved, scheduledAt);
    });
  });
}
