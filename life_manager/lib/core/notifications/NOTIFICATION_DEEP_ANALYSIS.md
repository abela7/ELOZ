# Notification System – Complete Deep Analysis

> Exhaustive audit of every notification path across Finance, Sleep, Habit, Task.

---

## 1. Two Pipelines – Architecture Overview

The app uses **two parallel notification pipelines**:

### Legacy Pipeline (NotificationService directly)
```
User Action → ReminderManager → NotificationService → FlutterLocalNotificationsPlugin / AlarmService
```
- **Tasks**: TaskProvider → ReminderManager.scheduleRemindersForTask → NotificationService.scheduleTaskReminder
- **Habits**: HabitProvider → ReminderManager.scheduleRemindersForHabit → HabitReminderService → NotificationService.scheduleHabitReminder
- **Sleep** (bedtime/wake-up): SleepReminderService → NotificationService.scheduleSimpleReminder
- Payload format: `task|taskId|reminderType|value|unit` or `habit|habitId|...` or `simple_reminder|id`

### Hub Pipeline (NotificationHub)
```
Scheduler → NotificationHub.schedule() → NotificationService.scheduleHubReminder
```
- **Finance**: FinanceNotificationScheduler → NotificationHub.schedule
- **Universal** (Tasks/Habits/Sleep wind-down via Universal Creator): UniversalNotificationScheduler → NotificationHub.schedule
- Payload format: `moduleId|entityId|reminderType|value|unit|key1:val1|key2:val2...`

### Dual Registration
All modules register adapters with NotificationHub for **tap/action handling**, even if scheduling uses the legacy path:
- `TaskNotificationAdapter` registered in `TasksModule.init()`
- `HabitNotificationAdapter` registered in `HabitsModule.init()`
- `SleepNotificationAdapter` registered in `SleepModule.init()`
- `FinanceNotificationAdapter` registered in `FinanceModule.init()`

---

## 2. Notification Lifecycle Events (History Tab)

These are **log entries** written by NotificationHub, not OS alarms:

| Event       | Meaning                                                              |
|-------------|----------------------------------------------------------------------|
| **Scheduled** | Hub successfully scheduled an OS alarm                             |
| **Delivered** | Notification shown to user (if tracked)                            |
| **Tapped**    | User tapped the notification                                       |
| **Action**    | User used an action button (Mark Done, Snooze, Skip, etc.)        |
| **Snoozed**   | Notification was snoozed (rescheduled)                            |
| **Cancelled** | Alarm was cancelled (sync, module off, entity delete, user action) |
| **Failed**    | Schedule attempt failed (time past, module disabled, etc.)         |
| **Missed**    | Notification was not delivered (OS killed it, etc.)                |

Dashboard "Activity Today" shows:
- **Scheduled** chip = `totalPending` (current OS alarm count, NOT "scheduled today" log entries)
- **Tapped** chip = `tappedToday` (from history logs)
- **Actions** chip = `actionToday` (from history logs)
- **Failed** chip = `failedToday` (from history logs)

---

## 3. Startup / Resume / Background Sync Flow

### App Startup (`main.dart`)
```
main() →
  ├─ TasksModule.init()    → registers TaskNotificationAdapter (Hub)
  ├─ HabitsModule.init()   → registers HabitNotificationAdapter (Hub)
  ├─ SleepModule.init()    → registers SleepNotificationAdapter (Hub)
  ├─ FinanceModule.init()  → registers FinanceNotificationAdapter + syncSchedules (Hub)
  └─ Post-frame:
      ├─ ReminderManager().initialize()             → initializes legacy NotificationService
      ├─ NotificationHub().initialize()              → initializes Hub
      ├─ cancelForModule('sleep_reminder')           → legacy sleep migration cleanup
      ├─ UniversalNotificationScheduler().syncAll()  → syncs Universal (Hub)
      ├─ If timezone changed: NotificationRecoveryService.runRecovery()
      ├─ NotificationRecoveryService.runHealthCheckIfNeeded()
      └─ WorkManager.registerPeriodicTask()          → background recovery every 15 min
```

### App Resume (after 15+ min background)
```
NotificationSystemRefresher.onAppResumed() →
  └─ NotificationRecoveryService.runRecovery() →
      ├─ FinanceNotificationScheduler().syncSchedules()
      └─ UniversalNotificationScheduler().syncAll()
```

### Background Recovery (WorkManager, every 15 min)
```
NotificationRecoveryService.runRecovery(bootstrapForBackground: true) →
  ├─ Bootstraps Hive + modules
  ├─ FinanceNotificationScheduler.syncSchedules() (Hub)
  └─ UniversalNotificationScheduler.syncAll() (Hub)
```

---

## 4. Finance Module – Complete

### Scheduling
- **FinanceNotificationScheduler** (Hub pipeline only)
- Sections: Bills, Debts, Lending, Budgets, Savings Goals, Recurring Income
- `syncSchedules()` = cancel ALL finance → rebuild from current data
- `syncBill()`, `syncDebt()`, `syncRecurringIncome()` = entity-level sync

### When scheduling runs
| Trigger | Method | File |
|---------|--------|------|
| App startup | `syncSchedules()` | `finance_module.dart:476, 506` |
| App resume (15+ min) | `syncSchedules()` via recovery | `notification_recovery_service.dart:51` |
| Bill add/edit | `syncBill()` | `add_bill_screen.dart:1522`, `bill_service.dart:120` |
| Debt add/edit | `syncDebt()` | `debts_screen.dart:1458, 3470` |
| Income add/edit | `syncRecurringIncome()` | `add_recurring_income_screen.dart:680` |
| Settings change | `syncSchedules()` | `finance_notification_settings_screen.dart:91` |
| Profile change | `syncSchedules()` | `bill_notification_profiles_screen.dart:193` |
| Notification action (mark paid) | `syncBill/syncDebt/syncIncome` | `finance_notification_adapter.dart:280, 298, 313` |
| Hub page refresh | `syncSchedules()` | `hub_finance_module_page.dart:99` |

### Cancel on delete
| Entity | Cancel Method | File | Status |
|--------|---------------|------|--------|
| Bill | `cancelBillNotifications(billId)` | `add_bill_screen.dart:1587`, `bill_service.dart:101` | ✅ GOOD |
| Debt | `cancelDebtNotifications(debtId)` | `debts_screen.dart:2116`, `lending_screen.dart:935` | ✅ GOOD |
| Budget | None explicit | `budgets_screen.dart:173` | ⚠️ GAP (next full sync clears) |
| Savings Goal | None explicit | `savings_goals_screen.dart:201` | ⚠️ GAP (next full sync clears) |
| Recurring Income | `refreshIncomeNotifications()` after delete | `recurring_income_screen.dart:468` | ⚠️ PARTIAL |

### Orphan risk
**LOW** – `syncSchedules()` does `cancelForModule(finance)` before rescheduling. Even if explicit cancel is missed on delete, the next full sync (startup, resume, or 15-min background) drops the orphan.

---

## 5. Sleep Module – Complete

### Scheduling
Uses **both pipelines**:

| Feature | Pipeline | Scheduler |
|---------|----------|-----------|
| Bedtime reminder | Legacy | `SleepReminderService → NotificationService.scheduleSimpleReminder` |
| Wake-up reminder | Legacy | `SleepReminderService → NotificationService.scheduleSimpleReminder` |
| Wind-down reminders | Hub | `UniversalNotificationScheduler → NotificationHub.schedule` |

### When scheduling runs
| Trigger | Method | File |
|---------|--------|------|
| Sleep screen open | `syncAll()` | `sleep_screen.dart:38` |
| Settings change | `syncAll()` | `sleep_settings_screen.dart:58, 200, 212` |
| Hub sleep page refresh | `syncAll()` | `hub_sleep_module_page.dart:93` |
| App startup | `syncAll()` via main.dart | `main.dart:107` |
| App resume (15+ min) | `syncAll()` via recovery | `notification_recovery_service.dart:56` |
| Wind-down save | `syncAll()` via repository | `wind_down_notification_repository.dart:103` |

### Cancel on delete/disable
| Entity | Cancel Method | File | Status |
|--------|---------------|------|--------|
| Wind-down disable | `cancelForNotification()` | `wind_down_settings_screen.dart:88, 692` | ✅ GOOD |
| Reset all sleep | `cancelForModule('sleep_reminder')` + `cancelForModule('sleep')` | `sleep_settings_screen.dart:465-466` | ✅ GOOD |
| Universal notification delete | Delete from repo + cancel | `sleep_settings_screen.dart:460` | ✅ GOOD |

### Orphan risk
**LOW** – Wind-down uses weekday-based entityIds (`sleep_winddown_mon`, etc.), not entity IDs that get deleted. Bedtime/wake-up are config-based.

---

## 6. Habit Module – Complete ⚠️

### Scheduling
Uses **both pipelines**:

| Feature | Pipeline | Scheduler |
|---------|----------|-----------|
| Habit reminders (legacy) | Legacy | `HabitReminderService → NotificationService.scheduleHabitReminder` |
| Universal reminders (Hub creator) | Hub | `UniversalNotificationScheduler → NotificationHub.schedule` |

### When legacy scheduling runs
| Trigger | Method | File |
|---------|--------|------|
| Habit create | `scheduleRemindersForHabit()` | `habit_providers.dart:265` |
| Habit update | `rescheduleRemindersForHabit()` | `habit_providers.dart:215` |

### When Hub scheduling runs
| Trigger | Method | File |
|---------|--------|------|
| Universal notification create/update | `syncForEntity()` | `universal_notification_creator_sheet.dart:217` |
| App startup | `syncAll()` | `main.dart:107` |
| App resume (15+ min) | `syncAll()` via recovery | `notification_recovery_service.dart:56` |

### Cancel on delete – DETAILED AUDIT
| Delete Location | Cancel Method | Status |
|----------------|---------------|--------|
| `habit_providers.dart:227` – `deleteHabit` | ✅ `cancelRemindersForHabit(id)` at line 235 | ✅ GOOD (legacy) |
| `habit_providers.dart:244` – `archiveHabit` | ✅ `cancelRemindersForHabit(id)` at line 251 | ✅ GOOD (legacy) |
| `quit_habit_data_reset_service.dart:57` – `deleteHabit` | ✅ `_cancelReminderSafely(id)` at line 56 | ✅ GOOD (legacy) |
| `sample_habit_generator.dart:894` – `deleteHabit` | ❌ None | ⚠️ GAP |
| `habits_screen.dart:1183` – via provider | ✅ Provider cancels | ✅ GOOD (legacy) |
| `view_all_habits_screen.dart:435, 1591` – via provider | ✅ Provider cancels | ✅ GOOD (legacy) |
| `habit_detail_modal.dart:3521` – via provider | ✅ Provider cancels | ✅ GOOD (legacy) |

### ⚠️ CRITICAL GAPS

1. **Universal notifications NOT cleaned on habit delete**:
   - `habit_providers.dart` calls `cancelRemindersForHabit()` which cancels legacy notifications.
   - But `UniversalNotificationRepository.deleteByEntity(habitId)` is **NEVER called**.
   - Universal notifications for the habit remain in the repo.
   - On next `syncAll()`, `_getHabitDueDate(entityId)` returns null (habit deleted) → skips scheduling → **but does NOT cancel the existing OS alarm**.
   - Result: OS alarm fires for deleted habit until it expires or app does a full OS alarm refresh.

2. **UniversalNotificationScheduler.syncAll() does not cancel when entity is missing**:
   - For each enabled notification: calls `_scheduleOne(n)`
   - `_scheduleOne` calls `_getDueDateForEntity()` → returns null for deleted habit
   - Returns early with "no due date" result → **no cancel issued**
   - The previously scheduled OS alarm remains active

3. **sample_habit_generator.dart:894** deletes habits without any cancellation.

### Orphan risk
**HIGH** – Both legacy cancellation gaps (sample generator) and Hub pipeline gaps (Universal notifications not cleaned) exist.

---

## 7. Task Module – Complete

### Scheduling
Uses **both pipelines**:

| Feature | Pipeline | Scheduler |
|---------|----------|-----------|
| Task reminders (legacy) | Legacy | `ReminderManager → NotificationService.scheduleTaskReminder` |
| Simple reminders | Legacy | `ReminderProvider → NotificationService.scheduleSimpleReminder` |
| Universal reminders (Hub creator) | Hub | `UniversalNotificationScheduler → NotificationHub.schedule` |

### When legacy scheduling runs
| Trigger | Method | File |
|---------|--------|------|
| Task create | `scheduleRemindersForTask()` | `task_providers.dart:181` |
| Task update | `rescheduleRemindersForTask()` | `task_providers.dart:229, 390, 755, 918, 1004, 1200, 1248, 1340, 1441, 1495` |
| Simple reminder create | `scheduleSimpleReminder()` | `reminder_providers.dart:74` |

### Cancel on delete – DETAILED AUDIT
| Delete Location | Cancel Method | Status |
|----------------|---------------|--------|
| `task_providers.dart:405` – `deleteTask` | ✅ `handleTaskDeleted → cancelRemindersForTask` at line 434 | ✅ GOOD (legacy) |
| `task_providers.dart:600` – `completeTask` | ✅ `handleTaskCompleted → cancelRemindersForTask` | ✅ GOOD (legacy) |
| `task_providers.dart:375` – `_regenerateRecurrenceSeries` | ✅ `handleTaskDeleted` at line 376 | ✅ GOOD |
| `task_providers.dart:468` – `deleteRecurringSeries` | ✅ `handleTaskDeleted` at line 469 | ✅ GOOD |
| `task_providers.dart:508` – `deleteRoutineSeries` | ✅ `handleTaskDeleted` at line 509 | ✅ GOOD |
| `task_providers.dart:581` – `cleanupExcessiveRecurringTasks` | ✅ `handleTaskDeleted` at line 582 | ✅ GOOD |
| `task_providers.dart:1074` – `cleanupOrphanedPostponeTasks` | ❌ None | ⚠️ GAP |
| All UI screens | ✅ Via provider | ✅ GOOD |

### ⚠️ GAPS
1. **`cleanupOrphanedPostponeTasks` (task_providers.dart:1074)** – deletes tasks without cancellation.
2. **Universal notifications NOT cleaned on task delete** – same gap as Habit: `UniversalNotificationRepository.deleteByEntity(taskId)` never called.

### Orphan risk
**MEDIUM** – Legacy cancel is mostly covered except `cleanupOrphanedPostponeTasks`. Hub Universal gap same as Habit.

---

## 8. Cancellation Methods Reference

### What each method cancels

| Method | OS Alarms | Native Alarms | Repo Entries | Log Entry |
|--------|-----------|---------------|--------------|-----------|
| `cancelAllHabitReminders` (NotificationService) | ✅ | ✅ | ❌ | ❌ |
| `cancelAllTaskReminders` (NotificationService) | ✅ | ✅ | ❌ | ❌ |
| `cancelRemindersForHabit` (ReminderManager) | ✅ | ✅ | ❌ | ❌ |
| `cancelRemindersForTask` (ReminderManager) | ✅ | ✅ | ❌ | ❌ |
| `cancelForEntity` (NotificationHub) | ✅ | ❌ | ❌ | ✅ |
| `cancelForModule` (NotificationHub) | ✅ | ❌ | ❌ | ✅ |
| `cancelByNotificationId` (NotificationHub) | ✅ | ❌ | ❌ | ✅ |
| `cancelBillNotifications` (FinanceScheduler) | ✅ | ❌ | ❌ | ✅ (via Hub) |
| `cancelDebtNotifications` (FinanceScheduler) | ✅ | ❌ | ❌ | ✅ (via Hub) |
| `cancelForNotification` (UniversalScheduler) | ✅ | ❌ | ❌ | ✅ (via Hub) |
| `deleteByEntity` (UniversalNotificationRepo) | ❌ | ❌ | ✅ | ❌ |
| `cancelPendingNotificationById` (NotificationService) | ✅ | ✅ | ❌ | ❌ |
| `AlarmService.cancelAlarm` | ❌ | ✅ | ❌ | ❌ |

### Key insight
`deleteByEntity` (UniversalNotificationRepository) exists but is **NEVER called** anywhere in the codebase. This is the root cause of orphaned Universal notifications.

---

## 9. Complete Gap Summary

### CRITICAL (orphaned notifications)

| # | Gap | Module | Impact |
|---|-----|--------|--------|
| 1 | `UniversalNotificationRepository.deleteByEntity()` never called on entity delete | Habit, Task | Universal notifications persist after entity deleted; OS alarm fires for deleted entity |
| 2 | `UniversalNotificationScheduler.syncAll()` does not cancel when `_getDueDateForEntity()` returns null | All | Orphaned OS alarms not cleaned during sync |

### MODERATE (specific code paths)

| # | Gap | Module | Impact |
|---|-----|--------|--------|
| 3 | `sample_habit_generator.dart:894` deletes habits without cancellation | Habit | Dev/sample data cleanup leaves orphans |
| 4 | `task_providers.dart:1074` `cleanupOrphanedPostponeTasks` deletes without cancellation | Task | Rare edge case, postponed task orphans |
| 5 | Budget delete has no explicit notification cancel | Finance | Low risk (next full sync clears) |
| 6 | Savings Goal delete has no explicit notification cancel | Finance | Low risk (next full sync clears) |
| 7 | Recurring Income delete has no explicit cancel (only refresh after) | Finance | Low risk (next full sync clears) |

### NOT AN ISSUE

| Item | Why |
|------|-----|
| Finance bill/debt delete | `cancelBillNotifications` / `cancelDebtNotifications` called |
| Sleep wind-down | Config-based entities, proper cancellation exists |
| Sleep reset all | `cancelForModule` called for both legacy and Hub modules |
| `AlarmService.cancelAllAlarms()` not implemented | Individual alarm cancellation works; bulk cancel would only be for full reset |

---

## 10. Recommended Fixes (Priority Order)

### Fix 1 – Universal sync: cancel when entity is missing
In `UniversalNotificationScheduler._scheduleOne()`, when `_getDueDateForEntity()` returns null, call `_cancelForNotification(n)` before returning.

### Fix 2 – Habit delete: clean Universal notifications
In `habit_providers.dart deleteHabit()`, after `cancelRemindersForHabit()`, add:
- `UniversalNotificationRepository().deleteByEntity(habitId)` (removes repo entries)
- `NotificationHub().cancelForEntity(moduleId: 'habit', entityId: habitId)` (cancels Hub-scheduled OS alarms)

### Fix 3 – Task delete: clean Universal notifications
In `task_providers.dart handleTaskDeleted()`, add same Universal cleanup as Habit.

### Fix 4 – Sample habit generator
In `sample_habit_generator.dart:894`, add `cancelRemindersForHabit(habit.id)` before delete.

### Fix 5 – Orphaned postpone task cleanup
In `task_providers.dart:1074`, add `handleTaskDeleted()` before delete.
