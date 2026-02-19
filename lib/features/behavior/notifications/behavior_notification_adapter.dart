import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notifications.dart';
import '../../../routing/app_router.dart';
import 'behavior_notification_contract.dart';

class BehaviorNotificationAdapter implements MiniAppNotificationAdapter {
  @override
  NotificationHubModule get module => NotificationHubModule(
    moduleId: BehaviorNotificationContract.moduleId,
    displayName: 'Behavior Tracker',
    description: 'Daily behavior logging reminders',
    idRangeStart: NotificationHubIdRanges.behaviorStart,
    idRangeEnd: NotificationHubIdRanges.behaviorEnd,
    iconCodePoint: Icons.track_changes_rounded.codePoint,
    colorValue: Colors.teal.toARGB32(),
  );

  @override
  List<HubNotificationSection> get sections => [
    HubNotificationSection(
      id: BehaviorNotificationContract.sectionDailyReminder,
      displayName: 'Daily Reminder',
      description: 'Reminder to log behavior events',
      iconCodePoint: Icons.notifications_active_rounded.codePoint,
      colorValue: Colors.teal.toARGB32(),
    ),
  ];

  @override
  List<HubNotificationType> get customNotificationTypes => const [
    HubNotificationType(
      id: BehaviorNotificationContract.typeDailyReminder,
      displayName: 'Behavior Daily Reminder',
      moduleId: BehaviorNotificationContract.moduleId,
      sectionId: BehaviorNotificationContract.sectionDailyReminder,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'task_reminders',
        audioStream: 'notification',
      ),
    ),
  ];

  @override
  Future<void> onNotificationTapped(NotificationHubPayload payload) async {
    await _openModuleLanding();
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
        await _openModuleLanding();
        return true;
      default:
        return false;
    }
  }

  @override
  Future<void> onNotificationDeleted(NotificationHubPayload payload) async {}

  @override
  Future<Map<String, String>> resolveVariablesForEntity(
    String entityId,
    String section,
  ) async {
    return <String, String>{};
  }

  Future<void> _openModuleLanding() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    GoRouter.of(context).go('/behavior');
  }
}
