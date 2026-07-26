BEGIN;
SELECT plan(6);

-- Setup: Create staff and profile
WITH new_hub AS (
    INSERT INTO public.transit_hub (hub_code, hub_name) VALUES ('TEST-HUB', 'Test Hub') RETURNING hub_id
),
new_staff AS (
    INSERT INTO public.staff (full_name, hub_id)
    VALUES ('Operator Auth Test', (SELECT hub_id FROM new_hub))
    RETURNING staff_id
),
new_user AS (
    INSERT INTO auth.users (id, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000003', '{"display_name": "Test Operator"}')
    RETURNING id
)
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT id::text FROM new_user), 'role', 'authenticated')::text, true);

UPDATE public.profiles 
SET app_role = 'HUB_OPERATOR', staff_id = (SELECT staff_id FROM public.staff WHERE full_name = 'Operator Auth Test')
WHERE user_id = '00000000-0000-0000-0000-000000000003';

-- Add a second hub and staff to ensure isolation
WITH other_hub AS (
    INSERT INTO public.transit_hub (hub_code, hub_name) VALUES ('OTHER-HUB', 'Other Hub') RETURNING hub_id
)
INSERT INTO public.staff (full_name, hub_id) VALUES ('Other Staff', (SELECT hub_id FROM other_hub));

SET ROLE authenticated;

-- 1. Can see own staff record
SELECT is(
    (SELECT COUNT(*)::int FROM public.staff),
    1,
    'HUB_OPERATOR can only see their own staff row'
);

-- 2. Cannot see routes
SELECT is(
    (SELECT COUNT(*)::int FROM public.route),
    0,
    'HUB_OPERATOR cannot see routes'
);

-- 3. Cannot call fn_update_customer
SELECT throws_ok(
    $$ SELECT public.fn_update_customer(1, 'Hacked'); $$,
    NULL,
    NULL,
    'HUB_OPERATOR cannot call fn_update_customer'
);

-- 4. Cannot call fn_rank_driver_performance
SELECT throws_ok(
    $$ SELECT * FROM public.fn_rank_driver_performance(); $$,
    'P0001',
    NULL,
    'HUB_OPERATOR cannot call fn_rank_driver_performance'
);

-- 5. Direct insert tracking event denied
SELECT throws_ok(
    $$ INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES (1, 1, 'REGISTERED', now(), 1) $$,
    '42501',
    NULL,
    'HUB_OPERATOR cannot directly insert tracking event'
);

-- 6. RPC record checkpoint scan with invalid hub rejected
SELECT throws_ok(
    $$ SELECT public.fn_record_checkpoint_scan('GC-FAKE', 9999, 'SCANNED', now(), (SELECT staff_id FROM public.staff LIMIT 1)); $$,
    NULL,
    NULL,
    'HUB_OPERATOR cannot record scan for a hub they are not assigned to'
);

ROLLBACK;
