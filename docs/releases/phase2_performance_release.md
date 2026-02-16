# Performance Release: Phase 2 Complete

Life Manager is now significantly faster as your history grows.

- Weekly and monthly views are now optimized across Tasks, Habits, Sleep, and Finance.
- The app uses date indexes and daily summaries to avoid full-history scans.
- A background **Optimizing History** process now fills older indexes over time, without blocking normal usage.
- If part of history is not indexed yet, the app safely falls back for that range and continues working correctly.

This release is focused on long-term smoothness and responsiveness for users with months or years of data.
