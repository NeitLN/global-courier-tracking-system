BEGIN;
SELECT plan(8);

-- Fixture
INSERT INTO public.transit_hub (hub_id, hub_code, hub_name) VALUES 
(901, 'TST-01', 'Hub A'),
(902, 'TST-02', 'Hub B'),
(903, 'TST-03', 'Hub C'),
(904, 'TST-04', 'Hub D');

INSERT INTO public.route (origin_hub_id, dest_hub_id, mode, distance_km, planned_hours) VALUES
(901, 902, 'TRUCK', 100.0, 2.0),
(902, 903, 'TRUCK', 150.0, 3.0),
(903, 904, 'TRUCK', 200.0, 4.0),
(903, 901, 'TRUCK', 300.0, 6.0); -- Cycle possibility

SELECT set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
SET LOCAL ROLE service_role;

-- 1. F10: Direct route (901 -> 902)
SELECT results_eq(
    $$ SELECT path_array, total_distance_km FROM public.fn_find_routes(901, 902) $$,
    $$ VALUES (ARRAY[901::bigint, 902::bigint], 100.0::numeric) $$,
    'Direct route found correctly'
);

-- 2. F10: Multi-hop route (901 -> 904)
SELECT results_eq(
    $$ SELECT path_array, total_distance_km FROM public.fn_find_routes(901, 904) $$,
    $$ VALUES (ARRAY[901::bigint, 902::bigint, 903::bigint, 904::bigint], 450.0::numeric) $$,
    'Multi-hop route found correctly'
);

-- 3. F10: No path (904 -> 901)
SELECT is_empty(
    $$ SELECT * FROM public.fn_find_routes(904, 901) $$,
    'Directed edges respected; no reverse path found'
);

-- 4. F10: Cycle guard and max hops using cycle (902 -> 901)
-- 902 -> 903 -> 901 (dist 450)
SELECT results_eq(
    $$ SELECT path_array, total_distance_km FROM public.fn_find_routes(902, 901, 10) $$,
    $$ VALUES (ARRAY[902::bigint, 903::bigint, 901::bigint], 450.0::numeric) $$,
    'Route traversing part of a cycle terminates safely and avoids infinite loops'
);

-- 5. F10: max_hops = 0 rejection
PREPARE test_zero_hops AS
SELECT * FROM public.fn_find_routes(901, 902, 0);
SELECT throws_ok('test_zero_hops', 'p_max_hops must be between 1 and 10.', 'max_hops = 0 rejected');

-- 6. F10: max_hops < 0 rejection
PREPARE test_negative_hops AS
SELECT * FROM public.fn_find_routes(901, 902, -1);
SELECT throws_ok('test_negative_hops', 'p_max_hops must be between 1 and 10.', 'max_hops < 0 rejected');

-- 7. F10: max_hops > 10 rejection
PREPARE test_high_hops AS
SELECT * FROM public.fn_find_routes(901, 902, 11);
SELECT throws_ok('test_high_hops', 'p_max_hops must be between 1 and 10.', 'max_hops > 10 rejected');

-- 8. F10: max_hops IS NULL rejection
PREPARE test_null_hops AS
SELECT * FROM public.fn_find_routes(901, 902, NULL);
SELECT throws_ok('test_null_hops', 'p_max_hops must be between 1 and 10.', 'max_hops IS NULL rejected');

SELECT * FROM finish();
ROLLBACK;