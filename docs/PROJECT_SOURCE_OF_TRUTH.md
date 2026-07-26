# Project Source of Truth

## Project Context
- **Project:** Global Courier & Tracking System
- **Course:** Database Management Systems
- **Frontend:** Next.js App Router + TypeScript + Tailwind CSS
- **Backend platform:** Supabase
- **Database:** Supabase-hosted PostgreSQL
- **Authentication:** Supabase Auth
- **Authorization:** PostgreSQL Row Level Security
- **Server workflows:** PostgreSQL RPC and Supabase Edge Functions

The final report is the absolute source of truth for this project.

## Domain Relations
There are strictly 13 domain relations in the system:
1. `STATUS_CODE`
2. `SERVICE_TYPE`
3. `CUSTOMER`
4. `TRANSIT_HUB`
5. `STAFF`
6. `DRIVER`
7. `VEHICLE`
8. `ROUTE`
9. `PACKAGE`
10. `TRACKING_EVENT`
11. `TRIP`
12. `PACKAGE_LEG`
13. `DELIVERY_ATTEMPT`

*Note: A future profiles table is application-support infrastructure and must not be counted as a fourteenth domain relation.*

## Domain User Classes
As explicitly defined in Section 2 of the approved final report, there are four domain user classes:
1. Customer
2. Hub Operator
3. Dispatcher
4. Analyst

*Note: These are domain definitions, not PostgreSQL login roles yet. Later Supabase Auth application roles and RLS policies will represent these domain user classes. An admin/support role may exist only as application infrastructure.*

## Important Design Decisions
- `TRACKING_EVENT` is the authoritative package history.
- `PACKAGE.current_status` is only a trigger-maintained cache.
- Tracking history is append-only.
- `TRIP` represents one route execution by one driver and vehicle.
- `PACKAGE_LEG` resolves the `PACKAGE`–`TRIP` many-to-many relationship.
- `SERVICE_TYPE` and `STATUS_CODE` are reference relations.

## Business Rules
- **R1.** A package has one sender and one receiver, and they must differ.
- **R2.** Tracking number is unique; each package has one service tier.
- **R3.** Each status change creates a tracking event.
- **R4.** A directed route connects two different hubs.
- **R5.** Driver and vehicle cannot be double-booked at the same departure time.
- **R6.** Status may repeat or advance exactly one step; RETURNED is reachable from any open status; no event follows a terminal status.
- **R7.** Tracking history is append-only.
- **R8.** Failed delivery requires a reason; successful delivery must not have one.
- **R9.** Shipping fee is calculated from service tariff and actual package weight.
- **R10.** Weight must be positive and not exceed the tier limit.
- **R11.** Operator scans record staff; system-generated registration may have no staff.
- **R12.** A hub referenced in tracking history cannot be deleted.

## Functions
- **F1.** Register and price package.
- **F2.** Track package by tracking number.
- **F3.** Record checkpoint scan.
- **F4.** List packages currently held at a hub using latest-event filtering.
- **F5.** Update customer details.
- **F6.** Reconstruct chain of custody using LAG.
- **F7.** Analyse inter-scan intervals by hub using LEAD/CTE.
- **F8.** Measure SLA compliance.
- **F9.** Rank driver performance.
- **F10.** Find multi-hop routes using a recursive CTE and cycle guard.

## Out of Scope
- Payment settlement
- Live GPS tracking
- Customs workflows
- AI route optimisation
- Separate driver mobile app

## Non-Negotiable Rules
1. Do not invent or silently change business rules.
2. Do not rename domain tables or columns without reporting the reason first.
3. PostgreSQL remains the authoritative enforcement layer.
4. Do not duplicate shipping fee or status-flow logic only in frontend code.
5. Never expose the Supabase service-role key to the browser.
6. Do not implement features belonging to later phases.
7. Do not modify the final report or presentation during coding phases.
8. Before finishing, run all tests relevant to the phase.
9. Report every created, modified and deleted file.
10. Do not commit or push automatically. Provide the exact recommended commit message.