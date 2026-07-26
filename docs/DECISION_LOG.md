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