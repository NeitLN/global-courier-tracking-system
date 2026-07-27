# Database Functions and Triggers (Phase 3)

## Overview
This document details the PostgreSQL functions, triggers, and analytics queries implemented in Phase 3 of the Global Courier & Tracking System. These enforce business logic exclusively at the database layer.

## 1. Trigger Architecture

### R6 Transition Matrix Enforcement
- **Trigger**: `trg_tracking_event_status_flow` (BEFORE INSERT on `tracking_event`)
- **Function**: `fn_validate_tracking_status()`
- **Logic**:
  - The first event must be `REGISTERED`.
  - For subsequent events, the system finds the latest event (by `event_time DESC`).
  - The new `event_time` must be strictly later than the previous event.
  - Repeating the same status is permitted.
  - Normal transitions advance exactly by one step (`sequence_no`).
  - Terminal states (`DELIVERED`, `RETURNED`) reject subsequent events.
  - Any non-terminal state may transition to `RETURNED`.

### Concurrency Strategy
- To prevent race conditions from concurrent scans of the same package, `fn_validate_tracking_status` acquires a strict row-level lock on the parent `package`:
  ```sql
  PERFORM 1 FROM public.package WHERE package_id = NEW.package_id FOR NO KEY UPDATE;
  ```
- This ensures that multiple transactions inserting events for the *same* package serialize and evaluate the correct latest event sequence.

### Package Cache Synchronization
- **Trigger**: `trg_tracking_event_sync_status` (AFTER INSERT on `tracking_event`)
- **Function**: `fn_sync_package_status()`
- **Logic**: Automatically updates `package.current_status` to match the newly inserted event. The tracking_event remains the authoritative history.

### R7 Append-Only Enforcement
- **Trigger**: `trg_tracking_event_append_only` (BEFORE UPDATE OR DELETE on `tracking_event`)
- **Function**: `fn_prevent_history_mutation()`
- **Logic**: Hard-rejects any UPDATE or DELETE statement on `tracking_event`, guaranteeing immutable history.

## 2. Operational Functions (F1-F5)

| Function | Volatility | Security | Purpose |
| :--- | :--- | :--- | :--- |
| `fn_register_package` | VOLATILE | INVOKER | Enforces R9/R10. Calculates fee based on weight/service. Generates collision-resistant tracking number. Atomically inserts package and initial REGISTERED event. |
| `fn_track_package` | STABLE | INVOKER | Returns a JSONB object containing package details and complete ordered tracking history (F2). |
| `fn_record_checkpoint_scan` | VOLATILE | INVOKER | Operator scan (F3). Validates staff hub assignment. Relies on triggers for cache and validation. |
| `fn_current_hub_inventory` | STABLE | INVOKER | Inventory analysis (F4) using ROW_NUMBER() over events to find non-terminal packages currently residing at a specific hub. |
| `fn_update_customer` | VOLATILE | INVOKER | Modifies name/email/phone for a given customer without impacting package history (F5). |

## 3. Analytics Functions (F6-F10)

| Function | Volatility | Security | Purpose |
| :--- | :--- | :--- | :--- |
| `fn_chain_of_custody` | STABLE | INVOKER | F6: Uses window function `LAG()` to surface the previous hub, staff, time, and elapsed interval per event. |
| `fn_inter_scan_hub_analysis` | STABLE | INVOKER | F7: Uses `LEAD()` and a CTE to aggregate processing durations grouped by hub (avg, min, max). |
| `fn_sla_compliance` | STABLE | INVOKER | F8: Compares elapsed hours since REGISTERED against the service tier's SLA. Classifies as MET, BREACHED, OPEN, or RETURNED. |
| `fn_rank_driver_performance` | STABLE | INVOKER | F9: Aggregates `delivery_attempt` stats and ranks drivers using `DENSE_RANK()` based on success rate and attempt count. |
| `fn_find_routes` | STABLE | INVOKER | F10: Recursive CTE traversing `route`. Includes a cycle guard (`next_route.dest_hub_id != ALL(rp.hubs_visited)`). |

## 4. Supporting Indexes (Migration 4)

- `idx_delivery_attempt_driver_time`: Optimizes F9 aggregation by driver.
- `idx_tracking_event_pkg_time_desc`: Primarily supports F4’s table-wide latest-event window ordering. Do not claim it is required for R6’s point lookup because the Phase 2 UNIQUE(package_id, event_time) B-tree can be scanned backward.
- `idx_tracking_event_status_time`: General/forward-looking index for querying events by status.
- `idx_package_service`: Supports package-to-service FK joins and possible service-scoped access.
- `idx_trip_route_depart`: Explicitly labelled forward-looking for future route trip matching.

## 5. Test Coverage
- pgTAP tests are located in `supabase/tests/database/`.
- 15 assertions for `006_status_flow_and_cache.test.sql`
- 3 assertions for `007_append_only_history.test.sql`
- 16 assertions for `008_register_and_price.test.sql`
- 18 assertions for `009_operational_functions.test.sql`
- 4 assertions for `010_chain_and_interval_analytics.test.sql`
- 4 assertions for `011_sla_and_driver_ranking.test.sql`
- 8 assertions for `012_recursive_routes.test.sql`
- 1 assertion for `013_atomicity.test.sql`

Phase 3 total: 69 assertions
Phase 2 total: 87 assertions
Combined total: 156 assertions

## 6. Deferred Auth/RLS Permissions
Functions currently use `SECURITY INVOKER`. Broad execution privileges and RLS enforcement policies are deferred to Phase 5. No remote service-role usage is required or documented at this phase.

## 7. Known Limitations
- F4 excludes packages whose latest status is terminal.
- F7 attributes each inter-scan segment to the current event’s hub. It omits hubs with zero qualifying segments.
- F8 distinguishes MET, BREACHED, OPEN and RETURNED. RETURNED is never treated as DELIVERED.
- F9 includes zero-attempt drivers through a LEFT JOIN.
- F10 is bounded graph reachability, not AI optimization or a guaranteed globally optimal route.
- R7 implementation triggers enforce row-level append-only behavior. TRUNCATE does not fire row-level UPDATE/DELETE triggers. A sufficiently privileged owner can disable triggers. Phase 5 privileges and RLS will reduce application-level access; Phase 3 does not claim protection against malicious database owners or superusers.

## 8. Phase 7–8 Application Support RPCs

Migration `20260727100000_create_customer_tracking_and_registration_support.sql` adds three narrow
application adapters without changing the approved F1–F10 definitions:

| Function | Security | Purpose |
| :--- | :--- | :--- |
| `fn_public_track_package` | DEFINER; anon-safe output | Public F2 projection without PII or internal staff identifiers. |
| `fn_register_package_by_receiver_email` | DEFINER; CUSTOMER-only | Resolves an exact receiver email inside PostgreSQL and delegates to F1 `fn_register_package`. |
| `fn_customer_dashboard_summary` | INVOKER; CUSTOMER/RLS-scoped | Returns real active/delivered/returned counts and latest event time. |

These are application-facing safety adapters. They do not add domain relations, statuses, fee rules or
new business functions beyond F1, F2, F5 and F6.
