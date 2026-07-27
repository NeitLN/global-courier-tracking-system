# Phase 6 UI Testing

This document records exactly what was tested for Phase 6 and how — no claim below is
made about a scenario that wasn't actually exercised. There is no browser/E2E test
framework in this project (no Playwright/Cypress config, no test script in
`package.json`), so automated UI checks in this phase were run as one-off Playwright
scripts against a running local build, not committed as a permanent test suite.

## Automated Checks (this repository, non-UI)

Run and passing at the time of this work:

```bash
npm run lint
npm run typecheck
npm run build
npm run check
git diff --check
```

`npm run build`'s route table was inspected directly to confirm:
- `ƒ Proxy (Middleware)` is present and recognized.
- Auth-dependent routes (`/`, `/account`, `/dashboard`, every `(protected)` route,
  `/unauthorized`) are marked `ƒ` (dynamic), not `○` (static) — required because their
  content depends on request-time auth state, and because static prerendering would
  otherwise fail the build with no env vars configured (a standing Phase 1 requirement).
- `/login` and `/signup` remain `○` (static) since they don't depend on auth state.

## Manual Browser Testing — What Was Actually Done

A local Supabase instance (`npx supabase db reset`) plus a local `.env.local` (pointing at
`http://127.0.0.1:54321` with the standard local demo publishable key — not a production
secret, and still gitignored) were used to run the real app end to end. Six real test
accounts were created via the Supabase Auth Admin API and assigned real profile rows to
cover every account state:

| Account | State |
| --- | --- |
| `customer@test.local` | active, `CUSTOMER`, bound to a real `customer` row |
| `operator@test.local` | active, `HUB_OPERATOR`, bound to a real `staff` row |
| `dispatcher@test.local` | active, `DISPATCHER` |
| `analyst@test.local` | active, `ANALYST` |
| `unassigned@test.local` | active, no `app_role` |
| `inactive@test.local` | `is_active = false` |

All test accounts and their supporting fixture rows were removed by a final
`npx supabase db reset` — the local database is back to a clean seed-only state.

**Important environment note:** interactivity testing (button clicks, dropdown open/close,
mobile drawer) was unreliable against `next dev` in this specific headless-Chromium/
Turbopack setup — the dev server's HMR WebSocket handshake failed
(`net::ERR_INVALID_HTTP_RESPONSE`), which coincided with client event handlers not
attaching at all (native `.click()` calls produced no state change anywhere on the page,
not just in one component). Switching to a production build (`npm run build && npm run
start`) resolved this completely and all interactivity worked as expected. **This is
recorded here because two real bugs were found and fixed during this testing pass** (see
below) — the dev-mode flakiness was a test-environment artifact, not the cause of either
bug; both were confirmed to exist independently of it.

### Scenarios exercised (desktop, 1440×900) — all passed

- Unauthenticated visitor: home page shows "Sign in" / "Create account"; visiting
  `/dashboard` redirects to `/login`.
- Each of the four roles: log in → land on `/dashboard` → sidebar navigation text
  compared exactly against the required per-role list (see `docs/DESIGN_SYSTEM.md` §6) —
  all four matched exactly, including the collapsed-by-default `Hub Operations` and
  `Analytics` groups.
- Wrong-role access: a `CUSTOMER` session visiting `/dispatcher/trips` is redirected to
  `/unauthorized`, which renders the safe explanation page with no internal detail.
- `unassigned@test.local` and `inactive@test.local`: both land on `/account` after login
  (showing the correct "waiting for role assignment" / "account suspended" message
  respectively) and are both redirected back to `/account` when directly visiting
  `/dashboard`.
- Sign out (via the user menu) redirects to `/login`.
- Keyboard: tabbing twice from `/login` lands on the password field with a visible
  `outline-style: solid`, `outline-width: 2px` focus ring.

### Scenarios exercised (tablet, 1024×768)

- Dispatcher dashboard (the longest nav list) rendered with **no horizontal page
  overflow** (`document.documentElement.scrollWidth <= clientWidth`, checked
  programmatically, not just eyeballed).

### Scenarios exercised (mobile, 390×844)

- Home page and dispatcher dashboard: no horizontal overflow.
- Mobile navigation drawer opens via the header hamburger button and displays the full
  role-appropriate nav list.

### Not tested this phase

- No role's placeholder sub-pages (e.g., `/operator/scans`, `/dispatcher/plan-track`)
  were individually screenshotted — they share the same `PageContainer`/`PageHeader`/
  `EmptyState` shell already verified on the dashboard and shipments pages, and contain no
  interactive logic of their own.
- No automated regression test was written for any of this (no test framework exists in
  the project — see the framework note above). This is a manual-checklist phase, per
  scope.
- Screen-reader-specific testing (e.g., NVDA/VoiceOver) was not performed — only
  programmatic checks (landmark roles, `aria-*` attributes, focus-visible styles).

## Two Real Bugs Found and Fixed During This Testing Pass

1. **RSC serialization violation**: `AppShell` (a Server Component) originally computed
   `getNavForRole(role)` and passed the resulting `NavItem[]` — which embeds Lucide icon
   component references — as a prop into `AppSidebar`/`AppHeader` (Client Components).
   Next.js rejected this at request time ("Functions cannot be passed directly to Client
   Components..."), and `/dashboard` rendered as a blank page. Fixed by passing only
   `role` (a plain string) across that boundary; `AppSidebar`, `AppHeader`, and
   `MobileNavigation` each now resolve their own nav items internally.
2. **`redirect()` inside a Suspense boundary degraded to an unreliable client-side
   redirect**: the `(protected)` route group originally had a `loading.tsx`, which wraps
   `{children}` in an implicit `<Suspense>`. Because the layout itself renders
   successfully before the page's own `requireRouteAccess(["ROLE"])` call executes, Next.js
   had already started streaming a `200` response by the time a role-mismatched page threw
   its `redirect('/unauthorized')` — turning a real HTTP redirect into a soft client-side
   one that did not reliably happen. A customer visiting `/dispatcher/trips` saw the actual
   page content instead of being redirected. Fixed by removing `(protected)/loading.tsx`
   — Next.js's default (browser-native loading state until the response resolves) is the
   correct choice for auth-gated routes, since a Suspense boundary there actively
   undermines page-level redirect reliability. This is documented as a deliberate decision,
   not an oversight, in `docs/DESIGN_SYSTEM.md`.

Both were confirmed fixed via the same automated Playwright scenarios listed above,
re-run after each fix.

## Screenshots

Screenshots from this testing pass exist only in this session's local scratch directory,
not committed to the repository (they were a debugging/verification aid, not a deliverable
artifact). If a permanent visual record is wanted, that should be a deliberate follow-up
(e.g., Storybook or committed reference screenshots), not assumed to already exist here.

## Addendum: Close-out review pass (this session)

This was a code review and validation pass per the roadmap's §6.1 checklist, not a
rebuild — no browser/E2E framework or local Supabase instance was available in this
review environment (no Docker), so the live six-account role-matrix testing above was
**not** re-run here; it's taken as still valid from the prior pass.

What this pass actually did:
- Full diff against the committed `HEAD` (byte-for-byte, ignoring line-ending noise from
  the working copy) to confirm no migration and no unrelated file had drifted.
- `npm run lint`, `npm run typecheck`, and `npm run build` all re-run and passing. (Build
  in this specific sandbox needed a temporary, reverted stub for the `next/font/google`
  import because this sandbox's network egress blocks `fonts.googleapis.com` — confirmed
  as a sandbox-only limitation, not an app defect, by restoring the file byte-identical
  afterward and diffing to prove it.)
- Static/code review of every protected page's `requireRouteAccess` call against
  `nav-config.ts` to confirm role↔route↔menu consistency.
- Grepped `src/` for fake/mock data patterns and for hardcoded secrets or service-role
  key usage — none found.
- Smoke-tested the public/unauthenticated flows (`/`, `/login`, `/signup`, `/unauthorized`,
  `/dashboard` redirect-when-signed-out, a 404 route) against a real `next start`
  production server in this sandbox, pointed at a placeholder (unreachable) Supabase URL —
  this exercises routing, the proxy/middleware, and page rendering, but **not**
  authenticated flows, since there was no reachable Supabase instance to sign in against.

One real bug found and fixed: see the Phase 6 entry in `docs/PHASE_PROGRESS.md` for the
breadcrumb label collision on `/analytics/routes` and `/analytics/drivers`.

Authenticated-flow regression testing (the six-role matrix) against this exact fix should
still be spot-checked once against a real local Supabase instance before this is
considered fully re-verified end to end — the fix itself is a pure label-lookup change
with no auth surface, so the risk is low, but it was not re-exercised live here.
