# Notification Stress Protocol (Device-Level Manual Test)

Run this protocol on a **physical Android device** to verify task/habit notifications, multi-reminders, snooze, orphan cleanup, and Hub reporting. Record pass/fail for each step.

---

## Preconditions

- [ ] App built and installed: `flutter run` or release APK
- [ ] Notification permission granted
- [ ] Exact alarm permission granted (Android 12+)

---

## 1. Task Multi-Reminder (Before + At + After)

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1.1 | Create a task with due time **5 minutes from now** | Task saved | |
| 1.2 | Add reminders: **15 min before**, **At task time**, **5 min after** | All 3 chips visible in Active reminders | |
| 1.3 | Save task | No errors; task appears in list | |
| 1.4 | Wait for **15 min before** notification | Notification fires ~15 min before due time | |
| 1.5 | Wait for **At task time** notification | Notification fires at exact due time | |
| 1.6 | Wait for **5 min after** notification | Notification fires 5 min after due time | |
| 1.7 | Open Notification Hub → History | All 3 events appear (scheduled/delivered) | |

---

## 2. Habit Reminder

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 2.1 | Create a habit with one reminder **5 minutes from now** | Habit saved | |
| 2.2 | Wait for notification | Notification fires at scheduled time | |
| 2.3 | Open Notification Hub → History | Habit event appears | |

---

## 3. Snooze Flow (Task)

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 3.1 | Create a task with due time **2 minutes from now**, reminder **At task time** | Task saved | |
| 3.2 | When notification appears, tap **Snooze** | Notification dismissed; no crash | |
| 3.3 | Wait for default snooze duration (e.g. 10 min) | Snoozed notification fires again | |
| 3.4 | Snooze again | Second snooze fires after duration | |
| 3.5 | Open Notification Hub → Activity Today | **Snoozed** chip shows count ≥ 2 | |
| 3.6 | Tap **Snoozed** chip | List of snooze events with duration | |
| 3.7 | Open Notification Hub → History → filter **Snoozed** | Snooze entries visible | |
| 3.8 | Tap a snooze entry | Detail sheet shows **Snooze** section with duration | |

---

## 4. Snooze Flow (Habit)

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 4.1 | Create a habit with reminder **2 minutes from now** | Habit saved | |
| 4.2 | When notification appears, tap **Snooze** | Notification dismissed; no crash | |
| 4.3 | Wait for snooze duration | Snoozed notification fires again | |
| 4.4 | Open Notification Hub → Activity Today | **Snoozed** chip shows count ≥ 1 | |

---

## 5. App Restart / Recovery

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 5.1 | Create a task with reminder **10 minutes from now** | Task saved | |
| 5.2 | Force-stop the app (Settings → Apps → Life Manager → Force stop) | App closed | |
| 5.3 | Wait until reminder time | Notification still fires (WorkManager / AlarmManager) | |
| 5.4 | Optional: Reboot device, then wait for reminder | Notification fires after reboot | |

---

## 6. Orphan Cleanup

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 6.1 | Create a task with reminder **5 minutes from now** | Task saved | |
| 6.2 | Delete the task **before** the reminder fires | Task removed | |
| 6.3 | Wait past the original reminder time | **No** notification for deleted task | |
| 6.4 | Open Notification Hub → Settings → **Orphaned Notifications** | Entry for deleted task may appear (or none if cleanup ran) | |
| 6.5 | If orphans listed: tap **Cancel All** | Orphans cleared | |
| 6.6 | Create a habit with reminder, then delete the habit | Same as 6.2–6.5 for habit | |

---

## 7. Hub Report Verification

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 7.1 | Open Notification Hub → Overview | Dashboard loads; no crash | |
| 7.2 | Check **Activity Today** chips | Scheduled, Tapped, Actions, **Snoozed**, Failed visible | |
| 7.3 | Tap **Snoozed** (after having snoozed at least once) | Sheet opens with "Snoozed Today" and list | |
| 7.4 | Open **History** tab | Entries load; filters work | |
| 7.5 | Filter by **Snoozed** | Only snooze events shown | |
| 7.6 | Filter by **Task** module | Only task events shown | |
| 7.7 | Filter by **Habit** module | Only habit events shown | |
| 7.8 | Open Task module page → Overview | Stats and scheduled section load | |
| 7.9 | Open Habit module page → Overview | Stats and scheduled section load | |

---

## 8. Edge Cases

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 8.1 | Create task with **5 reminders** (e.g. 1h before, 30m before, at, 5m after, 15m after) | All 5 saved; no crash | |
| 8.2 | Edit task and change due time | Reminders reschedule; old ones cancelled | |
| 8.3 | Create task with due time **in the past** | Past reminder not scheduled (or skipped) | |
| 8.4 | Disable notifications in app settings | New reminders not scheduled; existing may still fire until cleanup | |
| 8.5 | Re-enable notifications | New reminders work again | |

---

## Summary Matrix

| Category | Steps | Passed | Failed |
|----------|-------|--------|--------|
| 1. Task Multi-Reminder | 7 | | |
| 2. Habit Reminder | 3 | | |
| 3. Snooze (Task) | 8 | | |
| 4. Snooze (Habit) | 4 | | |
| 5. App Restart | 4 | | |
| 6. Orphan Cleanup | 6 | | |
| 7. Hub Report | 9 | | |
| 8. Edge Cases | 5 | | |
| **Total** | **46** | | |

---

## Notes

- Record device model, Android version, and any OEM (e.g. Samsung, Xiaomi) for reproducibility.
- If a step fails, note exact behavior and any error messages.
- Snooze duration comes from Notification Settings; verify default (e.g. 10 min) before testing.
