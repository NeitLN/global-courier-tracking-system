BEGIN;
SELECT plan(6);

-- Setup: Create customer and profile
WITH new_cust AS (
    INSERT INTO public.customer (full_name, phone, email)
    VALUES ('Customer Auth Test', 'CUST001', 'cust1@example.com')
    RETURNING customer_id
),
new_user AS (
    INSERT INTO auth.users (id, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000002', '{"display_name": "Test Customer"}')
    RETURNING id
)
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT id::text FROM new_user), 'role', 'authenticated')::text, true);

UPDATE public.profiles 
SET app_role = 'CUSTOMER', customer_id = (SELECT customer_id FROM public.customer WHERE email = 'cust1@example.com')
WHERE user_id = '00000000-0000-0000-0000-000000000002';

-- Add a second customer to ensure isolation
INSERT INTO public.customer (full_name, phone, email) VALUES ('Other Customer', 'CUST002', 'other@example.com');

SET ROLE authenticated;

-- 1. Can see own customer record
SELECT is(
    (SELECT COUNT(*)::int FROM public.customer),
    1,
    'CUSTOMER can only see their own customer row'
);

-- 2. Can see reference data
SELECT is(
    (SELECT COUNT(*)::int > 0 FROM public.status_code),
    true,
    'CUSTOMER can see status codes'
);

-- 3. Cannot see routes
SELECT is(
    (SELECT COUNT(*)::int FROM public.route),
    0,
    'CUSTOMER cannot see routes'
);

-- 4. Cannot direct insert package
SELECT throws_ok(
    $$ INSERT INTO public.package (tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status) VALUES ('GC-TEST', 1, 2, 1, 1, 1, 2, 'REGISTERED') $$,
    '42501',
    NULL,
    'CUSTOMER cannot directly insert package'
);

-- 5. Can call fn_update_customer for self
SELECT lives_ok(
    $$ SELECT public.fn_update_customer((SELECT customer_id FROM public.profiles WHERE user_id = '00000000-0000-0000-0000-000000000002'), 'New Name'); $$,
    'CUSTOMER can update own details via RPC'
);

-- 6. Cannot call fn_update_customer for other
SELECT throws_ok(
    $$ SELECT public.fn_update_customer((SELECT customer_id FROM public.customer WHERE email = 'other@example.com'), 'Hacked'); $$,
    NULL,
    NULL,
    'CUSTOMER cannot update another customer via RPC'
);

ROLLBACK;
