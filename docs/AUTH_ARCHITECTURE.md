# Auth Architecture

*Phase 4 remote deployment and recovery completion have been verified. Auth profiles and session foundation are active.*

## 1. Credentials and Sessions
Supabase Auth is the authoritative owner of user credentials and sessions. The application leverages `@supabase/ssr` to synchronize session state between the Next.js server components, server actions, and the browser.

## 2. Authentication Support Table
`public.profiles` acts as an authentication-support table. **It is not a 14th domain relation.** Its sole purpose is to securely extend `auth.users` with operational bindings and display properties required by the courier system.

## 3. Application Roles
The system defines exactly four approved application roles:
- `CUSTOMER` (requires `customer_id`)
- `HUB_OPERATOR` (requires `staff_id`)
- `DISPATCHER` (no domain identity required in Phase 4)
- `ANALYST` (no domain identity required in Phase 4)

## 4. Automatic Profile Provisioning
When a user signs up, an `AFTER INSERT` trigger on `auth.users` automatically provisions a row in `public.profiles`.
- New users explicitly receive `app_role = NULL`.
- Client-supplied metadata (such as `app_role`, `customer_id`, or `staff_id` sent during signup) is intentionally ignored by the trigger to prevent authorization escalation.
- Only safe display metadata (e.g., `display_name`) is parsed, trimmed, and copied.

### Security Definer Justification
The provisioning function (`fn_handle_new_auth_user`) runs with `SECURITY DEFINER`. This is strictly necessary because the `auth.users` trigger fires under the context of the user signing up (or an external identity provider), but it must write to the `public.profiles` table, which otherwise prohibits `anon` or newly `authenticated` inserts. The search path is explicitly cleared (`SET search_path = ''`) to mitigate search-path manipulation attacks.

## 5. Deferred Authorization
Role assignment is a privileged operational action and is intentionally deferred. In Phase 4, the application provides no mechanism for users to self-assign roles or identity bindings. 

## 6. Access and Exposure
- `public.profiles` is exposed via RLS strictly for self-selection (`user_id = auth.uid()`).
- Row Level Security (RLS) is fully enforced for all 14 domain relations. Ambient privileges are revoked, and all access requires explicit application roles evaluated by `authz_private` helpers.
- **Direct Domain DML (INSERT, UPDATE, DELETE) is explicitly denied for all application roles.**
- Mutations to domain data are restricted to explicitly crafted and secured `SECURITY DEFINER` RPCs (e.g. `fn_register_package`, `fn_record_checkpoint_scan`, `fn_update_customer`), which perform caller identity verification before writing.
- **DISPATCHER** and **ANALYST** roles have global read access to operational tables, but direct SELECT on PII tables (`customer`, `staff`, `driver`) is restricted.
- The schema `authz_private` is strictly isolated from PostgREST and contains `SECURITY DEFINER` context helpers.