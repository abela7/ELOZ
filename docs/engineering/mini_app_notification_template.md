# Mini App Notification Template

Use this template when adding notifications to a new mini app.

## 0) Non-Negotiables

1. Use universal + hub path only.
2. Do not create a new direct scheduler lane outside shared pipeline.
3. Keep deterministic IDs inside the module ID range.
4. Keep delete cleanup canonical to prevent resurrection.

## 1) Module Identity

Add module ID + range in `lib/core/notifications/models/notification_hub_modules.dart`.

Example:

```dart
class NotificationHubModuleIds {
  static const String myModule = 'my_module';
}

class NotificationHubIdRanges {
  static const int myModuleStart = 400000;
  static const int myModuleEnd = 409999;
}
```

## 2) Adapter Skeleton

Create: `lib/features/my_module/notifications/my_module_notification_adapter.dart`

```dart
import '../../../core/notifications/notifications.dart';

class MyModuleNotificationAdapter implements MiniAppNotificationAdapter {
  @override
  NotificationHubModule get module => const NotificationHubModule(
        moduleId: 'my_module',
        displayName: 'My Module',
        description: 'My module reminders',
        idRangeStart: 400000,
        idRangeEnd: 409999,
        iconCodePoint: 0xe3af, // replace
        iconFontFamily: 'MaterialIcons',
        colorValue: 0xFF4CAF50,
      );

  @override
  List<HubNotificationSection> get sections => const <HubNotificationSection>[
        HubNotificationSection(id: 'primary', displayName: 'Primary'),
      ];

  @override
  List<HubNotificationType> get customNotificationTypes =>
      const <HubNotificationType>[
        // Add custom types if needed.
      ];

  @override
  Future<void> onNotificationTapped(NotificationHubPayload payload) async {
    // Load entity by payload.entityId, validate exists, then route UI.
  }

  @override
  Future<bool> onNotificationAction({
    required String actionId,
    required NotificationHubPayload payload,
    int? notificationId,
  }) async {
    // Validate entity still exists and action is allowed.
    // Return true only when handled.
    return false;
  }

  @override
  Future<Map<String, String>> resolveVariablesForEntity(
    String entityId,
    String section,
  ) async {
    // Return template vars used by universal templates.
    return <String, String>{
      '{name}': 'Example',
      '{dueDate}': '2026-02-17',
    };
  }
}
```

## 3) Register Adapter in Module Init

In `lib/features/my_module/my_module.dart`:

```dart
Future<void> init() async {
  // hive/adapters/boxes...
  NotificationHub().registerAdapter(MyModuleNotificationAdapter());
}
```

## 4) Rule Model and Storage (Recommended)

Recommended: use `UniversalNotification` records from:

- `lib/core/notifications/models/universal_notification.dart`
- `lib/core/notifications/services/universal_notification_repository.dart`

For each module entity, persist one or more universal notification definitions with:

- `moduleId`
- `section`
- `entityId`
- `titleTemplate` / `bodyTemplate`
- `typeId`
- timing fields (`timing`, `timingValue`, `timingUnit`, `hour`, `minute`)
- action config (`actionsEnabled`, `actionsJson`)

## 5) Generate Notification Specs (Project Mapping)

In this codebase, "NotificationSpec" maps to:

1. `UniversalNotification` definition (storage-level intent)
2. `NotificationHubScheduleRequest` (runtime schedule request created by scheduler)

Scheduler path:

```text
UniversalNotificationRepository (defs)
  -> UniversalNotificationScheduler.syncAllWithMetrics()
  -> NotificationHub.schedule(NotificationHubScheduleRequest)
  -> NotificationService.scheduleHubReminder(...)
```

## 6) UI Integration

Preferred: embed `UniversalReminderSection` in create/edit/detail screen.

```dart
UniversalReminderSection(
  creatorContext: NotificationCreatorContext(
    moduleId: 'my_module',
    sectionId: 'primary',
    entityId: entityId,
    entityName: entityName,
  ),
  isDark: isDark,
)
```

After rule changes, trigger shared resync:

```dart
await NotificationSystemRefresher.instance.resyncAll(
  reason: 'my_module_rule_updated',
  force: true,
  debounce: false,
);
```

## 7) Payload Schema for Tap Routing

Use `NotificationHubPayload` as canonical payload:

- `moduleId`
- `entityId`
- `reminderType`
- `reminderValue`
- `reminderUnit`
- `extras` (recommended keys: `section`, `sourceFlow`, `entityType`)

Example (raw string produced by `NotificationHubPayload.toRaw()`):

```text
my_module|entity-123|before|15|minutes|section:primary|sourceFlow:universal_sync
```

## 8) Delete Cleanup Hook (Required)

On entity delete, run canonical cleanup:

```dart
final hub = NotificationHub();
await hub.initialize();
await hub.cancelForEntity(moduleId: 'my_module', entityId: entityId);
await UniversalNotificationRepository().deleteByEntity(entityId);
```

Do not leave module-specific reminder state that recovery can rehydrate.

## 9) Minimal Test Set

Required tests before merge:

1. Deterministic ID range test for module.
2. Create/edit/resync duplicate prevention test.
3. Delete + recovery no-resurrection test.
4. Module-disabled scheduling/action blocked test.
5. Tap/action with deleted entity safely rejected test.

## 10) Merge Checklist

1. Adapter implemented and registered.
2. Universal definitions saved from module UI.
3. Scheduling only through hub/universal pipeline.
4. Delete cleanup integrated.
5. Validation checklist from `notifications_integration_guide.md` passed.

