# Notification System Overview

## Architecture

- **Notification Hub**: Central scheduler and router. All modules register adapters. The Hub converts module requests into OS alarms and routes taps/actions to the correct mini app.
- **Finance Scheduler**: Builds requests from bills, debts, income, budgets, savings goals. Uses rolling model for bills (1 notification at a time); batch model for income (multiple occurrences within horizon).
- **Universal Notification Scheduler**: Schedules Task/Habit/Sleep reminders from UniversalNotificationRepository. One notification per stored definition; next occurrence computed at sync time.
- **NotificationSystemRefresher**: On app resume after 15+ min in background, triggers Finance + Universal sync so alarms stay current (e.g. after OS could have cleared them).

## Key Behaviors

### Bills & Subscriptions
- **Rolling model**: Only `nextDueDate` is scheduled. When user pays, `nextDueDate` advances; next sync schedules the new date. For 36-month or indefinite bills, we never plan 36 notifications -- always 1 at a time.
- **Sync triggers**: Startup (if syncOnStartup), app resume (if backgrounded 15+ min), after payment, bill add/edit.

### Recurring Income
- **Batch model**: Occurrences within planning window, capped at `min(planningWindowDays, 200)` per stream to avoid OS limits.
- Indefinite income: Each sync plans up to the cap within the horizon; next sync advances the window.

### OS Limits
- Android typically allows ~500 exact alarms. If total pending would exceed 480, the Finance scheduler logs a warning and prioritizes (bills > debts > lending > budgets > savings > income).

### Planning Window
- 7-365 days (default 180). Configurable in Finance notification settings.
- Bills: Only affects how far in the future we look for `nextDueDate` (usually irrelevant -- bills only have one next date).
- Income: Directly limits how many occurrences we schedule per stream.

---

## How to Add Notifications to a New Mini App

Every mini app follows the same 3-phase pattern:

### Hard Gate (Must Follow)

- New modules must go through **Universal Notifications + Notification Hub** only.
- Do not introduce new legacy scheduler paths that call module-specific reminder logic directly.
- Use `MINI_APP_NOTIFICATION_TEMPLATE.md` as the implementation checklist.

### Phase 1: Link to the Hub

1. **Reserve an ID range** in `core/notifications/models/notification_hub_modules.dart`:
   - Add a module ID constant (e.g. `static const String mood = 'mood';`)
   - Add an ID range (e.g. 400000-499999). Must not overlap existing ranges.

2. **Create a notification adapter** at `features/X/notifications/X_notification_adapter.dart`:
   - Extend `MiniAppNotificationAdapter`
   - Implement `module` (metadata), `onNotificationTapped`, `onNotificationAction`
   - Optionally override: `sections`, `customNotificationTypes`, `resolveVariablesForEntity`

3. **Register the adapter** in your module's `init()`:
   ```dart
   NotificationHub().registerAdapter(YourNotificationAdapter());
   ```

### Phase 2: Define Notification Types

1. **Create a contract file** at `features/X/notifications/X_notification_contract.dart`:
   - Type IDs, section IDs, extras keys, condition constants.

2. **Define custom types** (optional) by overriding `customNotificationTypes` in your adapter:
   - Each type has a `HubDeliveryConfig` (channel, audio stream, alarm mode, DND bypass, etc.)
   - Built-in types available without custom definitions: `regular`, `alarm`, `special`, `silent`.

### Phase 3: Use Notifications in Your UI

**Option A: Universal Creator (recommended)**
1. Create a creator context at `features/X/notifications/X_notification_creator_context.dart`:
   - Define `variables`, `availableActions`, `defaults`, `conditions`, optional `notificationKinds`.
2. Drop `UniversalReminderSection` widget into any add/edit screen:
   ```dart
   UniversalReminderSection(
     creatorContext: XCreatorContext.forEntity(entityId: id, entityName: name),
     isDark: isDark,
   )
   ```

**Option B: Direct scheduling (programmatic)**
- Call `NotificationHub().schedule(NotificationHubScheduleRequest(...))` from a scheduler or service.

### File Checklist

| File | Purpose |
|------|---------|
| `core/notifications/models/notification_hub_modules.dart` | Module ID + ID range |
| `features/X/notifications/X_notification_adapter.dart` | Adapter: metadata, tap/action handlers |
| `features/X/notifications/X_notification_contract.dart` | Constants: types, sections, extras |
| `features/X/notifications/X_notification_creator_context.dart` | Creator: variables, actions, defaults |
| `features/X/X_module.dart` | Register adapter in init() |
| Any add/edit screen | Drop in `UniversalReminderSection` |

### Key References

- Adapter interface: `core/notifications/adapters/mini_app_notification_adapter.dart`
- Creator context: `core/notifications/models/notification_creator_context.dart`
- Schedule request: `core/notifications/models/notification_hub_schedule_request.dart`
- Reminder widget: `features/notifications_hub/presentation/widgets/universal_reminder_section.dart`
- Finance adapter (full example): `features/finance/notifications/finance_notification_adapter.dart`
