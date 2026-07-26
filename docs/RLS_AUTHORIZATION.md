# RLS and Authorization

This document details the Row-Level Security (RLS) and Authorization architecture implemented in Phase 5 of the Global Courier & Tracking System.

## 1. Application Users and Authorization
Application users are authorized using:
- Verified `auth.uid()` via Supabase Auth.
- Valid role binding established in `public.profiles`.
- The `is_active = true` status check.
- Valid ownership scope (e.g. `customer_id` matching package fields) or hub scope (e.g. assigned `hub_id`).

The system strictly supports four application roles bound to `public.profiles`:
- **CUSTOMER**: Operates within their own customer boundaries (sender or receiver).
- **HUB_OPERATOR**: Operates strictly within the scope of their assigned transit hub.
- **DISPATCHER**: Has global operational read access and execution access to dispatch analytics/management RPCs.
- **ANALYST**: Has read-only access to operational data and analytics RPCs without exposing customer/staff PII.

Inactive and unassigned accounts cannot access any operational domain data.

## 2. Infrastructure Roles
- **anon**: Completely denied access to domain tables and RPCs.
- **authenticated**: Basic PostgREST connection role. Cannot execute direct DML on domain tables. Must use hardened RPCs for operations.
- **service_role**: Infrastructure credentials remain server-only and are never shipped to the browser.

## 9. Trusted Backend Execution
Trusted backend execution (bypassing normal application role constraints) strictly requires both:
- `auth.role() = 'service_role'` (JWT role claim validated by PostgREST)
- `current_setting('role', true) = 'service_role'` (The active PostgreSQL execution context)

A caller cannot become trusted merely by:
- Setting a customer or role in user metadata.
- Setting only `request.jwt.claim.role`.
- Connecting through an authenticated application session.
- Originating from a `postgres`-owned pgTAP physical connection.

`session_user` and `current_user` are not used for backend authorization because:
- `session_user` identifies the physical connection, which may be reused or shared by pgTAP regardless of the logical user identity.
- `SECURITY DEFINER` changes `current_user` to the function owner (`postgres`), making it useless for identifying the caller.

## 3. Table Access Matrix
| Table | CUSTOMER | HUB_OPERATOR | DISPATCHER | ANALYST |
|-------|----------|--------------|------------|---------|
| `profiles` | Own row | Own row | Own row | Own row |
| `status_code` | Global Read | Global Read | Global Read | Global Read |
| `service_type` | Global Read | Global Read | Global Read | Global Read |
| `customer` | Own row | Denied | Denied | Denied |
| `transit_hub` | Global Read | Global Read | Global Read | Global Read |
| `staff` | Denied | Own row | Denied | Denied |
| `driver` | Denied | Denied | Denied | Denied |
| `vehicle` | Denied | Denied | Denied | Denied |
| `route` | Denied | Denied | Global Read | Global Read |
| `package` | Own packages | Hub scope | Global Read | Global Read |
| `tracking_event` | Own packages | Hub scope | Global Read | Global Read |
| `trip` | Denied | Denied | Global Read | Global Read |
| `package_leg` | Own packages | Denied | Global Read | Global Read |
| `delivery_attempt`| Own packages | Denied | Global Read | Global Read |

*Note: All direct DML (INSERT, UPDATE, DELETE) is disabled on all tables. Operations must be executed via RPCs.*

## 4. RPC Execution Matrix
| Function | CUSTOMER | HUB_OPERATOR | DISPATCHER | ANALYST |
|----------|----------|--------------|------------|---------|
| `fn_update_display_name` | Allowed | Allowed | Allowed | Allowed |
| `fn_register_package` | Allowed | Denied | Denied | Denied |
| `fn_update_customer` | Allowed | Denied | Denied | Denied |
| `fn_record_checkpoint_scan` | Denied | Allowed | Denied | Denied |
| `fn_track_package` | Allowed | Allowed | Allowed | Denied |
| `fn_chain_of_custody` | Allowed | Allowed | Allowed | Denied |
| `fn_current_hub_inventory` | Denied | Allowed | Allowed | Denied |
| `fn_find_routes` | Denied | Denied | Allowed | Allowed |
| `fn_inter_scan_hub_analysis` | Denied | Denied | Allowed | Allowed |
| `fn_sla_compliance` | Denied | Denied | Allowed | Allowed |
| `fn_rank_driver_performance` | Denied | Denied | Allowed | Denied |

## 5. Private Helpers and Recursive RLS Prevention
To avoid infinite recursive RLS policies on `public.profiles`, a private schema `authz_private` was created. It contains `SECURITY DEFINER` functions like `current_app_role()`, `current_customer_id()`, `current_user_owns_package()`, etc., which read system state efficiently and safely, without looping RLS evaluation.

## 6. Write RPCs (SECURITY DEFINER)
Write RPCs execute as `SECURITY DEFINER` because they write to tables that forbid direct `INSERT/UPDATE` to regular users. They internally perform rigorous authorization checks against the active user's identity before committing mutations.

## 7. Dispatcher Write RPCs Deferred
Operational writes by DISPATCHERs (creating trips, assigning legs) are deferred until future phases where the specific UI and RPC contracts are better defined.

## 8. Role-Assignment Boundary
Role bindings (`app_role`, `customer_id`, `staff_id`) cannot be modified by any application role. Only a trusted backend administrator (`service_role`) or superuser can change role definitions, establishing an absolute security boundary.
