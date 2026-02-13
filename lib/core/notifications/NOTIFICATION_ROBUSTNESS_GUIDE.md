# Notification Hub Robustness Guide

This document explains how the notification system achieves reliability when the app is backgrounded, killed, or the device is rebooted. It also describes OEM limitations and recommended user guidance.

---

## Current Architecture (Already Strong)

### 1. **Dual Path: Plugin + Native AlarmManager**

| Path | Use Case | Persistence | Boot Handling |
|------|----------|-------------|---------------|
| `flutter_local_notifications` (zonedSchedule) | Standard reminders (wind-down, tasks, habits, finance) | Plugin stores in SQLite; AlarmManager delivers | `ScheduledNotificationBootReceiver` reschedules on BOOT_COMPLETED |
| Native `AlarmService` + `AlarmPlayerService` | Special task alarms (wake-up, DND bypass, full-screen) | `AlarmBootReceiver` saves to SharedPreferences | Restores from prefs on BOOT_COMPLETED |

Both paths survive reboot. The plugin uses its own persistence; the native path uses explicit save/restore.

### 2. **Schedule Modes (Android)**

- **Standard reminders:** `AndroidScheduleMode.exactAllowWhileIdle`  
  Exact time; fires in Doze/low-power; does not show in status bar.

- **Special alarms:** `AlarmManager.setAlarmClock()`  
  Uses `AlarmClockInfo`; shows in status bar; often treated more favourably by OEMs.

### 3. **Sync Triggers**

| Trigger | What Happens |
|---------|--------------|
| App cold start | `UniversalNotificationScheduler().syncAll()` + Finance sync |
| App resume (15+ min in background) | `NotificationSystemRefresher` triggers Finance + Universal sync |
| Module-specific | Sleep settings save, bill payment, etc. |

This covers:
- **App killed:** Next open does a full sync.
- **OS cleared alarms:** Resume-after-15min or next open resyncs.
- **Device reboot:** Boot receivers reschedule.

### 4. **Permissions (Android)**

| Permission | Purpose |
|------------|---------|
| `SCHEDULE_EXACT_ALARM` | Exact timing |
| `USE_EXACT_ALARM` | Required on Android 14+ for exact alarms |
| `RECEIVE_BOOT_COMPLETED` | Boot receivers run |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Reduce OEM killing |
| `ACCESS_NOTIFICATION_POLICY` | DND bypass for alarm-type notifications |

---

## OEM Limitations (Cannot Fully Fix in Code)

Manufacturers (Xiaomi, Huawei, OnePlus, Samsung, OPPO, etc.) apply battery optimizations that can:

1. Force-stop apps after a few minutes in background.
2. Delay or drop AlarmManager alarms for “untrusted” apps.
3. Clear alarms when the app is swiped away (Recent Apps).

**Best mitigations:**

1. **User action:** Disable battery optimization for the app (Settings → Apps → Life Manager → Battery → Unrestricted / Don’t optimize).
2. **alarmClock:** For critical reminders (e.g. wind-down), consider `AndroidScheduleMode.alarmClock`; it may be treated more like system alarms.
3. **Sync on open:** Already done via cold-start and resume-after-15min sync.

---

## When Notifications Fire

| Scenario | Expected Behavior |
|----------|-------------------|
| App in foreground | Alarm fires → plugin/native shows notification |
| App in background | Alarm fires → OS delivers; no app process needed |
| App killed | Alarm fires → OS delivers; no app process needed |
| Device in Doze | `exactAllowWhileIdle` / `setAlarmClock` can fire (subject to OEM) |
| Device rebooted | Boot receivers reschedule; alarms fire at their set times |
| OEM battery optimization ON | May delay or drop alarms; user must disable for app |

---

## Recommendations

### Already in Place

- Exact timing with Doze support (`exactAllowWhileIdle` / `setAlarmClock`)
- Boot receivers for plugin and native alarms
- Sync on cold start and after long background
- Correct permissions and battery-optimization request
- Dedicated native path for alarm-type, DND-bypassing notifications

### Implemented Enhancements (nek12.dev guide – 100% result)

1. **WorkManager safety net (Layer 3):** Periodic task every 15 minutes resyncs Finance + Universal notifications. Runs when app is killed; bootstraps Hive + modules. Catches alarms dropped by OEM battery optimization.

2. **Timezone/time change + MY_PACKAGE_REPLACED (Layer 2):**
   - `NotificationSystemEventReceiver` listens for `TIMEZONE_CHANGED` and `TIME_SET`; sets a flag. On next app open, Dart resyncs.
   - `AlarmBootReceiver` extended with `MY_PACKAGE_REPLACED` so native alarms restore after app updates.

3. **alarmClock for critical reminders (Layer 3):** Wind-down reminders use `AndroidScheduleMode.alarmClock` for better OEM reliability (shows in status bar).

4. **App-open health check (Layer 4):** If we expect notifications (Universal or Finance enabled) but OS has 0 pending, run full recovery automatically.

5. **OEM user guidance (Layer 5):** Hub Global Settings shows a "Reliability" section with guidance and "Open Battery Settings" for Android.

### Optional Future Enhancements

1. **Extend alarmClock to more sections** (bills, debts)  
   - Pros: Often more reliable on aggressive OEMs.  
   - Cons: Shows in status bar; may be reserved for “true” alarms.

2. **In-app guidance**  
   - Add a short explainer in Hub Settings: “For best reliability, disable battery optimization for this app.”

3. **Periodic health check**  
   - Optional: on each app open, compare Hub’s “should be scheduled” list with `getPendingNotificationRequests()` and resync if there are gaps. Trade-off: more work vs. catching edge cases.

### What to Avoid

- Polling or frequent background sync (battery impact).
- WorkManager for time-critical reminders (not suitable for exact timing).
- Over-reliance on FCM for local reminders (needs network, adds complexity).

---

## Summary

The Notification Hub is built for robustness:

- Two persistence paths (plugin + native) both survive reboot.
- Sync on cold start and long background covers “app killed” and “OS cleared alarms”.
- `exactAllowWhileIdle` and `setAlarmClock` support Doze and alarm-style delivery.

The main remaining risk is OEM battery optimization. Users who need very reliable reminders should disable battery optimization for the app. The architecture is sound; OEM behaviour is the limiting factor.
