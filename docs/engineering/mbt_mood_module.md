# MBT Mood Module

This document defines the MBT Mood mini-app architecture and integration points.

## Scope

Mood is implemented as an independent module with:

- Configurable mood definitions (no hardcoded mood list)
- Reusable reasons constrained by polarity
- One primary mood entry per day
- Indexed history for fast analytics across multi-year data
- Notification Hub + Universal reminder integration
- Backup/restore compatibility with existing app-wide backup flow

## Data Model

### Mood

File: `lib/features/mbt/data/models/mood.dart`

- `id`
- `name` (unique among non-deleted moods)
- `iconCodePoint`, `iconFontFamily`, `iconFontPackage`
- `colorValue`
- `pointValue` (can be negative)
- `reasonRequired`
- `polarity` (`good` or `bad`)
- `isActive`
- `createdAt`, `updatedAt`
- `deletedAt` (soft delete)

### MoodReason

File: `lib/features/mbt/data/models/mood_reason.dart`

- `id`
- `name`
- `type` (`good` or `bad`)
- `isActive`
- `createdAt`, `updatedAt`
- `deletedAt` (soft delete)

Rules:

- reasons are reusable across moods
- reason type must match mood polarity at log time

### MoodEntry

File: `lib/features/mbt/data/models/mood_entry.dart`

- `id`
- `moodId`
- `reasonId` (nullable)
- `customNote` (nullable)
- `loggedAt`
- `createdAt`, `updatedAt`
- `source` (`manual` / `import`)
- `deletedAt` (soft delete)

Rules:

- one primary active mood entry per day (upsert behavior)
- if `mood.reasonRequired == true`, reason is mandatory

## Storage and Indexing

Module: `lib/features/mbt/mbt_module.dart`

Boxes:

- `mbt_moods_v1`
- `mbt_mood_reasons_v1`
- `mbt_mood_entries_v1`
- `mbt_mood_entry_date_index_v1` (`YYYYMMDD -> entryId`)
- `mbt_mood_daily_summary_v1` (`YYYYMMDD -> compact summary map`)
- `mbt_mood_index_meta_v1` (index/backfill state)

Repository: `lib/features/mbt/data/repositories/mood_repository.dart`

- 30-day bootstrap index window
- resumable chunked backfill for older history
- scan fallback only when integrity is invalid
- no full-box scans on indexed UI paths

## API-first Service

File: `lib/features/mbt/data/services/mood_api_service.dart`

Endpoint-shaped local APIs:

- Mood:
  - `postMood(...)`
  - `putMood(moodId, ...)`
  - `deleteMood(moodId)`
  - `getMoods(...)`
- Reason:
  - `postReason(...)`
  - `putReason(reasonId, ...)`
  - `deleteReason(reasonId)`
  - `getReasons(...)`
- Entry:
  - `postMoodEntry(...)`
  - `getMoodEntryByDate(date)`
  - `getMoodEntriesByRange(...)`
- Analytics:
  - `getMoodSummary(...)`
  - `getMoodTrends(...)`

## Notifications

### Hub Module Registration

- Module ID: `mbt_mood`
- ID range: `310000..319999`
- Files:
  - `lib/features/mbt/notifications/mbt_notification_contract.dart`
  - `lib/features/mbt/notifications/mbt_mood_notification_adapter.dart`
  - `lib/core/notifications/models/notification_hub_modules.dart`

### Daily Reminder Definition

File: `lib/features/mbt/notifications/mbt_mood_notification_service.dart`

- Persists one universal definition (`mbt_mood_daily_reminder_v1`)
- Idempotent cleanup of stale MBT definitions
- Triggered through `NotificationSystemRefresher.resyncAll(...)`

### Universal Scheduler Support

File: `lib/core/notifications/services/universal_notification_scheduler.dart`

- MBT module range validation
- MBT due-date resolver for daily check-in (today or next day)

## App Wiring

- Module initialization:
  - `lib/main.dart`
  - `lib/core/notifications/services/notification_recovery_service.dart` (headless bootstrap)
- Route:
  - `lib/routing/app_router.dart` (`/mood`)
- Screen:
  - `lib/features/mbt/presentation/screens/mood_screen.dart`

## Backup/Restore and Performance

- MBT boxes are included automatically in comprehensive backup (only finance is excluded).
- History backfill now includes MBT via:
  - `lib/features/more/data/services/history_optimization_service.dart`
- Backup info copy updated to explicitly include MBT Mood:
  - `lib/features/more/presentation/screens/comprehensive_data_backup_screen.dart`

## Validation Checklist

- reason-required and polarity constraints enforced at log time
- one-entry-per-day upsert behavior verified
- 30-day bootstrap + resumable backfill verified
- MBT notification IDs stay in `310000..319999`
- source resolver maps MBT ID range
- reason deletion does not break existing entries (graceful missing reason)
