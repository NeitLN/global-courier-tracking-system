BEGIN;
SELECT plan(31);

-- 1. Setup isolated reference and domain data for Phase 10
INSERT INTO public.transit_hub (hub_code, hub_name) VALUES
  ('PH10-H1', 'Phase 10 Hub 1'),
  ('PH10-H2', 'Phase 10 Hub 2');

INSERT INTO public.route (origin_hub_id, dest_hub_id, mode, distance_km, planned_hours) VALUES
  ((SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-H1'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-H2'),
   'TRUCK', 100.0, 2.0);

INSERT INTO public.driver (full_name, license_no, phone, base_hub_id) VALUES
  ('Phase 10 Driver 1', 'PH10-LIC001', 'PH10-PH001', (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-H1')),
  ('Phase 10 Driver 2', 'PH10-LIC002', 'PH10-PH002', (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-H1'));

INSERT INTO public.vehicle (plate_no, vehicle_type, capacity_kg, home_hub_id) VALUES
  ('PH10-PL001', 'TRUCK', 1000.0, (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-H1')),
  ('PH10-PL002', 'TRUCK', 1000.0, (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-H1'));

SELECT set_config('test.p10_route_id', (SELECT route_id::text FROM public.route WHERE origin_hub_id = (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-H1') AND dest_hub_id = (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-H2')), true);
SELECT set_config('test.p10_driver_1_id', (SELECT driver_id::text FROM public.driver WHERE license_no = 'PH10-LIC001'), true);
SELECT set_config('test.p10_driver_2_id', (SELECT driver_id::text FROM public.driver WHERE license_no = 'PH10-LIC002'), true);
SELECT set_config('test.p10_vehicle_1_id', (SELECT vehicle_id::text FROM public.vehicle WHERE plate_no = 'PH10-PL001'), true);
SELECT set_config('test.p10_vehicle_2_id', (SELECT vehicle_id::text FROM public.vehicle WHERE plate_no = 'PH10-PL002'), true);

-- Calculate dynamic invalid references to guarantee uniqueness and non-existence
SELECT set_config('test.p10_missing_route_id', (COALESCE((SELECT MAX(route_id) FROM public.route), 0) + 100000)::text, true);
SELECT set_config('test.p10_missing_vehicle_id', (COALESCE((SELECT MAX(vehicle_id) FROM public.vehicle), 0) + 100000)::text, true);
SELECT set_config('test.p10_missing_driver_id', (COALESCE((SELECT MAX(driver_id) FROM public.driver), 0) + 100000)::text, true);

-- Setup authentication users and profiles
-- User 1: Active DISPATCHER
INSERT INTO auth.users (id, email) VALUES ('10101010-1010-1010-1010-101010101010', 'p10-dispatcher@example.com');
UPDATE public.profiles
SET app_role = 'DISPATCHER',
    is_active = true
WHERE user_id = '10101010-1010-1010-1010-101010101010';

-- User 2: Active CUSTOMER
INSERT INTO public.customer (full_name, phone, email) VALUES ('Phase 10 Cust', 'PH10-CUST-PH', 'p10-customer@example.com');
INSERT INTO auth.users (id, email) VALUES ('20202020-2020-2020-2020-202020202020', 'p10-customer@example.com');
UPDATE public.profiles
SET app_role = 'CUSTOMER',
    customer_id = (SELECT customer_id FROM public.customer WHERE email = 'p10-customer@example.com'),
    is_active = true
WHERE user_id = '20202020-2020-2020-2020-202020202020';

-- User 3: Active ANALYST
INSERT INTO auth.users (id, email) VALUES ('30303030-3030-3030-3030-303030303030', 'p10-analyst@example.com');
UPDATE public.profiles
SET app_role = 'ANALYST',
    is_active = true
WHERE user_id = '30303030-3030-3030-3030-303030303030';

-- User 4: Inactive DISPATCHER
INSERT INTO auth.users (id, email) VALUES ('40404040-4040-4040-4040-404040404040', 'p10-inactive-dispatcher@example.com');
UPDATE public.profiles
SET app_role = 'DISPATCHER',
    is_active = false
WHERE user_id = '40404040-4040-4040-4040-404040404040';

-- User 5: Authenticated but no profile
INSERT INTO auth.users (id, email) VALUES ('50505050-5050-5050-5050-505050505050', 'p10-noprofile@example.com');
DELETE FROM public.profiles WHERE user_id = '50505050-5050-5050-5050-505050505050';


-- ============================================================================
-- A. FUNCTION STRUCTURE AND ACCESS (Assertions 1 - 7)
-- ============================================================================

-- Assertion 1: Function exists and matches the expected signature
SELECT has_function(
    'public',
    'fn_create_trip',
    ARRAY['bigint', 'bigint', 'bigint', 'timestamp with time zone'],
    'Function fn_create_trip(bigint, bigint, bigint, timestamptz) exists'
);

-- Assertion 2: Function is SECURITY DEFINER
SELECT is_definer(
    'public',
    'fn_create_trip',
    ARRAY['bigint', 'bigint', 'bigint', 'timestamp with time zone'],
    'Function fn_create_trip is SECURITY DEFINER'
);

-- Assertion 3: Function search_path is configured empty
SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_proc WHERE proname = 'fn_create_trip' AND proconfig @> ARRAY['search_path=""']
    ),
    'Function fn_create_trip search_path is set to empty string'
);

-- Assertion 4: anon has NO execute privileges
SELECT ok(
    NOT has_function_privilege('anon', 'public.fn_create_trip(bigint, bigint, bigint, timestamptz)', 'EXECUTE'),
    'anon should not have EXECUTE privilege on fn_create_trip'
);

-- Assertion 5: PUBLIC has NO execute privileges
SELECT ok(
    NOT has_function_privilege('public', 'public.fn_create_trip(bigint, bigint, bigint, timestamptz)', 'EXECUTE'),
    'PUBLIC should not have EXECUTE privilege on fn_create_trip'
);

-- Assertion 6: authenticated role has execute privileges
SELECT ok(
    has_function_privilege('authenticated', 'public.fn_create_trip(bigint, bigint, bigint, timestamptz)', 'EXECUTE'),
    'authenticated should have EXECUTE privilege on fn_create_trip'
);

-- Assertion 7: service_role has execute privileges
SELECT ok(
    has_function_privilege('service_role', 'public.fn_create_trip(bigint, bigint, bigint, timestamptz)', 'EXECUTE'),
    'service_role should have EXECUTE privilege on fn_create_trip'
);


-- ============================================================================
-- B. AUTHORIZED BEHAVIOR (Assertions 8 - 9)
-- ============================================================================

-- Set JWT context to active DISPATCHER
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '10101010-1010-1010-1010-101010101010', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Assertion 8: Active DISPATCHER receives the requested created trip row
WITH created AS MATERIALIZED (
    SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 10:00:00+00'::timestamptz
    ) AS trip
)
SELECT ok(
    (
        SELECT
            (trip).trip_id IS NOT NULL
            AND (trip).route_id = current_setting('test.p10_route_id')::bigint
            AND (trip).vehicle_id = current_setting('test.p10_vehicle_1_id')::bigint
            AND (trip).driver_id = current_setting('test.p10_driver_1_id')::bigint
            AND (trip).depart = '2026-08-01 10:00:00+00'::timestamptz
        FROM created
    ),
    'Active DISPATCHER receives the requested created trip row'
);

-- Assertion 9: Returned row and DB state have exactly the requested details
SELECT is(
    (SELECT count(*)::int FROM public.trip
     WHERE route_id = current_setting('test.p10_route_id')::bigint
       AND vehicle_id = current_setting('test.p10_vehicle_1_id')::bigint
       AND driver_id = current_setting('test.p10_driver_1_id')::bigint
       AND depart = '2026-08-01 10:00:00+00'::timestamptz),
    1,
    'Exactly one trip was inserted with correct details'
);


-- ============================================================================
-- C. AUTHORIZATION REJECTION (Assertions 10 - 16)
-- ============================================================================

-- Assertion 10: anon is rejected with permission error (42501)
RESET ROLE;
SET LOCAL ROLE anon;
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 11:00:00+00'::timestamptz
    ) $$,
    '42501',
    NULL,
    'anon is rejected from calling fn_create_trip'
);

-- Assertion 11: Active CUSTOMER is rejected
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '20202020-2020-2020-2020-202020202020', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 11:00:00+00'::timestamptz
    ) $$,
    NULL,
    NULL,
    'Active CUSTOMER is rejected'
);

-- Assertion 12: Active ANALYST is rejected
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '30303030-3030-3030-3030-303030303030', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 11:00:00+00'::timestamptz
    ) $$,
    NULL,
    NULL,
    'Active ANALYST is rejected'
);

-- Assertion 13: Inactive DISPATCHER is rejected
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '40404040-4040-4040-4040-404040404040', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 11:00:00+00'::timestamptz
    ) $$,
    NULL,
    NULL,
    'Inactive DISPATCHER is rejected'
);

-- Assertion 14: Authenticated user with no profile is rejected
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '50505050-5050-5050-5050-505050505050', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 11:00:00+00'::timestamptz
    ) $$,
    NULL,
    NULL,
    'Authenticated user with no profile is rejected'
);

-- Assertion 15: Forged service_role JWT claim under SET ROLE authenticated is rejected
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '50505050-5050-5050-5050-505050505050', 'role', 'service_role')::text, true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 11:00:00+00'::timestamptz
    ) $$,
    NULL,
    NULL,
    'Forged service_role claim under authenticated is rejected'
);

-- Assertion 16: Verification that failed authorization attempts insert no trip rows
RESET ROLE;
SELECT is(
    (SELECT count(*)::int FROM public.trip WHERE depart = '2026-08-01 11:00:00+00'::timestamptz),
    0,
    'No trips were inserted for failed authorization attempts'
);


-- ============================================================================
-- D. TRUSTED BACKEND (Assertions 17 - 18)
-- ============================================================================

-- Assertion 17: Legitimate service_role satisfies dual-check and creates trip
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
SET LOCAL ROLE service_role;

SELECT lives_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_2_id')::bigint,
        '2026-08-01 12:00:00+00'::timestamptz
    ) $$,
    'Legitimate service_role context can create a trip'
);

-- Assertion 18: Verify the service_role trip was inserted successfully
SELECT is(
    (SELECT count(*)::int FROM public.trip
     WHERE route_id = current_setting('test.p10_route_id')::bigint
       AND vehicle_id = current_setting('test.p10_vehicle_1_id')::bigint
       AND driver_id = current_setting('test.p10_driver_2_id')::bigint
       AND depart = '2026-08-01 12:00:00+00'::timestamptz),
    1,
    'Trip created by service_role exists'
);


-- ============================================================================
-- E. R5 DOUBLE-BOOKING CONTRACT (Assertions 19 - 23)
-- ============================================================================

RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '10101010-1010-1010-1010-101010101010', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Assertion 19: Duplicate vehicle at exact same depart is rejected with SQLSTATE 23505
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_2_id')::bigint,
        '2026-08-01 10:00:00+00'::timestamptz
    ) $$,
    '23505',
    NULL,
    'Duplicate vehicle booking rejected via UNIQUE uq_trip_vehicle_depart'
);

-- Assertion 20: Duplicate driver at exact same depart is rejected with SQLSTATE 23505
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_2_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 10:00:00+00'::timestamptz
    ) $$,
    '23505',
    NULL,
    'Duplicate driver booking rejected via UNIQUE uq_trip_driver_depart'
);

-- Assertion 21: Same vehicle at different depart timestamp is allowed
SELECT lives_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_2_id')::bigint,
        '2026-08-01 14:00:00+00'::timestamptz
    ) $$,
    'Same vehicle booked at a different depart timestamp is allowed'
);

-- Assertion 22: Same driver at different depart timestamp is allowed
SELECT lives_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_2_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 15:00:00+00'::timestamptz
    ) $$,
    'Same driver booked at a different depart timestamp is allowed'
);

-- Assertion 23: Verification that rejected duplicate inserts leave no partial rows
SELECT is(
    (SELECT count(*)::int FROM public.trip WHERE depart = '2026-08-01 10:00:00+00'::timestamptz),
    1,
    'Rejected duplicate exact-time inserts do not leave partial extra rows'
);


-- ============================================================================
-- F. REFERENTIAL AND NULL SAFETY (Assertions 24 - 31)
-- ============================================================================

RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '10101010-1010-1010-1010-101010101010', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Assertion 24: Rejected for invalid route
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_missing_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 16:00:00+00'::timestamptz
    ) $$,
    NULL,
    NULL,
    'Rejects invalid route ID'
);

-- Assertion 25: Rejected for invalid vehicle
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_missing_vehicle_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 16:00:00+00'::timestamptz
    ) $$,
    NULL,
    NULL,
    'Rejects invalid vehicle ID'
);

-- Assertion 26: Rejected for invalid driver
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_missing_driver_id')::bigint,
        '2026-08-01 16:00:00+00'::timestamptz
    ) $$,
    NULL,
    NULL,
    'Rejects invalid driver ID'
);

-- Assertion 27: Rejected for null route
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        NULL::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 16:00:00+00'::timestamptz
    ) $$,
    NULL,
    NULL,
    'Rejects null route ID'
);

-- Assertion 28: Rejected for null vehicle
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        NULL::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        '2026-08-01 16:00:00+00'::timestamptz
    ) $$,
    NULL,
    NULL,
    'Rejects null vehicle ID'
);

-- Assertion 29: Rejected for null driver
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        NULL::bigint,
        '2026-08-01 16:00:00+00'::timestamptz
    ) $$,
    NULL,
    NULL,
    'Rejects null driver ID'
);

-- Assertion 30: Rejected for null depart
SELECT throws_ok(
    $$ SELECT public.fn_create_trip(
        current_setting('test.p10_route_id')::bigint,
        current_setting('test.p10_vehicle_1_id')::bigint,
        current_setting('test.p10_driver_1_id')::bigint,
        NULL::timestamptz
    ) $$,
    NULL,
    NULL,
    'Rejects null depart timestamp'
);

-- Assertion 31: Verification that failed referential/null inserts left no trip rows at '2026-08-01 16:00:00+00'
RESET ROLE;
SELECT is(
    (SELECT count(*)::int FROM public.trip WHERE depart = '2026-08-01 16:00:00+00'::timestamptz),
    0,
    'No trips were inserted for failed referential or null parameters'
);

SELECT * FROM finish();
ROLLBACK;
