# Phase 7–8 Implementation Record

## Status

Implementation is complete in the working tree. Final completion is deliberately not claimed until
migration 17, the new pgTAP file, authenticated role flows and the normal npm validation suite run in
an environment with PostgreSQL/Supabase and installable dependencies.

- Previously verified database baseline: **16 migrations, 248/248 pgTAP assertions**.
- Current local database state: **17 migrations**.
- New test coverage added: **13 pgTAP assertions** in test 022 (not executed in this sandbox).
- No remote database command, commit or push was performed.

## Source-backed decisions

1. `fn_register_package` generates the tracking number, so the UI does not ask customers to invent one.
2. Shipping fees are returned by PostgreSQL. The UI contains no tariff formula and does not label a
   currency because the approved source documents do not define one.
3. The approved `CUSTOMER` relation contains `full_name`, `phone` and `email`; it has no address column.
   The profile UI therefore does not add an unsupported address field.
4. The existing authenticated `fn_track_package` exposes internal IDs and requires login. Public
   tracking therefore uses a separate `fn_public_track_package` RPC with a deliberately smaller output.
5. Receiver selection uses an exact email inside a database wrapper. No customer directory or receiver
   identifier is exposed to the browser.
6. `TRACKING_EVENT` remains authoritative and append-only. Detail pages read F6 chain-of-custody data;
   they do not edit or delete history.

## Database additions

### `fn_public_track_package(text)`

- Executable by `anon`, `authenticated` and `service_role`.
- `SECURITY DEFINER`, empty search path and fully qualified relations.
- Returns only tracking number, current status, service type, origin/destination hub labels, latest
  update and ordered public timeline.
- Excludes sender/receiver IDs, contact data, staff IDs, recorded-by values and internal remarks.

### `fn_register_package_by_receiver_email(...)`

- Executable only by `authenticated`; `anon` and `PUBLIC` are revoked.
- Requires an active `CUSTOMER` profile.
- Resolves one exact receiver email inside PostgreSQL, then delegates to the existing
  `fn_register_package`, preserving its sender check, weight/tier validation, database fee calculation,
  package insert and REGISTERED-event atomicity.

### `fn_customer_dashboard_summary()`

- Authenticated CUSTOMER-only, `SECURITY INVOKER` and RLS-scoped.
- Returns active, delivered and returned counts plus the latest shipment event time.
- The UI renders an error state instead of substituting zero values when this RPC fails.

## UI additions

- `/track`: public-safe tracking search and timeline.
- `/dashboard`: real customer summary and recent RLS-scoped shipments.
- `/shipments`: RLS-scoped list with tracking/status/service filters.
- `/shipments/new`: real registration form using a Server Action and database RPC.
- `/shipments/[trackingNo]`: overview, chain of custody, inter-scan interval, trip legs and delivery
  attempts when real rows exist.
- `/profile`: display-name and CUSTOMER domain updates through their approved RPCs.

## Validation performed here

- `git diff --check`: PASS.
- TypeScript/TSX parser pass with `tsc -p tsconfig.json --noCheck --noEmit`: PASS.
- Existing migrations 1–16: not modified.
- Direct browser DML scan: no `.insert`, `.update`, `.delete` or `.upsert` calls added to `src/`.
- Secret/service-role scan: no service-role key added to `src/` or tracked environment files.

## Validation still required before marking COMPLETE

```bash
npm ci
npm run lint
npm run typecheck
npm run build
npm run check
git diff --check
npx supabase db reset
npx supabase test db
npx supabase db lint
npx supabase migration list
```

Then smoke-test with real CUSTOMER accounts:

1. Public valid and invalid tracking numbers.
2. Customer A cannot see Customer B's unrelated package.
3. Sender and receiver can each open the same package.
4. Profile self-update succeeds; another customer update is rejected.
5. Valid registration returns DB fee and one REGISTERED event.
6. Same sender/receiver, unknown receiver, invalid weight/tier and same origin/destination are rejected.
7. A failed transaction leaves no partial package or event.

## Recommended commit message after validation

```text
feat: implement customer tracking and package workflows
```
