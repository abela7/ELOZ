import '../models/hub_notification_section.dart';
import '../models/hub_notification_type.dart';
import '../models/notification_hub_module.dart';
import '../models/notification_hub_payload.dart';

abstract class MiniAppNotificationAdapter {
  /// Module metadata (ID, display name, icon, ID range, etc.).
  NotificationHubModule get module;

  /// Sections within this module that group notification types.
  ///
  /// E.g. Finance has: Bills & Subscriptions, Debts, Budgets, etc.
  /// Each section is displayed as a category in the Hub UI.
  /// Override to provide module sections. Empty means no grouping.
  List<HubNotificationSection> get sections =>
      const <HubNotificationSection>[];

  /// Custom notification types registered by this module.
  ///
  /// These are automatically added to the [NotificationTypeRegistry] when
  /// the adapter is registered with the hub. Override this to provide
  /// module-specific types (e.g. `'finance_payment_due'`).
  ///
  /// Each type should have a [HubNotificationType.sectionId] matching one
  /// of the [sections] above for proper grouping.
  ///
  /// Built-in types (`special`, `alarm`, `regular`, `silent`) are always
  /// available and don't need to be listed here.
  List<HubNotificationType> get customNotificationTypes =>
      const <HubNotificationType>[];

  /// Called when the user taps the notification body.
  Future<void> onNotificationTapped(NotificationHubPayload payload);

  /// Called when the user taps an action button on the notification.
  ///
  /// Return `true` if the action was handled.
  Future<bool> onNotificationAction({
    required String actionId,
    required NotificationHubPayload payload,
    int? notificationId,
  });

  /// Called when the user deletes a scheduled notification from the Hub.
  ///
  /// Override to permanently remove the reminder from the source entity so
  /// it won't be rescheduled on the next sync. Default does nothing.
  Future<void> onNotificationDeleted(NotificationHubPayload payload) async {}

  /// Resolve variable values for a given entity when scheduling or previewing.
  ///
  /// Used by the Universal Notification system. Given an [entityId] and
  /// [section], return a map of variable keys (e.g. `{billName}`) to current
  /// values. Override to provide live data; default returns empty map.
  Future<Map<String, String>> resolveVariablesForEntity(
    String entityId,
    String section,
  ) async =>
      {};
}
