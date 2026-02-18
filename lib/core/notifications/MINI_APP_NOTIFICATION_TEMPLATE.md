# Mini-App Notification Template

## Non-Negotiable Rule

- New modules must use `UniversalNotificationRepository` + `NotificationHub`.
- Do not add new legacy scheduler paths (direct `NotificationService` task/habit-style flows).

## 1) Reserve Module Identity

- Add module id and ID range in `lib/core/notifications/models/notification_hub_modules.dart`.
- Keep ranges non-overlapping and deterministic.

## 2) Create Adapter

File: `lib/features/<module>/notifications/<module>_notification_adapter.dart`

Requirements:
- Extend `MiniAppNotificationAdapter`.
- Provide `module` metadata.
- Implement:
  - `onNotificationTapped(...)`
  - `onNotificationAction(...)`
- Optional:
  - `sections`
  - `customNotificationTypes`
  - `resolveVariablesForEntity(...)`

## 3) Register Adapter

Register in `<module>_module.dart` during module `init()`:

```dart
NotificationHub().registerAdapter(YourModuleNotificationAdapter());
```

## 4) Add Universal Reminder UI

Use `UniversalReminderSection` in add/edit screens with a creator context.

```dart
UniversalReminderSection(
  creatorContext: YourModuleNotificationCreatorContext.forEntity(
    entityId: entityId,
    entityName: entityName,
  ),
  isDark: isDark,
)
```

## 5) Scheduling Contract

- Write reminder definitions to `UniversalNotificationRepository`.
- Let `UniversalNotificationScheduler.syncAll()` schedule/cancel via Hub.
- No module-specific OS scheduling logic outside Hub.

## 6) Delete Contract

Every entity delete must call one canonical cleanup path that:
- Cancels OS notifications for that entity/module via Hub.
- Removes universal definitions for the entity.
- Removes legacy remnants only if migration compatibility requires it.

## 7) Required Tests (minimum)

- Deterministic notification ID test for the module range.
- Delete -> recovery test: deleted entity notifications do not resurrect.
- Adapter routing tests for tap and at least one action.
