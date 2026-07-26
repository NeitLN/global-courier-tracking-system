BEGIN;

SELECT plan(8);

-- 1. Helper execution denied to anon
SELECT throws_ok(
    $$ SET ROLE anon; SELECT authz_private.is_active_user(); $$,
    '42501',
    NULL,
    'anon should not execute helpers'
);

RESET ROLE;

-- 2. authenticated can execute
SELECT lives_ok(
    $$ SET ROLE authenticated; SELECT authz_private.is_active_user(); RESET ROLE; $$,
    'authenticated should execute helpers'
);

RESET ROLE;

-- 3. test with auth.uid() IS NULL
SELECT is(
    (SELECT authz_private.is_active_user()),
    false,
    'is_active_user() returns false when uid is null'
);

SELECT is(
    (SELECT authz_private.current_app_role()),
    NULL,
    'current_app_role() returns NULL when uid is null'
);

-- Mock JWT claims for a test user
-- Create test customer
WITH new_cust AS (
    INSERT INTO public.customer (full_name, phone, email)
    VALUES ('Test Cust', '123456789', 'test@example.com')
    RETURNING customer_id
),
new_user AS (
    INSERT INTO auth.users (id, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000001', '{"display_name": "Test Customer"}')
    RETURNING id
)
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT id::text FROM new_user), 'role', 'authenticated')::text, true);

UPDATE public.profiles 
SET app_role = 'CUSTOMER', customer_id = (SELECT customer_id FROM public.customer WHERE email = 'test@example.com')
WHERE user_id = '00000000-0000-0000-0000-000000000001';

-- test active user
SELECT is(
    (SELECT authz_private.is_active_user()),
    true,
    'is_active_user() returns true for active profile'
);

SELECT is(
    (SELECT authz_private.current_app_role()),
    'CUSTOMER',
    'current_app_role() returns CUSTOMER'
);

-- set inactive
UPDATE public.profiles 
SET is_active = false 
WHERE user_id = '00000000-0000-0000-0000-000000000001';

SELECT is(
    (SELECT authz_private.is_active_user()),
    false,
    'is_active_user() returns false for inactive profile'
);

SELECT is(
    (SELECT authz_private.current_app_role()),
    NULL,
    'current_app_role() returns NULL for inactive profile'
);

ROLLBACK;
