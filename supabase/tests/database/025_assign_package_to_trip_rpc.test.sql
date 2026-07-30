BEGIN;
SELECT plan(26);

-- 1. Setup isolated reference and domain data for Phase 10A2
INSERT INTO public.transit_hub (hub_code, hub_name) VALUES 
  ('PH10-A2-H1', 'Phase 10A2 Hub 1'),
  ('PH10-A2-H2', 'Phase 10A2 Hub 2');

INSERT INTO public.route (origin_hub_id, dest_hub_id, mode, distance_km, planned_hours) VALUES
  ((SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H1'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H2'),
   'TRUCK', 150.0, 3.0);

INSERT INTO public.driver (full_name, license_no, phone, base_hub_id) VALUES
  ('Phase 10A2 Driver', 'PH10A2-LIC', 'PH10A2-PH', (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H1'));

INSERT INTO public.vehicle (plate_no, vehicle_type, capacity_kg, home_hub_id) VALUES
  ('PH10A2-PL', 'TRUCK', 1500.0, (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H1'));

INSERT INTO public.trip (route_id, vehicle_id, driver_id, depart) VALUES
  ((SELECT route_id FROM public.route WHERE origin_hub_id = (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H1')),
   (SELECT vehicle_id FROM public.vehicle WHERE plate_no = 'PH10A2-PL'),
   (SELECT driver_id FROM public.driver WHERE license_no = 'PH10A2-LIC'),
   '2026-08-05 10:00:00+00'::timestamptz);

-- Setup package context (Sender and Receiver customers)
INSERT INTO public.customer (full_name, phone, email) VALUES
  ('PH10A2 Sender', 'PH10A2-SND-PH', 'p10a2-sender@example.com'),
  ('PH10A2 Receiver', 'PH10A2-RCV-PH', 'p10a2-receiver@example.com');

INSERT INTO public.service_type (service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES
  ('PH10A2 Service', 20.0, 5.0, 24, 50.0);

-- Package 1: Currently at the origin hub of the trip route (PH10-A2-H1)
INSERT INTO public.package (tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status) VALUES
  ('P10A2-TRK001',
   (SELECT customer_id FROM public.customer WHERE email = 'p10a2-sender@example.com'),
   (SELECT customer_id FROM public.customer WHERE email = 'p10a2-receiver@example.com'),
   (SELECT service_id FROM public.service_type WHERE service_name = 'PH10A2 Service'),
   10.0,
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H1'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H2'),
   'REGISTERED');

-- Initial tracking event for Package 1 at origin hub
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES
  ((SELECT package_id FROM public.package WHERE tracking_no = 'P10A2-TRK001'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H1'),
   'REGISTERED', '2026-08-05 08:00:00+00'::timestamptz, NULL);

-- Package 2: Terminal status (DELIVERED)
INSERT INTO public.package (tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status) VALUES
  ('P10A2-TRK002',
   (SELECT customer_id FROM public.customer WHERE email = 'p10a2-sender@example.com'),
   (SELECT customer_id FROM public.customer WHERE email = 'p10a2-receiver@example.com'),
   (SELECT service_id FROM public.service_type WHERE service_name = 'PH10A2 Service'),
   10.0,
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H1'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H2'),
   'DELIVERED');

-- Package 3: Location mismatch (Currently at Hub 2, but trip route origin is Hub 1)
INSERT INTO public.package (tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status) VALUES
  ('P10A2-TRK003',
   (SELECT customer_id FROM public.customer WHERE email = 'p10a2-sender@example.com'),
   (SELECT customer_id FROM public.customer WHERE email = 'p10a2-receiver@example.com'),
   (SELECT service_id FROM public.service_type WHERE service_name = 'PH10A2 Service'),
   10.0,
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H1'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H2'),
   'REGISTERED');

INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES
  ((SELECT package_id FROM public.package WHERE tracking_no = 'P10A2-TRK003'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H2'),
   'REGISTERED', '2026-08-05 08:00:00+00'::timestamptz, NULL);

-- Save GUC variables for test isolation
SELECT set_config('test.p10_trip_id', (SELECT trip_id::text FROM public.trip WHERE route_id = (SELECT route_id FROM public.route WHERE origin_hub_id = (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H1'))), true);
SELECT set_config('test.p10_pkg_1_id', (SELECT package_id::text FROM public.package WHERE tracking_no = 'P10A2-TRK001'), true);
SELECT set_config('test.p10_pkg_2_id', (SELECT package_id::text FROM public.package WHERE tracking_no = 'P10A2-TRK002'), true);
SELECT set_config('test.p10_pkg_3_id', (SELECT package_id::text FROM public.package WHERE tracking_no = 'P10A2-TRK003'), true);

-- Calculate dynamic unused IDs
SELECT set_config('test.p10_missing_trip_id', (COALESCE((SELECT MAX(trip_id) FROM public.trip), 0) + 100000)::text, true);
SELECT set_config('test.p10_missing_pkg_id', (COALESCE((SELECT MAX(package_id) FROM public.package), 0) + 100000)::text, true);

-- Setup authentication profiles
-- Active DISPATCHER
INSERT INTO auth.users (id, email) VALUES ('10a210a2-10a2-10a2-10a2-10a210a210a2', 'p10a2-dispatcher@example.com');
UPDATE public.profiles SET app_role = 'DISPATCHER', is_active = true WHERE user_id = '10a210a2-10a2-10a2-10a2-10a210a210a2';

-- Active CUSTOMER
INSERT INTO public.customer (full_name, phone, email) VALUES ('PH10A2 Normal Cust', 'PH10A2-CUST', 'p10a2-cust@example.com');
INSERT INTO auth.users (id, email) VALUES ('20a220a2-20a2-20a2-20a2-20a220a220a2', 'p10a2-cust@example.com');
UPDATE public.profiles SET app_role = 'CUSTOMER', customer_id = (SELECT customer_id FROM public.customer WHERE email = 'p10a2-cust@example.com'), is_active = true WHERE user_id = '20a220a2-20a2-20a2-20a2-20a220a220a2';

-- Active ANALYST
INSERT INTO auth.users (id, email) VALUES ('30a230a2-30a2-30a2-30a2-30a230a230a2', 'p10a2-analyst@example.com');
UPDATE public.profiles SET app_role = 'ANALYST', is_active = true WHERE user_id = '30a230a2-30a2-30a2-30a2-30a230a230a2';

-- Inactive DISPATCHER
INSERT INTO auth.users (id, email) VALUES ('40a240a2-40a2-40a2-40a2-40a240a240a2', 'p10a2-inactive-dispatcher@example.com');
UPDATE public.profiles SET app_role = 'DISPATCHER', is_active = false WHERE user_id = '40a240a2-40a2-40a2-40a2-40a240a240a2';


-- ============================================================================
-- A. FUNCTION STRUCTURE AND PRIVILEGES (Assertions 1 - 7)
-- ============================================================================

-- Assertion 1: Function exists and matches the signature
SELECT has_function(
    'public',
    'fn_assign_package_to_trip',
    ARRAY['bigint', 'bigint'],
    'Function fn_assign_package_to_trip(bigint, bigint) exists'
);

-- Assertion 2: Function is SECURITY DEFINER
SELECT is_definer(
    'public',
    'fn_assign_package_to_trip',
    ARRAY['bigint', 'bigint'],
    'Function fn_assign_package_to_trip is SECURITY DEFINER'
);

-- Assertion 3: Function search_path is configured empty
SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_proc WHERE proname = 'fn_assign_package_to_trip' AND proconfig @> ARRAY['search_path=""']
    ),
    'Function fn_assign_package_to_trip search_path is set to empty string'
);

-- Assertion 4: anon has NO execute privileges
SELECT ok(
    NOT has_function_privilege('anon', 'public.fn_assign_package_to_trip(bigint, bigint)', 'EXECUTE'),
    'anon should not have EXECUTE privilege'
);

-- Assertion 5: PUBLIC has NO execute privileges
SELECT ok(
    NOT has_function_privilege('public', 'public.fn_assign_package_to_trip(bigint, bigint)', 'EXECUTE'),
    'PUBLIC should not have EXECUTE privilege'
);

-- Assertion 6: authenticated role has execute privileges
SELECT ok(
    has_function_privilege('authenticated', 'public.fn_assign_package_to_trip(bigint, bigint)', 'EXECUTE'),
    'authenticated should have EXECUTE privilege'
);

-- Assertion 7: service_role has execute privileges
SELECT ok(
    has_function_privilege('service_role', 'public.fn_assign_package_to_trip(bigint, bigint)', 'EXECUTE'),
    'service_role should have EXECUTE privilege'
);


-- ============================================================================
-- B. AUTHORIZED DISPATCHER BEHAVIOR (Assertions 8 - 10)
-- ============================================================================

-- Set JWT context to active DISPATCHER
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '10a210a2-10a2-10a2-10a2-10a210a210a2', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Assertion 8: Active DISPATCHER receives the correct returned package_leg composite row
WITH assigned AS MATERIALIZED (
    SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        current_setting('test.p10_pkg_1_id')::bigint
    ) AS leg
)
SELECT ok(
    (
        SELECT
            (leg).trip_id = current_setting('test.p10_trip_id')::bigint
            AND (leg).package_id = current_setting('test.p10_pkg_1_id')::bigint
            AND (leg).loaded_at IS NULL
            AND (leg).unloaded_at IS NULL
        FROM assigned
    ),
    'Active DISPATCHER receives the requested package_leg returned composite row'
);

-- Assertion 9: Verify exactly one row was inserted into package_leg table
RESET ROLE;
SELECT is(
    (SELECT count(*)::int FROM public.package_leg
     WHERE trip_id = current_setting('test.p10_trip_id')::bigint
       AND package_id = current_setting('test.p10_pkg_1_id')::bigint),
    1,
    'Exactly one package_leg row is inserted in database'
);


-- ============================================================================
-- C. CONSTRAINTS AND VALIDATIONS (Assertions 11 - 18)
-- ============================================================================

SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '10a210a2-10a2-10a2-10a2-10a210a210a2', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Assertion 10: Re-assigning duplicate package to the same trip is rejected
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        current_setting('test.p10_pkg_1_id')::bigint
    ) $$,
    NULL,
    NULL,
    'Re-assignment of duplicate package is rejected'
);

-- Assertion 11: Invalid trip ID is rejected
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_missing_trip_id')::bigint,
        current_setting('test.p10_pkg_3_id')::bigint
    ) $$,
    NULL,
    NULL,
    'Invalid trip ID is rejected'
);

-- Assertion 12: Invalid package ID is rejected
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        current_setting('test.p10_missing_pkg_id')::bigint
    ) $$,
    NULL,
    NULL,
    'Invalid package ID is rejected'
);

-- Assertion 13: NULL trip ID is rejected
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        NULL::bigint,
        current_setting('test.p10_pkg_3_id')::bigint
    ) $$,
    NULL,
    NULL,
    'NULL trip ID is rejected'
);

-- Assertion 14: NULL package ID is rejected
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        NULL::bigint
    ) $$,
    NULL,
    NULL,
    'NULL package ID is rejected'
);

-- Assertion 15: Terminal status (DELIVERED) is rejected
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        current_setting('test.p10_pkg_2_id')::bigint
    ) $$,
    NULL,
    NULL,
    'Package in terminal status is rejected'
);

-- Assertion 16: Location mismatch is rejected (Package currently at Hub 2, trip starts from Hub 1)
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        current_setting('test.p10_pkg_3_id')::bigint
    ) $$,
    NULL,
    NULL,
    'Package at wrong hub is rejected due to location mismatch'
);


-- ============================================================================
-- D. TRUSTED BACKEND BYPASS (Assertions 17 - 18)
-- ============================================================================

-- Assertion 17: Legitimate service_role context bypasses role checks and assigns successfully
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
SET LOCAL ROLE service_role;

-- Pre-setup: Package 3 location reverted to Hub 1 for successful service_role setup
RESET ROLE;
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES
  ((SELECT package_id FROM public.package WHERE tracking_no = 'P10A2-TRK003'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H1'),
   'REGISTERED', '2026-08-05 09:00:00+00'::timestamptz, NULL);

SELECT set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
SET LOCAL ROLE service_role;

SELECT lives_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        current_setting('test.p10_pkg_3_id')::bigint
    ) $$,
    'Legitimate service_role satisfies dual-check and creates package_leg'
);

-- Assertion 18: Verify the service_role package_leg actually exists in the database
RESET ROLE;
SELECT is(
    (SELECT count(*)::int FROM public.package_leg
     WHERE trip_id = current_setting('test.p10_trip_id')::bigint
       AND package_id = current_setting('test.p10_pkg_3_id')::bigint),
    1,
    'Package leg created by service_role exists in database'
);


-- ============================================================================
-- E. AUTHORIZATION REJECTIONS (Assertions 19 - 24)
-- ============================================================================

-- Assertion 19: anon is rejected with exception
RESET ROLE;
SET LOCAL ROLE anon;
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        current_setting('test.p10_pkg_3_id')::bigint
    ) $$,
    '42501',
    NULL,
    'anon is rejected from calling fn_assign_package_to_trip'
);

-- Assertion 20: Active CUSTOMER is rejected
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '20a220a2-20a2-20a2-20a2-20a220a220a2', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        current_setting('test.p10_pkg_3_id')::bigint
    ) $$,
    NULL,
    NULL,
    'Active CUSTOMER is rejected'
);

-- Assertion 21: Active ANALYST is rejected
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '30a230a2-30a2-30a2-30a2-30a230a230a2', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        current_setting('test.p10_pkg_3_id')::bigint
    ) $$,
    NULL,
    NULL,
    'Active ANALYST is rejected'
);

-- Assertion 22: Inactive DISPATCHER is rejected
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '40a240a2-40a2-40a2-40a2-40a240a240a2', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        current_setting('test.p10_pkg_3_id')::bigint
    ) $$,
    NULL,
    NULL,
    'Inactive DISPATCHER is rejected'
);

-- Assertion 23: Forged service_role under authenticated role is rejected
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '10a210a2-10a2-10a2-10a2-10a210a210a2', 'role', 'service_role')::text, true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$ SELECT public.fn_assign_package_to_trip(
        current_setting('test.p10_trip_id')::bigint,
        current_setting('test.p10_pkg_3_id')::bigint
    ) $$,
    NULL,
    NULL,
    'Forged service_role JWT under postgres authenticated role is rejected'
);

-- Assertion 24: Verify failed validations do not insert any package_leg rows (total row count is unchanged)
RESET ROLE;
SELECT is(
    (SELECT count(*)::int FROM public.package_leg),
    2, -- Expecting exactly the 2 successful legs inserted (Assertion 8 and Assertion 17)
    'Failed validation or unauthorized attempts leave no partial package_leg rows'
);


-- ============================================================================
-- F. BROWSER DIRECT WRITE PREVENTION (Assertions 25 - 26)
-- ============================================================================

-- Setup Package 4 for direct RLS insert checks
RESET ROLE;
INSERT INTO public.package (tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status) VALUES
  ('P10A2-TRK004',
   (SELECT customer_id FROM public.customer WHERE email = 'p10a2-sender@example.com'),
   (SELECT customer_id FROM public.customer WHERE email = 'p10a2-receiver@example.com'),
   (SELECT service_id FROM public.service_type WHERE service_name = 'PH10A2 Service'),
   10.0,
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H1'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A2-H2'),
   'REGISTERED');
SELECT set_config('test.p10_pkg_4_id', (SELECT package_id::text FROM public.package WHERE tracking_no = 'P10A2-TRK004'), true);

-- Switch back to active DISPATCHER
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '10a210a2-10a2-10a2-10a2-10a210a210a2', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Assertion 25: Browser authenticated Dispatcher is blocked from direct INSERT into package_leg table (via RLS/Privileges)
SELECT throws_ok(
    $$ INSERT INTO public.package_leg (trip_id, package_id, loaded_at, unloaded_at)
       VALUES (
           current_setting('test.p10_trip_id')::bigint,
           current_setting('test.p10_pkg_4_id')::bigint,
           NULL, NULL
       ) $$,
    '42501', -- permission_denied error
    NULL,
    'Authenticated Dispatcher role cannot insert directly into package_leg table'
);

-- Assertion 26: Verify direct write attempts failed to insert any extra rows
RESET ROLE;
SELECT is(
    (SELECT count(*)::int FROM public.package_leg),
    2,
    'Direct write attempts leave no partial package_leg rows'
);

SELECT * FROM finish();
ROLLBACK;
