BEGIN;
SELECT plan(6);

-- Setup
WITH new_user AS (
    INSERT INTO auth.users (id, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000001', '{"display_name": "Test Profile"}')
    RETURNING id
)
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', id::text, 'role', 'authenticated')::text, true)
FROM new_user;

-- Verify own profile visible
SET ROLE authenticated;

SELECT is(
    (SELECT display_name FROM public.profiles WHERE user_id = '00000000-0000-0000-0000-000000000001'),
    'Test Profile',
    'Authenticated user can read own profile'
);

-- Try to read other profile
SELECT is(
    (SELECT COUNT(*)::int FROM public.profiles WHERE user_id <> '00000000-0000-0000-0000-000000000001'),
    0,
    'Authenticated user cannot read other profiles'
);

-- Test fn_update_display_name
SELECT lives_ok(
    $$ SELECT public.fn_update_display_name('New Name'); $$,
    'Can update display name via RPC'
);

SELECT is(
    (SELECT display_name FROM public.profiles WHERE user_id = '00000000-0000-0000-0000-000000000001'),
    'New Name',
    'Display name was successfully updated'
);

-- Direct update denied
SELECT throws_ok(
    $$ UPDATE public.profiles SET display_name = 'Hacked' WHERE user_id = '00000000-0000-0000-0000-000000000001'; $$,
    '42501',
    NULL,
    'Direct UPDATE on profiles is denied'
);

-- Direct insert denied
SELECT throws_ok(
    $$ INSERT INTO public.profiles (user_id) VALUES ('00000000-0000-0000-0000-000000000002'); $$,
    '42501',
    NULL,
    'Direct INSERT on profiles is denied'
);

ROLLBACK;
