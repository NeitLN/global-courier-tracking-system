BEGIN;
SELECT plan(10);

-- 1. Setup isolated driver and delivery attempt data
INSERT INTO public.transit_hub (hub_code, hub_name) VALUES 
  ('PH11-H1', 'Phase 11 Hub 1');

INSERT INTO public.driver (full_name, license_no, phone, base_hub_id) VALUES
  ('Phase 11 Driver 1', 'PH11-LIC01', 'PH11-PH01', (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH11-H1')),
  ('Phase 11 Driver 2', 'PH11-LIC02', 'PH11-PH02', (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'PH11-H1'));

-- Setup authentication profiles
-- User 1: Active ANALYST
INSERT INTO auth.users (id, email) VALUES ('10111011-1011-1011-1011-101110111011', 'p11-analyst@example.com');
UPDATE public.profiles SET app_role = 'ANALYST', is_active = true WHERE user_id = '10111011-1011-1011-1011-101110111011';

-- User 2: Active CUSTOMER
INSERT INTO public.customer (full_name, phone, email) VALUES ('PH11 Normal Cust', 'PH11-CUST', 'p11-cust@example.com');
INSERT INTO auth.users (id, email) VALUES ('20112011-2011-2011-2011-201120112011', 'p11-cust@example.com');
UPDATE public.profiles SET app_role = 'CUSTOMER', customer_id = (SELECT customer_id FROM public.customer WHERE email = 'p11-cust@example.com'), is_active = true WHERE user_id = '20112011-2011-2011-2011-201120112011';

-- User 3: Inactive ANALYST
INSERT INTO auth.users (id, email) VALUES ('30113011-3011-3011-3011-301130113011', 'p11-inactive-analyst@example.com');
UPDATE public.profiles SET app_role = 'ANALYST', is_active = false WHERE user_id = '30113011-3011-3011-3011-301130113011';


-- ============================================================================
-- A. PRIVILEGES & SIGNATURE
-- ============================================================================

-- Assertion 1: Function exists and matches the signature
SELECT has_function(
    'public',
    'fn_get_analyst_driver_performance',
    ARRAY[]::text[],
    'Function fn_get_analyst_driver_performance exists'
);

-- Assertion 2: Function is SECURITY DEFINER
SELECT is_definer(
    'public',
    'fn_get_analyst_driver_performance',
    ARRAY[]::text[],
    'Function fn_get_analyst_driver_performance is SECURITY DEFINER'
);

-- Assertion 3: Function search_path is configured empty
SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_proc WHERE proname = 'fn_get_analyst_driver_performance' AND proconfig @> ARRAY['search_path=""']
    ),
    'Function fn_get_analyst_driver_performance search_path is set to empty string'
);

-- Assertion 4: anon has NO execute privileges
SELECT ok(
    NOT has_function_privilege('anon', 'public.fn_get_analyst_driver_performance()', 'EXECUTE'),
    'anon should not have EXECUTE privilege'
);

-- Assertion 5: PUBLIC has NO execute privileges
SELECT ok(
    NOT has_function_privilege('public', 'public.fn_get_analyst_driver_performance()', 'EXECUTE'),
    'PUBLIC should not have EXECUTE privilege'
);

-- Assertion 6: authenticated role has execute privileges
SELECT ok(
    has_function_privilege('authenticated', 'public.fn_get_analyst_driver_performance()', 'EXECUTE'),
    'authenticated should have EXECUTE privilege'
);


-- ============================================================================
-- B. ROLE EXECUTIONS
-- ============================================================================

-- Set JWT context to active ANALYST
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '10111011-1011-1011-1011-101110111011', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Assertion 7: Active ANALYST can successfully call the RPC
SELECT lives_ok(
    $$ SELECT * FROM public.fn_get_analyst_driver_performance() $$,
    'Active ANALYST can successfully call fn_get_analyst_driver_performance'
);

-- Assertion 8: Correct rows are returned
SELECT ok(
    EXISTS (
        SELECT 1 FROM public.fn_get_analyst_driver_performance() WHERE driver_name = 'Phase 11 Driver 1'
    ),
    'Active ANALYST successfully retrieves ranking records'
);


-- ============================================================================
-- C. AUTHORIZATION REJECTIONS
-- ============================================================================

-- Active CUSTOMER is rejected
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '20112011-2011-2011-2011-201120112011', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Assertion 9: CUSTOMER is rejected
SELECT throws_ok(
    $$ SELECT * FROM public.fn_get_analyst_driver_performance() $$,
    NULL,
    NULL,
    'CUSTOMER role is rejected from executing fn_get_analyst_driver_performance'
);

-- Inactive ANALYST is rejected
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '30113011-3011-3011-3011-301130113011', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Assertion 10: Inactive ANALYST is rejected
SELECT throws_ok(
    $$ SELECT * FROM public.fn_get_analyst_driver_performance() $$,
    NULL,
    NULL,
    'Inactive ANALYST profile is rejected from executing fn_get_analyst_driver_performance'
);

SELECT * FROM finish();
ROLLBACK;
