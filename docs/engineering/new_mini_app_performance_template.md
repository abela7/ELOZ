# New Mini-App Performance Template

Use this from day 1 for any new module with time-based or growing history data.

## Required Data Pattern

1. Main box
- Store full records in the module's primary box.

2. Date index box
- Key format: `YYYYMMDD -> List<recordId>`.
- Update on create/update/delete.

3. Daily summary box
- Key format: `YYYYMMDD` (or `YYYYMMDD|currency` if needed).
- Store pre-aggregated counts/totals used by dashboards/charts.

4. Meta box
- Track:
  - `indexed_from_date_key`
  - `oldest_data_date_key`
  - `last_indexed_date_key`
  - `backfill_complete`
  - `backfill_paused`
  - `rebuild_needed`

## Required Runtime Behavior

1. Bootstrap window
- Build indexes/summaries for the most recent 30 days on first access.

2. Background backfill
- Backfill older history in 30-day chunks.
- Persist progress in meta.
- Yield between chunks and bound work per session.

3. Read path safety
- If range is fully indexed: indexed read.
- If partially indexed: indexed read for covered part + scan fallback for uncovered part.
- If indexes are invalid: scan fallback for the session and set `rebuild_needed`.

4. Isolate safety
- Heavy aggregation runs in an isolate.
- Pass plain payloads only (paths, keys, date range, maps/lists).
- Do not pass Hive `Box` objects across isolates.

5. UI integration
- Hook module status into History Optimization UI.
- Support pause/resume and run-now actions.

6. Paging
- Any potentially unbounded list must page (initial page + load more).

## Required Tests

1. Index correctness
- Write/update/delete records and verify date index integrity.

2. Summary parity
- Compare summary-driven outputs vs raw recomputation for sample datasets.

3. Bootstrap behavior
- Verify only recent window is indexed initially.

4. Resume behavior
- Verify chunk backfill resumes from saved meta after restart.

5. Partial-range correctness
- Verify mixed indexed + scan fallback returns complete/ordered results.
