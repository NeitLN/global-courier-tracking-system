BEGIN;
SELECT plan(45);

-- 1. Setup isolated reference and domain data for Phase 10A3
INSERT INTO public.transit_hub (hub_code, hub_name) VALUES 
  ('PH10-A3-H1', 'Phase 10A3 Hub 1'),
  ('PH10-A3-H2', 'Phase 10A3 Hub 2');

INSERT INTO public.route (origin_hub_id, dest_hub_id, mode, distance_km, planned_hours) VALUES
  ((SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A3-H1'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A3-H2'),
   'TRUCK', 150.0, 3.0);

INSERT INTO public.driver (full_name, license_no, phone, base_hub_id) VALUES
  ('Phase 10A3 Driver', 'PH10A3-LIC', 'PH10A3-PH', (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A3-H1'));

INSERT INTO public.vehicle (plate_no, vehicle_type, capacity_kg, home_hub_id) VALUES
  ('PH10A3-PL', 'TRUCK', 1500.0, (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A3-H1'));

INSERT INTO public.trip (route_id, vehicle_id, driver_id, depart) VALUES
  ((SELECT route_id FROM public.route WHERE origin_hub_id = (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A3-H1')),
   (SELECT vehicle_id FROM public.vehicle WHERE plate_no = 'PH10A3-PL'),
   (SELECT driver_id FROM public.driver WHERE license_no = 'PH10A3-LIC'),
   '2026-08-05 10:00:00+00'::timestamptz);

-- Setup package context (Sender and Receiver customers)
INSERT INTO public.customer (full_name, phone, email) VALUES
  ('PH10A3 Sender', 'PH10A3-SND-PH', 'p10a3-sender@example.com'),
  ('PH10A3 Receiver', 'PH10A3-RCV-PH', 'p10a3-receiver@example.com');

INSERT INTO public.service_type (service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES
  ('PH10A3 Service', 20.0, 5.0, 24, 50.0);

-- Package 1: Unassigned currently at the origin hub (PH10-A3-H1)
INSERT INTO public.package (tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status) VALUES
  ('P10A3-TRK001',
   (SELECT customer_id FROM public.customer WHERE email = 'p10a3-sender@example.com'),
   (SELECT customer_id FROM public.customer WHERE email = 'p10a3-receiver@example.com'),
   (SELECT service_id FROM public.service_type WHERE service_name = 'PH10A3 Service'),
   10.0,
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A3-H1'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A3-H2'),
   'REGISTERED');

INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES
  ((SELECT package_id FROM public.package WHERE tracking_no = 'P10A3-TRK001'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH10-A3-H1'),
   'REGISTERED', '2026-08-05 08:00:00+00'::timestamptz, NULL);

-- Save GUC variable for unassigned package test
SELECT set_config('test.p10a3_hub_id', (SELECT hub_id::text FROM public.transit_hub WHERE hub_code = 'PH10-A3-H1'), true);

-- Setup authentication profiles
-- User 1: Active DISPATCHER
INSERT INTO auth.users (id, email) VALUES ('10a310a3-10a3-10a3-10a3-10a310a310a3', 'p10a3-dispatcher@example.com');
UPDATE public.profiles SET app_role = 'DISPATCHER', is_active = true WHERE user_id = '10a310a3-10a3-10a3-10a3-10a310a310a3';

-- User 2: Active CUSTOMER
INSERT INTO public.customer (full_name, phone, email) VALUES ('PH10A3 Normal Cust', 'PH10A3-CUST', 'p10a3-cust@example.com');
INSERT INTO auth.users (id, email) VALUES ('20a320a3-20a3-20a3-20a3-20a320a320a3', 'p10a3-cust@example.com');
UPDATE public.profiles SET app_role = 'CUSTOMER', customer_id = (SELECT customer_id FROM public.customer WHERE email = 'p10a3-cust@example.com'), is_active = true WHERE user_id = '20a320a3-20a3-20a3-20a3-20a320a320a3';

-- User 3: Inactive DISPATCHER
INSERT INTO auth.users (id, email) VALUES ('40a340a3-40a3-40a3-40a3-40a340a340a3', 'p10a3-inactive-dispatcher@example.com');
UPDATE public.profiles SET app_role = 'DISPATCHER', is_active = false WHERE user_id = '40a340a3-40a3-40a3-40a3-40a340a340a3';


-- ============================================================================
-- A. FUNCTION EXISTENCE, DEFINER, SEARCH_PATH (Assertions 1 - 15)
-- ============================================================================

-- Drivers RPC
SELECT has_function('public', 'fn_get_dispatcher_drivers', ARRAY[]::text[], 'Function fn_get_dispatcher_drivers exists');
SELECT is_definer('public', 'fn_get_dispatcher_drivers', ARRAY[]::text[], 'Function fn_get_dispatcher_drivers is SECURITY DEFINER');
SELECT ok(EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_get_dispatcher_drivers' AND proconfig @> ARRAY['search_path=""']), 'fn_get_dispatcher_drivers search_path is set to empty string');

-- Vehicles RPC
SELECT has_function('public', 'fn_get_dispatcher_vehicles', ARRAY[]::text[], 'Function fn_get_dispatcher_vehicles exists');
SELECT is_definer('public', 'fn_get_dispatcher_vehicles', ARRAY[]::text[], 'Function fn_get_dispatcher_vehicles is SECURITY DEFINER');
SELECT ok(EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_get_dispatcher_vehicles' AND proconfig @> ARRAY['search_path=""']), 'fn_get_dispatcher_vehicles search_path is set to empty string');

-- Trips RPC
SELECT has_function('public', 'fn_get_dispatcher_trips', ARRAY[]::text[], 'Function fn_get_dispatcher_trips exists');
SELECT is_definer('public', 'fn_get_dispatcher_trips', ARRAY[]::text[], 'Function fn_get_dispatcher_trips is SECURITY DEFINER');
SELECT ok(EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_get_dispatcher_trips' AND proconfig @> ARRAY['search_path=""']), 'fn_get_dispatcher_trips search_path is set to empty string');

-- Routes RPC
SELECT has_function('public', 'fn_get_dispatcher_routes', ARRAY[]::text[], 'Function fn_get_dispatcher_routes exists');
SELECT is_definer('public', 'fn_get_dispatcher_routes', ARRAY[]::text[], 'Function fn_get_dispatcher_routes is SECURITY DEFINER');
SELECT ok(EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_get_dispatcher_routes' AND proconfig @> ARRAY['search_path=""']), 'fn_get_dispatcher_routes search_path is set to empty string');

-- Unassigned Packages RPC
SELECT has_function('public', 'fn_get_dispatcher_unassigned_packages', ARRAY['bigint'], 'Function fn_get_dispatcher_unassigned_packages exists');
SELECT is_definer('public', 'fn_get_dispatcher_unassigned_packages', ARRAY['bigint'], 'Function fn_get_dispatcher_unassigned_packages is SECURITY DEFINER');
SELECT ok(EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_get_dispatcher_unassigned_packages' AND proconfig @> ARRAY['search_path=""']), 'fn_get_dispatcher_unassigned_packages search_path is set to empty string');


-- ============================================================================
-- B. REVOKED / GRANTED EXECUTE (Assertions 16 - 30)
-- ============================================================================

-- Drivers RPC
SELECT ok(NOT has_function_privilege('anon', 'public.fn_get_dispatcher_drivers()', 'EXECUTE'), 'anon lacks execute on fn_get_dispatcher_drivers');
SELECT ok(NOT has_function_privilege('public', 'public.fn_get_dispatcher_drivers()', 'EXECUTE'), 'public lacks execute on fn_get_dispatcher_drivers');
SELECT ok(has_function_privilege('authenticated', 'public.fn_get_dispatcher_drivers()', 'EXECUTE'), 'authenticated has execute on fn_get_dispatcher_drivers');

-- Vehicles RPC
SELECT ok(NOT has_function_privilege('anon', 'public.fn_get_dispatcher_vehicles()', 'EXECUTE'), 'anon lacks execute on fn_get_dispatcher_vehicles');
SELECT ok(NOT has_function_privilege('public', 'public.fn_get_dispatcher_vehicles()', 'EXECUTE'), 'public lacks execute on fn_get_dispatcher_vehicles');
SELECT ok(has_function_privilege('authenticated', 'public.fn_get_dispatcher_vehicles()', 'EXECUTE'), 'authenticated has execute on fn_get_dispatcher_vehicles');

-- Trips RPC
SELECT ok(NOT has_function_privilege('anon', 'public.fn_get_dispatcher_trips()', 'EXECUTE'), 'anon lacks execute on fn_get_dispatcher_trips');
SELECT ok(NOT has_function_privilege('public', 'public.fn_get_dispatcher_trips()', 'EXECUTE'), 'public lacks execute on fn_get_dispatcher_trips');
SELECT ok(has_function_privilege('authenticated', 'public.fn_get_dispatcher_trips()', 'EXECUTE'), 'authenticated has execute on fn_get_dispatcher_trips');

-- Routes RPC
SELECT ok(NOT has_function_privilege('anon', 'public.fn_get_dispatcher_routes()', 'EXECUTE'), 'anon lacks execute on fn_get_dispatcher_routes');
SELECT ok(NOT has_function_privilege('public', 'public.fn_get_dispatcher_routes()', 'EXECUTE'), 'public lacks execute on fn_get_dispatcher_routes');
SELECT ok(has_function_privilege('authenticated', 'public.fn_get_dispatcher_routes()', 'EXECUTE'), 'authenticated has execute on fn_get_dispatcher_routes');

-- Unassigned Packages RPC
SELECT ok(NOT has_function_privilege('anon', 'public.fn_get_dispatcher_unassigned_packages(bigint)', 'EXECUTE'), 'anon lacks execute on fn_get_dispatcher_unassigned_packages');
SELECT ok(NOT has_function_privilege('public', 'public.fn_get_dispatcher_unassigned_packages(bigint)', 'EXECUTE'), 'public lacks execute on fn_get_dispatcher_unassigned_packages');
SELECT ok(has_function_privilege('authenticated', 'public.fn_get_dispatcher_unassigned_packages(bigint)', 'EXECUTE'), 'authenticated has execute on fn_get_dispatcher_unassigned_packages');


-- ============================================================================
-- C. AUTHORIZED BEHAVIOR (Assertions 31 - 35)
-- ============================================================================

-- Set JWT context to active DISPATCHER
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '10a310a3-10a3-10a3-10a3-10a310a310a3', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Assertion 31: Drivers read successfully
SELECT is(
    (SELECT count(*)::int FROM public.fn_get_dispatcher_drivers() WHERE full_name = 'Phase 10A3 Driver'),
    1,
    'Active DISPATCHER can list drivers'
);

-- Assertion 32: Vehicles read successfully
SELECT is(
    (SELECT count(*)::int FROM public.fn_get_dispatcher_vehicles() WHERE plate_no = 'PH10A3-PL'),
    1,
    'Active DISPATCHER can list vehicles'
);

-- Assertion 33: Trips read successfully
SELECT is(
    (SELECT count(*)::int FROM public.fn_get_dispatcher_trips() WHERE driver_name = 'Phase 10A3 Driver'),
    1,
    'Active DISPATCHER can list trips'
);

-- Assertion 34: Routes read successfully
SELECT is(
    (SELECT count(*)::int FROM public.fn_get_dispatcher_routes() WHERE origin_hub_code = 'PH10-A3-H1'),
    1,
    'Active DISPATCHER can list routes'
);

-- Assertion 35: Unassigned packages read successfully
SELECT is(
    (SELECT count(*)::int FROM public.fn_get_dispatcher_unassigned_packages(current_setting('test.p10a3_hub_id')::bigint) WHERE tracking_no = 'P10A3-TRK001'),
    1,
    'Active DISPATCHER can list unassigned packages at hub'
);


-- ============================================================================
-- D. REJECTION BY OTHER ROLES (Assertions 36 - 40)
-- ============================================================================

-- Active CUSTOMER
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '20a320a3-20a3-20a3-20a3-20a320a320a3', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT * FROM public.fn_get_dispatcher_drivers() $$, NULL, NULL, 'CUSTOMER rejected from fn_get_dispatcher_drivers');
SELECT throws_ok($$ SELECT * FROM public.fn_get_dispatcher_vehicles() $$, NULL, NULL, 'CUSTOMER rejected from fn_get_dispatcher_vehicles');
SELECT throws_ok($$ SELECT * FROM public.fn_get_dispatcher_trips() $$, NULL, NULL, 'CUSTOMER rejected from fn_get_dispatcher_trips');
SELECT throws_ok($$ SELECT * FROM public.fn_get_dispatcher_routes() $$, NULL, NULL, 'CUSTOMER rejected from fn_get_dispatcher_routes');
SELECT throws_ok($$ SELECT * FROM public.fn_get_dispatcher_unassigned_packages(1) $$, NULL, NULL, 'CUSTOMER rejected from fn_get_dispatcher_unassigned_packages');


-- ============================================================================
-- E. REJECTION BY INACTIVE DISPATCHER (Assertions 41 - 45)
-- ============================================================================

-- Inactive DISPATCHER
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '40a340a3-40a3-40a3-40a3-40a340a340a3', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT * FROM public.fn_get_dispatcher_drivers() $$, NULL, NULL, 'Inactive DISPATCHER rejected from fn_get_dispatcher_drivers');
SELECT throws_ok($$ SELECT * FROM public.fn_get_dispatcher_vehicles() $$, NULL, NULL, 'Inactive DISPATCHER rejected from fn_get_dispatcher_vehicles');
SELECT throws_ok($$ SELECT * FROM public.fn_get_dispatcher_trips() $$, NULL, NULL, 'Inactive DISPATCHER rejected from fn_get_dispatcher_trips');
SELECT throws_ok($$ SELECT * FROM public.fn_get_dispatcher_routes() $$, NULL, NULL, 'Inactive DISPATCHER rejected from fn_get_dispatcher_routes');
SELECT throws_ok($$ SELECT * FROM public.fn_get_dispatcher_unassigned_packages(1) $$, NULL, NULL, 'Inactive DISPATCHER rejected from fn_get_dispatcher_unassigned_packages');


SELECT * FROM finish();
ROLLBACK;
