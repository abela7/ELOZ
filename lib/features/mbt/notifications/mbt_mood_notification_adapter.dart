import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notifications.dart';
import '../../../routing/app_router.dart';
import 'mbt_mood_notification_service.dart';
import 'mbt_notification_contract.dart';

class MbtMoodNotificationAdapter implements MiniAppNotificationAdapter {
  final MbtMoodNotificationService _service = MbtMoodNotificationService();

  @override
  NotificationHubModule get module => NotificationHubModule(
    moduleId: MbtNotificationContract.moduleId,
    displayName: 'MBT Mood',
    description: 'Daily mood check-in reminders',
    idRangeStart: NotificationHubIdRanges.mbtMoodStart,
    idRangeEnd: NotificationHubIdRanges.mbtMoodEnd,
    iconCodePoint: Icons.mood_rounded.codePoint,
    colorValue: Colors.orange.toARGB32(),
  );

  @override
  List<HubNotificationSection> get sections => [
    HubNotificationSection(
      id: MbtNotificationContract.sectionMoodCheckin,
      displayName: 'Mood Check-in',
      description: 'Daily reminder to log your mood',
      iconCodePoint: Icons.mood_rounded.codePoint,
      colorValue: Colors.orange.toARGB32(),
    ),
  ];

  @override
  List<HubNotificationType> get customNotificationTypes => const [
    HubNotificationType(
      id: MbtNotificationContract.typeMoodDailyCheckin,
      displayName: 'Daily Mood Check-in',
      moduleId: MbtNotificationContract.moduleId,
      sectionId: MbtNotificationContract.sectionMoodCheckin,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'task_reminders',
        audioStream: 'notification',
      ),
    ),
  ];

  @override
  Future<void> onNotificationTapped(NotificationHubPayload payload) async {
    await _openMoodScreen();
  }

  @override
  Future<bool> onNotificationAction({
    required String actionId,
    required NotificationHubPayload payload,
    int? notificationId,
  }) async {
    switch (actionId) {
      case 'open':
      case 'view':
      case 'log_now':
        await _openMoodScreen();
        return true;
      default:
        return false;
    }
  }

  @override
  Future<void> onNotificationDeleted(NotificationHubPayload payload) async {
    if (payload.entityId != MbtNotificationContract.entityMoodDailyCheckin) {
      return;
    }
    try {
      final settings = await _service.loadSettings();
      await _service.setDailyReminder(
        enabled: false,
        time: settings.time,
        triggerResync: false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'MbtMoodNotificationAdapter: failed to persist delete for '
          '${payload.entityId}: $e',
        );
      }
    }
  }

  @override
  Future<Map<String, String>> resolveVariablesForEntity(
    String entityId,
    String section,
  ) async {
    return <String, String>{};
  }

  Future<void> _openMoodScreen() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    GoRouter.of(context).go('/mood');
  }
}
