# Notification Integration Guide

This is the source-of-truth guide for integrating notifications into any new mini app.

## Main Goal

Add module notifications through one robust path:

- Hub policy authority
- deterministic IDs + module ranges
- idempotent cancel-then-schedule
- reliable recovery/resync
- safe tap/action handling
- delete cleanup with no resurrection

## Quick Start

If you are integrating a new module quickly, do this first:

1. Reserve a module ID + non-overlapping ID range in `notification_hub_modules.dart`.
2. Implement a `MiniAppNotificationAdapter` for the module.
3. Register the adapter in `<module>_module.dart`.
4. Persist reminder rules in universal storage (not a new legacy path).
5. Trigger `NotificationSystemRefresher.instance.resyncAll(...)` after create/edit/delete.
6. Run the mandatory validation checklist before merge.

## High-Level Architecture

Text flow:

1. Rule creation/edit in module UI
2. Persist universal rule definitions
3. Trigger hub resync/apply
4. Hub policy gate + deterministic ID generation
5. OS schedule (AlarmManager / flutter_local_notifications)
6. Hub logging + trace metrics
7. Notification tap/action routed through handler + adapter
8. Recovery/resync keeps schedules correct after lifecycle/system events
9. Entity delete runs canonical cleanup (OS + stored definitions)

ASCII diagram:

```text
Module UI (create/edit rule)
  -> UniversalNotificationRepository.save(...)
  -> NotificationSystemRefresher.resyncAll(...)
  -> NotificationRecoveryService.runRecovery(...)
  -> UniversalNotificationScheduler.syncAllWithMetrics()
  -> NotificationHub.schedule(...)
  -> NotificationService.scheduleHubReminder(...)
  -> OS pending notifications/alarms
  -> Hub logs (history + trace)

Tap/Action:
OS -> NotificationHandler -> NotificationHub.handleTap/handleAction
   -> module adapter (onNotificationTapped/onNotificationAction)

Delete:
module delete hook -> Hub cancel + universal definition delete
                  -> recovery sees nothing to restore
```

## Rules vs Instances

- Rule: persistent user intent (for example recurrence, message, action type, entity binding).
- Instance: concrete scheduled fire at a specific time with a deterministic notification ID.
- Scheduler responsibility: derive upcoming instances from rules for the active horizon window.
- Recovery responsibility: rebuild missing instances from rules, never from stale pending state.
- Delete responsibility: remove rules and cancel all derived instances for that entity.

## Golden Rules (Must Not Break)

1. Hub policy is authoritative.
2. New modules must not schedule directly from module code using ad-hoc OS calls.
3. Every scheduled notification ID must be deterministic and inside that module's ID range.
4. Scheduling must be idempotent: cancel-then-schedule for the same logical reminder.
5. Delete cleanup must remove OS pending entries and stored definitions, so recovery cannot resurrect deleted entities.
6. Quiet hours must be enforced in the shared scheduling pipeline, not in module-specific duplicated logic.
   - Standard rule: if a reminder does not bypass quiet hours, defer it to the next allowed time outside the quiet window.
7. Tap/action handlers must validate current state (entity exists, module enabled) before mutating data.

## Don't-Do-This (Common Mistakes)

- Do not call scheduling plugins directly from feature/module UI code.
- Do not generate notification IDs from random/time-based values.
- Do not keep separate module-enable flags that can drift from Hub policy.
- Do not schedule without cancel-then-schedule idempotent behavior.
- Do not execute tap/action mutations without re-validating entity existence and module policy.
- Do not leave legacy reminder state after entity deletion.

## Step-by-Step: Add Notifications to a New Mini App

Use this checklist in order:

1. Reserve module identity.
   - Add module ID constant and non-overlapping ID range in `lib/core/notifications/models/notification_hub_modules.dart`.
   - Define module metadata (`NotificationHubModule`) in your adapter.

2. Implement adapter.
   - Create `lib/features/<module>/notifications/<module>_notification_adapter.dart`.
   - Implement `MiniAppNotificationAdapter` from `lib/core/notifications/adapters/mini_app_notification_adapter.dart`.
   - Implement tap/action handlers and optional variable resolution.

3. Register adapter in module init.
   - Register in `<module>_module.dart` using `NotificationHub().registerAdapter(...)`.
   - Follow existing module patterns in:
     - `lib/features/tasks/tasks_module.dart`
     - `lib/features/habits/habits_module.dart`
     - `lib/features/finance/finance_module.dart`
     - `lib/features/sleep/sleep_module.dart`

4. Define notification rule storage.
   - Preferred: universal definitions in `UniversalNotificationRepository`.
   - Avoid new legacy per-module scheduling stores.

5. Wire rule UI.
   - Use universal creator flows (`UniversalReminderSection`) where possible.
   - For custom UI, still write into universal definitions and trigger shared resync/apply.

6. Schedule only through shared pipeline.
   - Persist definitions.
   - Trigger `NotificationSystemRefresher.instance.resyncAll(...)`.
   - Let recovery + universal scheduler + hub do scheduling.

7. Safe tap/action routing.
   - Route via `NotificationHandler` + `NotificationHub`.
   - Adapter handlers should re-load entity and handle missing/deleted state gracefully.

8. Add canonical delete cleanup.
   - On entity delete: cancel Hub notifications for that entity + delete universal definitions.
   - Ensure no module-specific orphan state can recreate reminders.

9. Add tests and regression checks.
   - Deterministic ID/range test.
   - Delete + recovery no-resurrection test.
   - Module-disabled scheduling/action blocked test.
   - Duplicate prevention for repeated edit/resync flows.

## Required Code Touchpoints

Core authority and routing:

- `lib/core/notifications/notification_hub.dart`
- `lib/core/notifications/services/notification_module_policy.dart`
- `lib/core/services/notification_handler.dart`

ID ranges and module identity:

- `lib/core/notifications/models/notification_hub_modules.dart`
- `lib/core/notifications/models/notification_hub_module.dart`

Adapter contract:

- `lib/core/notifications/adapters/mini_app_notification_adapter.dart`

Universal rule storage and schedule generation:

- `lib/core/notifications/services/universal_notification_repository.dart`
- `lib/core/notifications/services/universal_notification_scheduler.dart`
- `lib/core/notifications/models/universal_notification.dart`

Final scheduling + quiet hours enforcement:

- `lib/core/services/notification_service.dart`
- `lib/core/models/notification_settings.dart`
- `lib/features/notifications_hub/presentation/screens/hub_quiet_hours_page.dart`

Resync and recovery (app/runtime/headless):

- `lib/core/notifications/services/notification_system_refresher.dart`
- `lib/core/notifications/services/notification_recovery_service.dart`
- `lib/core/notifications/services/notification_workmanager_dispatcher.dart`
- `lib/main.dart`
- `lib/features/more/presentation/screens/comprehensive_data_backup_screen.dart`

User-facing warning and diagnostics:

- `lib/features/notifications_hub/presentation/screens/hub_dashboard_page.dart`
- `lib/features/notifications_hub/presentation/screens/hub_failed_notifications_page.dart`
- `lib/features/notifications_hub/presentation/screens/hub_permissions_page.dart`

## Validation Checklist (Mandatory)

Run this before merging any new module notification integration:

1. Create reminder, edit it rapidly (10x), resync, verify pending count stays stable (no duplicate growth).
2. Delete entity, run recovery/resync, verify no pending reminders return for deleted entity.
3. Disable module in Hub, resync, verify no schedules/actions are applied for that module.
4. Block notifications/exact alarms in system settings, verify Hub shows a visible delivery warning.
5. Re-enable permissions and verify warning clears after refresh and scheduling resumes.
6. Set quiet hours to include a reminder fire time, resync, and verify delivery is deferred/skipped according to quiet-hours policy (no fire inside quiet window).
7. Verify deterministic IDs stay in the module range for all generated reminders.
8. Verify tap/action for stale/deleted entities is safely rejected.
9. Verify reboot/update/resume recovery does not create duplicates.

Notes:

- If a debug smoke screen exists in your development branch, run it.
- If debug smoke UI is not present, execute equivalent manual/automated scenarios above.

## Debugging (Tiny)

- Check Hub warning surfaces first: blocked permission, exact alarm restriction, or module policy off.
- Inspect failed notifications in `hub_failed_notifications_page.dart` for the latest failure reason.
- For one entity, run create -> edit -> resync -> delete -> resync and confirm pending count returns to baseline.
- In logs, verify `sourceFlow`, `reason`, `cancelledIds`, `scheduledIds`, and `skipped` counts are coherent.

## Definition of Done

A new developer can add notifications for a new mini app using this guide only, without tribal knowledge, and without bypassing Hub/universal scheduling paths.
