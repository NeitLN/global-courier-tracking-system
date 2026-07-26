BEGIN;
SELECT plan(6);

-- Setup: Create DISPATCHER profile
WITH new_user AS (
    INSERT INTO auth.users (id, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000004', '{"display_name": "Test Dispatcher"}')
    RETURNING id
)
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT id::text FROM new_user), 'role', 'authenticated')::text, true);

UPDATE public.profiles 
SET app_role = 'DISPATCHER'
WHERE user_id = '00000000-0000-0000-0000-000000000004';

SET ROLE authenticated;

-- 1. Can see routes
SELECT lives_ok(
    $$ SELECT * FROM public.route LIMIT 1; $$,
    'DISPATCHER can select from routes'
);

-- 2. Cannot see customer table directly
SELECT is(
    (SELECT COUNT(*)::int FROM public.customer),
    0,
    'DISPATCHER cannot see customer data directly'
);

-- 3. Can call fn_rank_driver_performance
SELECT lives_ok(
    $$ SELECT * FROM public.fn_rank_driver_performance() LIMIT 1; $$,
    'DISPATCHER can call fn_rank_driver_performance'
);

-- Now test ANALYST
RESET ROLE;

WITH new_user AS (
    INSERT INTO auth.users (id, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000005', '{"display_name": "Test Analyst"}')
    RETURNING id
)
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT id::text FROM new_user), 'role', 'authenticated')::text, true);

UPDATE public.profiles 
SET app_role = 'ANALYST'
WHERE user_id = '00000000-0000-0000-0000-000000000005';

SET ROLE authenticated;

-- 4. Can see routes
SELECT lives_ok(
    $$ SELECT * FROM public.route LIMIT 1; $$,
    'ANALYST can select from routes'
);

-- 5. Cannot call fn_rank_driver_performance
SELECT throws_ok(
    $$ SELECT * FROM public.fn_rank_driver_performance(); $$,
    NULL,
    NULL,
    'ANALYST cannot call fn_rank_driver_performance'
);

-- 6. Cannot directly update route
SELECT throws_ok(
    $$ UPDATE public.route SET distance_km = 100 WHERE route_id = 1; $$,
    '42501',
    NULL,
    'ANALYST cannot directly update route'
);

ROLLBACK;
