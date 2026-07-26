BEGIN;
SELECT plan(12);

-- 1. PUBLIC execute revoked from fns
SELECT ok(
    NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
          AND p.proname IN ('fn_register_package', 'fn_track_package', 'fn_record_checkpoint_scan', 'fn_update_customer')
          AND has_function_privilege('public', p.oid, 'EXECUTE')
    ),
    'PUBLIC should not have EXECUTE privilege on application RPCs'
);

-- 2. Trigger functions not executable by authenticated
SELECT ok(
    NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
          AND p.proname IN ('fn_validate_tracking_status', 'fn_sync_package_status', 'fn_prevent_history_mutation')
          AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
    ),
    'authenticated should not have EXECUTE privilege on trigger functions'
);

-- 3. Inactive user cannot use display name update
WITH new_user AS (
    INSERT INTO auth.users (id, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000006', '{"display_name": "Inactive"}')
    RETURNING id
)
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT id::text FROM new_user), 'role', 'authenticated')::text, true);

UPDATE public.profiles 
SET is_active = false
WHERE user_id = '00000000-0000-0000-0000-000000000006';

SET ROLE authenticated;

SELECT throws_ok(
    $$ SELECT public.fn_update_display_name('Still Inactive'); $$,
    NULL,
    NULL,
    'Inactive user cannot update display name'
);

RESET ROLE;

-- REGRESSION TESTS FOR TRUSTED BACKEND

-- Setup for regressions
INSERT INTO public.customer (full_name, phone, email) VALUES ('Target Cust', 'REG001', 'regtarget@example.com');
INSERT INTO public.customer (full_name, phone, email) VALUES ('Attacker Cust', 'REG002', 'regattacker@example.com');
INSERT INTO auth.users (id, email) VALUES ('11111111-1111-1111-1111-111111111111', 'targetuser@example.com');
INSERT INTO auth.users (id, email) VALUES ('22222222-2222-2222-2222-222222222222', 'attackeruser@example.com');
INSERT INTO public.transit_hub (hub_code, hub_name) VALUES ('REG-01', 'Reg Hub 1');
INSERT INTO public.transit_hub (hub_code, hub_name) VALUES ('REG-02', 'Reg Hub 2');
INSERT INTO public.service_type (service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES ('Reg Service', 10, 1, 24, 20);

UPDATE public.profiles SET app_role = 'CUSTOMER', customer_id = (SELECT customer_id FROM public.customer WHERE email = 'regtarget@example.com') WHERE user_id = '11111111-1111-1111-1111-111111111111';
UPDATE public.profiles SET app_role = 'CUSTOMER', customer_id = (SELECT customer_id FROM public.customer WHERE email = 'regattacker@example.com') WHERE user_id = '22222222-2222-2222-2222-222222222222';

SELECT set_config('test.target_id', (SELECT customer_id::text FROM public.customer WHERE email = 'regtarget@example.com'), true);
SELECT set_config('test.attacker_id', (SELECT customer_id::text FROM public.customer WHERE email = 'regattacker@example.com'), true);
SELECT set_config('test.svc_id', (SELECT service_id::text FROM public.service_type WHERE service_name = 'Reg Service'), true);
SELECT set_config('test.h1_id', (SELECT hub_id::text FROM public.transit_hub WHERE hub_code = 'REG-01'), true);
SELECT set_config('test.h2_id', (SELECT hub_id::text FROM public.transit_hub WHERE hub_code = 'REG-02'), true);

-- A. ORIGINAL EXPLOIT REGRESSION
-- Connection is postgres (we don't SET ROLE).
-- We set JWT to attacker user.
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text, true);

SELECT throws_ok(
    $$ SELECT public.fn_register_package(current_setting('test.target_id')::bigint, current_setting('test.attacker_id')::bigint, current_setting('test.svc_id')::bigint, 1, NULL, NULL, NULL, current_setting('test.h1_id')::bigint, current_setting('test.h2_id')::bigint) $$,
    NULL,
    NULL,
    'Exploit A: Postgres physical connection without SET ROLE service_role cannot bypass sender check'
);

-- Prove no exploit package inserted
SELECT is(
    (SELECT COUNT(*)::int FROM public.package WHERE sender_id = current_setting('test.target_id')::bigint),
    0,
    'Exploit A: No package was inserted via exploit'
);

-- B. FORGED SERVICE_ROLE CLAIM
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'service_role')::text, true);
SET ROLE authenticated;

SELECT throws_ok(
    $$ SELECT public.fn_register_package(current_setting('test.target_id')::bigint, current_setting('test.attacker_id')::bigint, current_setting('test.svc_id')::bigint, 1, NULL, NULL, NULL, current_setting('test.h1_id')::bigint, current_setting('test.h2_id')::bigint) $$,
    NULL,
    NULL,
    'Exploit B: Forged service_role JWT claim under authenticated role is denied'
);

RESET ROLE;

-- C. LEGITIMATE CUSTOMER
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

SELECT lives_ok(
    $$ SELECT public.fn_register_package(current_setting('test.attacker_id')::bigint, current_setting('test.target_id')::bigint, current_setting('test.svc_id')::bigint, 1::numeric, NULL, NULL, NULL, current_setting('test.h1_id')::bigint, current_setting('test.h2_id')::bigint) $$,
    'C: Legitimate CUSTOMER can register package for themselves'
);

RESET ROLE;

-- D. LEGITIMATE SERVICE ROLE
SELECT set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
SET LOCAL ROLE service_role;

SELECT lives_ok(
    $$ SELECT public.fn_register_package(current_setting('test.target_id')::bigint, current_setting('test.attacker_id')::bigint, current_setting('test.svc_id')::bigint, 1::numeric, NULL, NULL, NULL, current_setting('test.h1_id')::bigint, current_setting('test.h2_id')::bigint) $$,
    'D: Legitimate service_role connection with service_role claim succeeds'
);

RESET ROLE;

-- E. ANON AND MISSING CLAIMS
SELECT set_config('request.jwt.claims', '', true);
SET LOCAL ROLE anon;

SELECT throws_ok(
    $$ SELECT public.fn_register_package(1, 2, 1, 1, NULL, NULL, NULL, 1, 2) $$,
    '42501',
    NULL,
    'E: anon cannot execute function at all'
);

RESET ROLE;
SET LOCAL ROLE authenticated;
-- Claims still empty
SELECT throws_ok(
    $$ SELECT public.fn_register_package(1, 2, 1, 1, NULL, NULL, NULL, 1, 2) $$,
    NULL,
    NULL,
    'E: authenticated with no claims is denied'
);

RESET ROLE;

-- F. ANALYTICS REGRESSION
-- Try to call rank driver (DISPATCHER only) as CUSTOMER with forged service_role claim
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'service_role')::text, true);
SET ROLE authenticated;

SELECT throws_ok(
    $$ SELECT * FROM public.fn_rank_driver_performance() $$,
    NULL,
    NULL,
    'F: Forged service_role claim cannot bypass analytics RPC checks'
);

RESET ROLE;

-- G. STATIC SAFETY AUDIT
-- Prove none of the 10 RPCs contain session_user or current_user checks 
-- that would bypass the primary authorization
SELECT is(
    (SELECT COUNT(*)::int FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN (
          'fn_register_package', 'fn_record_checkpoint_scan', 'fn_update_customer',
          'fn_track_package', 'fn_chain_of_custody', 'fn_current_hub_inventory',
          'fn_find_routes', 'fn_inter_scan_hub_analysis', 'fn_sla_compliance',
          'fn_rank_driver_performance'
       )
       AND pg_get_functiondef(p.oid) ~* '(session_user|current_user|current_setting\(''role''\)\s*(?:=|IN)\s*\(?''none'')'
    ),
    0,
    'G: Static audit confirms no RPC uses session_user, current_user, or role=none for bypass'
);

ROLLBACK;