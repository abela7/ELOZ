# Notification Tracking Guide

How to trace **where** a notification comes from, **where** it goes, and **when** it fires when the source shows as "unknown" in History.

## Quick Reference: Notification ID Ranges

| Module   | ID Range     | Source                         |
|----------|--------------|--------------------------------|
| Task     | 1–99,999     | Task reminders, Universal Task |
| Habit    | 100,000–199,999 | Habit reminders, Universal Habit |
| Finance  | 200,000–299,999 | Bills, debts, budgets         |
| Sleep    | 300,000–309,999 | Wind-down, bedtime, wake-up  |
| Universal (hashCode) | Other | Task/Habit/Sleep via Universal Creator |

Universal reminders (from Universal Notification Creator) use `n.id.hashCode & 0x7FFFFFFF` as their notification ID, so they fall outside the fixed ranges.

## Tracing Flow: From → To → When

### 1. **From** (source)

- **Contract**: Module + section + entity ID
  - Example: `sleep` + `winddown` + `sleep_winddown_mon`
- **Creator Context**: Where the reminder is configured (e.g. `FinanceNotificationCreatorContext.forBill`, `SleepNotificationCreatorContext.forWindDown`)
- **Repository**: Where the definition is stored (`UniversalNotificationRepository`, `WindDownNotificationRepository`, or entity-owned like `bill.remindersJson`)

### 2. **To** (scheduling & delivery)

- **Scheduler** builds `NotificationHubScheduleRequest` and calls `NotificationHub.schedule()`
- **Payload** format: `moduleId|entityId|reminderType|reminderValue|reminderUnit|section:X|...`
- **OS** stores the notification; payload is returned in `getDetailedPendingNotifications()`

### 3. **When** (cancellation & logging)

- **Cancel** paths:
  - `UniversalNotificationScheduler._cancelForNotification(n)` – passes full payload from UniversalNotification
  - `NotificationHub.cancelByNotificationId()` – uses payload or resolves via `NotificationSourceResolver` if payload is missing/unparseable
- **Log entry** includes: `moduleId`, `entityId`, `notificationId`, `payload`, `title`, `body`, `metadata`

## Resolving Unknown Notifications

When History shows "Source unknown":

1. **Notification ID** (e.g. `#220399490`): Use for tracing.
2. **Log ID** (e.g. `1771070505818978-1`): Use when searching logs.
3. **`NotificationSourceResolver.resolve(notificationId)`**:
   - If ID is in a known range → returns module (task, habit, finance, sleep)
   - If outside range → scans `UniversalNotificationRepository` for `id.hashCode & 0x7FFFFFFF == notificationId`

### If resolution still fails

- The notification may have been **deleted** from the Universal repo (e.g. after sync cancels it).
- It may be a **legacy** notification (pre–Notification Hub).
- Search logs for `notificationId` or `Log ID` to see scheduling/cancel activity.

## Ensuring Correct Source Tracking

1. **When cancelling**, pass `payload` from the original schedule (or `moduleId`/`section` if available).
2. **`UniversalNotificationScheduler`** uses `_buildPayloadForLogging(n)` so cancellation logs include the correct payload.
3. **`NotificationSourceResolver`** is used as a fallback when payload is null or unparseable.
