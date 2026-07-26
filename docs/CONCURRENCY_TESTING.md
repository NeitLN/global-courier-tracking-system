# Concurrency Testing

## Locking Strategy

The Global Courier & Tracking System uses a deterministic strict row-level lock on the `package` row to serialize concurrent event submissions. 

1. **Lock Acquisition:** Before validating transition rules or querying the latest event, `fn_validate_tracking_status()` executes `PERFORM 1 FROM public.package WHERE package_id = NEW.package_id FOR NO KEY UPDATE;`
2. **Path Uniformity:** Every TRACKING_EVENT insert path uses the same trigger, so all insertions serialize correctly against the same lock.
3. **Targeted Serialization:** Different packages are not mutually serialized. Only concurrent insertions targeting the *same* package block each other.
4. **Validation Ordering:** The query fetching the strictly latest event (`ORDER BY event_time DESC LIMIT 1`) is executed *after* the lock is acquired, ensuring that all concurrently uncommitted events are flushed and evaluated deterministically.

## Limitations of Automated Coverage

pgTAP does not open two independent, parallel database sessions in a single test script. Because functions run in a single transaction during automated tests, our pgTAP coverage proves **atomicity** (e.g., failure rollback without partial rows) rather than true multi-session concurrency. 

The automated test script `013_atomicity.test.sql` validates these single-session guarantees. The lock design was explicitly verified through code review.

## Manual Two-Session Test

To safely verify real concurrency protection, use two active connections (e.g., via `psql` or `npx supabase db psql`):

**Session A**
```sql
BEGIN;
-- Acquire the package lock through a valid event insert
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) 
VALUES (9001, 901, 'PICKED_UP', now(), 901);
```

**Session B**
```sql
BEGIN;
-- This will wait (block) because Session A holds the lock on package 9001
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) 
VALUES (9001, 901, 'IN_TRANSIT', now(), 901);
```

**Session A**
```sql
COMMIT;
-- Session B resumes and revalidates against the new latest event inserted by A.
```

**Session B**
```sql
-- The transaction completes successfully because IN_TRANSIT is a valid transition after PICKED_UP.
COMMIT;
```

If Session B attempted an invalid transition (e.g., `REGISTERED`), it would throw an R6 violation exception immediately upon waking up and re-evaluating the new `latest_event`.
