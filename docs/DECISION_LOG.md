# Decision Log

This document records key architectural and design decisions made throughout the lifecycle of the Global Courier & Tracking System.

## Architectural Decisions
- **Framework:** Next.js App Router with TypeScript.
- **Styling:** Tailwind CSS.
- **Backend & Database:** Supabase (PostgreSQL) is the authoritative enforcement layer.
- **Auth:** Supabase Auth with PostgreSQL Row Level Security (RLS) for authorization.

## Domain User Classes
As defined in Section 2 of the approved final report, the domain user classes are: Customer, Hub Operator, Dispatcher, and Analyst. These are not described as PostgreSQL login roles yet. Later Supabase Auth application roles and RLS policies will represent these domain user classes.

## UI Design Direction (Approved in Phase 0)
- Build a modern courier dispatch control-center layout. The project may follow common dashboard and dispatch workflow patterns.
- **Do not copy** third-party branding, logos, text, images, icons, or proprietary assets.
- **Desktop-first admin interface.**
- Fixed left sidebar and top navigation bar.
- KPI cards on the dashboard.
- Large searchable and filterable shipment tables.
- Status badges and operational warning indicators.
- Right-side detail drawer for shipment details and timeline.
- A three-column **Plan & Track** screen:
  1. Unassigned shipments
  2. Scheduled trips
  3. Selected trip details
- Drag-and-drop package assignment will be implemented later using `PACKAGE_LEG`.
- **Main visual palette:** dark navy, white/light gray, and amber highlights.
- UI must strictly follow the final report’s 13 domain relations, 12 business rules, four user classes, and F1–F10 functions.
- **Strictly Out of Scope:** Live GPS, payment, customs, AI route optimization, or a separate driver mobile app.

## Delivery Attempt Clarification
- `DELIVERY_ATTEMPT` records an attempt outcome independently.
- Creating a `DELIVERY_ATTEMPT` does not automatically insert a `TRACKING_EVENT`.
- Creating a `DELIVERY_ATTEMPT` does not automatically update `PACKAGE.current_status`.
- A failed attempt must have a failure reason.
- A successful attempt must not have a failure reason.
- Any package status change must be recorded separately through F3 as a `TRACKING_EVENT` and validated by R6.
- A failed attempt may be followed by another OUT_FOR_DELIVERY event or by RETURNED, depending on a later explicit operational decision.
- A successful attempt should be followed by an explicit DELIVERED tracking event.
- **2026-07-30 correction:** the Phase 9 implementation of `fn_record_delivery_attempt`
  (`20260727110000_create_delivery_attempt_rpc.sql`) diverged from this decision by
  auto-inserting a `DELIVERED` tracking_event on `outcome = 'SUCCESS'`, because
  `/operator/scans` had no `DELIVERED` option in its status dropdown at the time — there
  was no other way to reach the terminal state. Migration
  `20260730140000_fix_delivery_attempt_hub_scope_and_history.sql` removed the auto-insert
  to restore the original decision, and `ScanForm.tsx` now offers `DELIVERED` as an
  explicit status choice so Hub Operators record it themselves via
  `fn_record_checkpoint_scan`, same as any other checkpoint scan.

## Analyst Driver Ranking Access (Phase 6 note resolved in Phase 11)
Phase 6 flagged a mismatch: the UI roadmap listed an Analyst → Driver Performance view,
but the only ranking RPC (`fn_rank_driver_performance`) was DISPATCHER-only and exposes
driver PII (license number, phone) unsuitable for ANALYST access. Resolved in Phase 11 by
adding a separate, privacy-safe `fn_get_analyst_driver_performance` RPC restricted to
ANALYST/DISPATCHER that returns only aggregate performance fields (name, attempts,
successes, failures, success rate, rank) — no license/phone/PII columns. ANALYST never
calls the DISPATCHER-only RPC.

## Phase 13 Error Taxonomy
- All user-facing error messages must go through `courierErrorMessage()`
  (`src/lib/courier/errors.ts`), which maps known database/RPC error signatures to a
  fixed list of safe, pre-written messages (duplicate tracking, sender=receiver, tier
  limit exceeded, backward/skipped status, terminal package, driver/vehicle
  double-booking, missing failure reason, permission denied).
- Any error that does not match a known pattern falls through to a single generic
  message ("An unexpected error occurred. Please try again."). There is intentionally
  **no fallback that echoes any part of the raw database error text** — an earlier
  version split the raw message on `:` and returned the tail segment, which could still
  leak internal detail; this was removed on 2026-07-30 along with 8 UI call sites
  (4 analytics pages, hub inventory, dispatcher trips, delivery attempts) that were
  rendering `error.message` directly instead of calling the mapper.