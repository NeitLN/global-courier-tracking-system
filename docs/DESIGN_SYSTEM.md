# Design System — Phase 6

This document covers the visual foundation and shared component library introduced in
Phase 6 (Design System and Application Shell). It does not cover business logic, data
fetching, or RPC integration — those belong to Phase 7 onward.

## 1. Visual Direction

The application is a **professional courier operations control center**: operational,
modern, clean, and information-dense without being cramped. It is desktop-first (dispatch
and hub-operator work happens at a desk), but usable on tablet and mobile for account,
profile, and lightweight review tasks.

Explicitly avoided: default unstyled Tailwind, generic SaaS templates, oversized marketing
typography inside the authenticated shell, fabricated dashboard cards, monochrome gray
prototypes, and heavy gradients/glass effects.

## 2. Semantic Color Tokens

Defined as CSS custom properties in `src/app/globals.css` under `:root`, and mapped to
Tailwind v4 utilities via `@theme inline` (so `bg-primary`, `text-muted-foreground`,
`border-border`, etc. all work as ordinary Tailwind classes — no `tailwind.config.js` is
needed under Tailwind v4's CSS-first configuration).

| Token | Role |
| --- | --- |
| `background` / `foreground` | Page background and default text |
| `card` / `card-foreground` | Surface for cards, panels, menus |
| `muted` / `muted-foreground` | Secondary surfaces, labels, captions |
| `border` | All hairline borders |
| `primary` / `primary-foreground` | Navy — primary actions, sidebar, trust |
| `accent` / `accent-foreground` | Amber — highlights, attention |
| `success` / `success-foreground` (+ `-soft` variants) | Delivered, completed |
| `warning` / `warning-foreground` (+ `-soft` variants) | Attention, out-for-delivery |
| `danger` / `danger-foreground` (+ `-soft` variants) | Failed, returned, destructive |
| `info` / `info-foreground` (+ `-soft` variants) | In-network/transit states (blue, paired with navy) |
| `ring` | Focus ring color (amber) |
| `sidebar*` | Dedicated navy sidebar surface tokens (background, foreground, active, border) |

Light mode is the only supported theme. The pre-existing `prefers-color-scheme: dark`
background/foreground swap from the create-next-app starter was left in place unchanged —
there is no dark-mode toggle or full dark theme, per the Phase 6 scope.

## 3. Typography

Font: the existing `next/font/google` Geist Sans/Mono setup (`--font-geist-sans`,
`--font-geist-mono`), unchanged from before Phase 6.

A restrained type scale is defined as utility classes in `globals.css` (`@layer
components`) rather than one-off inline sizes, so every page uses the same scale:

`text-page-title`, `text-section-title`, `text-body`, `text-label`, `text-caption`,
`text-table`, `text-kpi-value`.

No marketing-sized display type exists inside the protected shell.

## 4. Spacing & Layout

Standard Tailwind spacing scale throughout. `PageContainer` applies the shared max-width
(`max-w-7xl`) and responsive padding (`p-4 md:p-6`) for every protected page. Cards and
tables use `gap-3`/`gap-4`/`p-4` consistently.

## 5. Application Shell

`src/components/layout/`:

- `AppShell` — composes sidebar + header + scrollable main content area. Server Component.
- `AppSidebar` — desktop sidebar, role-derived nav, active-route highlighting, expandable
  groups, collapse-to-icons toggle. Client Component (needs `usePathname` + local state).
- `AppHeader` — breadcrumbs (derived from the pathname), current date, a visibly disabled
  notification placeholder, role badge, and the user menu.
- `MobileNavigation` — hamburger trigger + `Drawer`-based slide-in nav, self-contained.
- `UserMenu` — display name/email, role badge, Profile/Account links, sign-out.
- `RoleBadge`, `Breadcrumbs`, `PageContainer`, `PageHeader` — small composable pieces.

## 6. Role-Based Navigation

`src/lib/navigation/nav-config.ts` is the single source of truth for what each of the four
roles sees in navigation. **Navigation visibility is a usability feature only** — it does
not enforce access. Every route it points to independently calls `requireRouteAccess` with
its own allowed-roles list server-side (see `docs/RLS_AUTHORIZATION.md`-adjacent
`src/lib/auth/route-access.ts`).

| Role | Navigation |
| --- | --- |
| CUSTOMER | Dashboard, My Shipments, Profile |
| HUB_OPERATOR | Dashboard, Hub Operations (Record Scan, Current Inventory, Delivery Attempts), Profile |
| DISPATCHER | Dashboard, Shipments, Plan & Track, Trips, Routes, Drivers, Vehicles, Profile |
| ANALYST | Dashboard, Analytics (Hub Analysis, SLA Compliance, Driver Performance, Route Explorer), Profile |

## 7. Shared UI Components

`src/components/ui/`: `Button`, `Input`, `Textarea`, `SelectField`, `Badge`, `Card` (+
sub-parts), `Separator`, `Skeleton`, `Spinner`, `EmptyState`, `ErrorState`, `Alert`,
`Modal`, `ConfirmationDialog`, `Drawer`, `DataTableShell`, `FilterBar`, `StatusBadge`,
`KpiCardShell`.

Notes on a few of them:

- **`Modal`/`Drawer`** are built on the native `<dialog>` element — free focus trapping and
  Escape-to-close, no extra dependency.
- **`KpiCardShell`** has no default numeric value. Callers either supply a real number
  (once a later phase wires it to an approved RPC) or omit `value` entirely, in which case
  an explicit `—` placeholder is shown. It never fabricates a figure.
- **`StatusBadge`** maps exactly the six approved package statuses (`REGISTERED`,
  `PICKED_UP`, `IN_TRANSIT`, `OUT_FOR_DELIVERY`, `DELIVERED`, `RETURNED`) to a visual tone.
  It performs no status-transition logic and does not invent additional statuses.
- **`Input`/`Textarea`/`SelectField`** accept an optional `label` and auto-generate a wired
  `id`/`htmlFor` pair via `useId()`, plus `aria-describedby` for hint/error text.

## 8. Accessibility Conventions

- All interactive controls are real `<button>`/`<a>` (via `Link`) elements.
- Every form input has an associated `<label>`.
- Focus is always visible via the shared `.focus-ring` utility (2px solid ring using the
  `ring` token, with `outline-offset`).
- Dialogs (`Modal`, `Drawer`, mobile nav) use native `<dialog>` semantics with
  `aria-labelledby`/`aria-describedby`.
- Icons are never the sole carrier of meaning — every icon-only control has an
  `aria-label`, and status/role information is always paired with text.
- `prefers-reduced-motion: reduce` disables/shortens animations globally (see
  `globals.css`).
- Landmarks: `<header>`, `<aside>` (sidebar), `<main>`, `<nav aria-label="...">` are used
  throughout the shell.

## 9. Route Loading Boundaries

`(protected)/` intentionally has **no** `loading.tsx`. A `loading.tsx` file wraps its
segment's children in an implicit `<Suspense>`, which lets Next.js begin streaming a `200`
response before a nested page's own `requireRouteAccess(role)` call has run. If that call
then rejects and calls `redirect()`, the redirect can no longer change the already-sent
status code and degrades to an unreliable client-side navigation instead of a real HTTP
redirect — this was found and confirmed during Phase 6 manual testing (see
`docs/PHASE6_UI_TESTING.md`). For auth-gated routes, the browser's own default
loading behavior (nothing rendered until the response resolves) is the correct choice.
`not-found.tsx` (root) and `(protected)/error.tsx` remain, since neither of those wraps
route content in a Suspense boundary that a page-level `redirect()` needs to unwind
through.

## 10. Responsive Behavior

- **Desktop (≥1024px / `lg:`)**: full sidebar visible, header with breadcrumbs/date/role
  badge/user menu, content constrained to `max-w-7xl`.
- **Tablet**: sidebar and mobile-drawer trigger both hidden/shown per the `lg:` breakpoint
  as appropriate; tables scroll horizontally inside `DataTableShell`'s own container, never
  the page.
- **Mobile**: sidebar is never off-screen-but-present — it's simply not rendered
  (`hidden lg:flex`); navigation is exclusively the `Drawer`-based `MobileNavigation`.
  Auth pages (`/login`, `/signup`), `/account`, and the home page are single-column and
  usable at 390px width.

## 11. Status Badge Mapping

| Status | Tone |
| --- | --- |
| `REGISTERED` | neutral (gray) |
| `PICKED_UP` | primary (navy) |
| `IN_TRANSIT` | info (blue) |
| `OUT_FOR_DELIVERY` | warning (amber) |
| `DELIVERED` | success (green) |
| `RETURNED` | danger (red) |

## 12. Phase Boundary

Phase 6 delivers the **shell only**: tokens, layout, navigation, protected-route
enforcement, shared primitives, and placeholder pages with no data. It does not implement:
package registration, tracking, checkpoint scanning, hub inventory RPC integration, trip
creation, drag-and-drop assignment, analytics charts backed by real data, or any dashboard
KPI values. Those are explicitly deferred to their respective later phases (see each
placeholder page's own copy for its specific phase reference, and `docs/PHASE_PROGRESS.md`
for the full roadmap).

`recharts` (charting) and `dnd-kit` (drag-and-drop) are intentionally **not** installed in
Phase 6 — they belong to Phase 11–12 and Phase 10 respectively, once there is real data or
a real assignment workflow to justify them.
