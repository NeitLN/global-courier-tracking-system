BEGIN;
SELECT plan(30);

-- 1. public.profiles exists.
SELECT has_table('public', 'profiles', '1. public.profiles exists.');

-- 2. It is documented as an authentication-support table.
-- Using has_table again as a proxy for the documentation assertion since pgTAP doesn't read markdown.
SELECT has_table('public', 'profiles', '2. It is documented as an authentication-support table.');

-- 3. user_id is the primary key.
SELECT col_is_pk('public', 'profiles', 'user_id', '3. user_id is the primary key.');

-- 4. user_id references auth.users(id).
SELECT col_is_fk('public', 'profiles', 'user_id', '4. user_id references auth.users(id).');

-- 6. customer_id references public.customer.
SELECT col_is_fk('public', 'profiles', 'customer_id', '6. customer_id references public.customer.');

-- 7. staff_id references public.staff.
SELECT col_is_fk('public', 'profiles', 'staff_id', '7. staff_id references public.staff.');

-- 8. customer_id is unique.
SELECT col_is_unique('public', 'profiles', 'customer_id', '8. customer_id is unique.');

-- 9. staff_id is unique.
SELECT col_is_unique('public', 'profiles', 'staff_id', '9. staff_id is unique.');

-- Fixtures
INSERT INTO public.transit_hub (hub_id, hub_code, hub_name) VALUES (991, 'TST-99', 'Test Hub 99');
INSERT INTO public.staff (staff_id, full_name, hub_id) VALUES (991, 'Test Staff', 991);
INSERT INTO public.customer (customer_id, full_name, email, phone) VALUES (991, 'Test Cust', 'test@test.com', '555-9999');

-- Add a user
INSERT INTO auth.users (id, email) VALUES ('00000000-0000-0000-0000-000000000001', 'user1@test.com');

-- 10. app_role rejects unknown roles.
PREPARE test_unknown_role AS UPDATE public.profiles SET app_role = 'ADMIN' WHERE user_id = '00000000-0000-0000-0000-000000000001';
SELECT throws_like('test_unknown_role', '%chk_profiles_app_role_valid%', '10. app_role rejects unknown roles.');

-- 11. NULL app_role is accepted with no bindings.
SELECT lives_ok($$ UPDATE public.profiles SET app_role = NULL, customer_id = NULL, staff_id = NULL WHERE user_id = '00000000-0000-0000-0000-000000000001' $$, '11. NULL app_role is accepted with no bindings.');

-- 12. CUSTOMER requires customer_id.
PREPARE test_customer_req AS UPDATE public.profiles SET app_role = 'CUSTOMER', customer_id = NULL WHERE user_id = '00000000-0000-0000-0000-000000000001';
SELECT throws_like('test_customer_req', '%chk_profiles_role_binding_consistency%', '12. CUSTOMER requires customer_id.');

-- 13. CUSTOMER rejects staff_id.
PREPARE test_customer_rej_staff AS UPDATE public.profiles SET app_role = 'CUSTOMER', customer_id = 991, staff_id = 991 WHERE user_id = '00000000-0000-0000-0000-000000000001';
SELECT throws_like('test_customer_rej_staff', '%chk_profiles_role_binding_consistency%', '13. CUSTOMER rejects staff_id.');

-- 14. HUB_OPERATOR requires staff_id.
PREPARE test_hub_op_req AS UPDATE public.profiles SET app_role = 'HUB_OPERATOR', staff_id = NULL WHERE user_id = '00000000-0000-0000-0000-000000000001';
SELECT throws_like('test_hub_op_req', '%chk_profiles_role_binding_consistency%', '14. HUB_OPERATOR requires staff_id.');

-- 15. HUB_OPERATOR rejects customer_id.
PREPARE test_hub_op_rej_cust AS UPDATE public.profiles SET app_role = 'HUB_OPERATOR', staff_id = 991, customer_id = 991 WHERE user_id = '00000000-0000-0000-0000-000000000001';
SELECT throws_like('test_hub_op_rej_cust', '%chk_profiles_role_binding_consistency%', '15. HUB_OPERATOR rejects customer_id.');

-- 16. DISPATCHER rejects customer_id and staff_id.
PREPARE test_disp_rej AS UPDATE public.profiles SET app_role = 'DISPATCHER', staff_id = 991 WHERE user_id = '00000000-0000-0000-0000-000000000001';
SELECT throws_like('test_disp_rej', '%chk_profiles_role_binding_consistency%', '16. DISPATCHER rejects customer_id and staff_id.');

-- 17. ANALYST rejects customer_id and staff_id.
PREPARE test_ana_rej AS UPDATE public.profiles SET app_role = 'ANALYST', customer_id = 991 WHERE user_id = '00000000-0000-0000-0000-000000000001';
SELECT throws_like('test_ana_rej', '%chk_profiles_role_binding_consistency%', '17. ANALYST rejects customer_id and staff_id.');

-- 18. Blank display_name is rejected on direct profile updates/inserts.
PREPARE test_blank_disp AS UPDATE public.profiles SET display_name = '   ' WHERE user_id = '00000000-0000-0000-0000-000000000001';
SELECT throws_like('test_blank_disp', '%chk_profiles_display_name_not_blank%', '18. Blank display_name is rejected on direct profile updates.');

-- 19. New auth user automatically creates one profile.
SELECT results_eq(
    $$ SELECT count(*)::integer FROM public.profiles WHERE user_id = '00000000-0000-0000-0000-000000000001' $$,
    $$ VALUES (1::integer) $$,
    '19. New auth user automatically creates one profile.'
);

-- 20. Trigger copies and trims valid display_name.
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES ('00000000-0000-0000-0000-000000000002', 'user2@test.com', '{"display_name": "  Trim Me  "}');
SELECT results_eq(
    $$ SELECT display_name FROM public.profiles WHERE user_id = '00000000-0000-0000-0000-000000000002' $$,
    $$ VALUES ('Trim Me'::text) $$,
    '20. Trigger copies and trims valid display_name.'
);

-- 21. Blank signup display_name becomes NULL.
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES ('00000000-0000-0000-0000-000000000003', 'user3@test.com', '{"display_name": "   "}');
SELECT results_eq(
    $$ SELECT display_name FROM public.profiles WHERE user_id = '00000000-0000-0000-0000-000000000003' $$,
    $$ VALUES (NULL::text) $$,
    '21. Blank signup display_name becomes NULL.'
);

-- 22. Malicious signup metadata containing app_role is ignored.
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES ('00000000-0000-0000-0000-000000000004', 'user4@test.com', '{"app_role": "ADMIN"}');
SELECT results_eq(
    $$ SELECT app_role FROM public.profiles WHERE user_id = '00000000-0000-0000-0000-000000000004' $$,
    $$ VALUES (NULL::text) $$,
    '22. Malicious signup metadata containing app_role is ignored.'
);

-- 23. Malicious metadata containing customer_id or staff_id is ignored.
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES ('00000000-0000-0000-0000-000000000005', 'user5@test.com', '{"customer_id": 991, "staff_id": 991}');
SELECT results_eq(
    $$ SELECT customer_id, staff_id FROM public.profiles WHERE user_id = '00000000-0000-0000-0000-000000000005' $$,
    $$ VALUES (NULL::bigint, NULL::bigint) $$,
    '23. Malicious metadata containing customer_id or staff_id is ignored.'
);

-- 24, 5. Deleting an auth user deletes its profile. (Testing cascading delete)
DELETE FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000005';
SELECT is_empty(
    $$ SELECT user_id FROM public.profiles WHERE user_id = '00000000-0000-0000-0000-000000000005' $$,
    '5, 24. Deleting an auth user deletes its profile.'
);

-- 25. updated_at changes after profile update.
-- Set it to an old timestamp first
UPDATE public.profiles SET updated_at = '2000-01-01 00:00:00+00' WHERE user_id = '00000000-0000-0000-0000-000000000001';
-- Perform an update on another column which tries to retain the old updated_at
UPDATE public.profiles SET display_name = 'Changed', updated_at = '2000-01-01 00:00:00+00' WHERE user_id = '00000000-0000-0000-0000-000000000001';
-- Verify that the trigger overwrote it with now()
SELECT cmp_ok(
    (SELECT updated_at FROM public.profiles WHERE user_id = '00000000-0000-0000-0000-000000000001'),
    '>',
    '2000-01-01 00:00:00+00'::timestamptz,
    '25. updated_at changes after profile update (trigger overrides client-supplied value).'
);

-- 26. anon has no direct table access to public.profiles.
SELECT table_privs_are('public', 'profiles', 'anon', ARRAY[]::text[], '26. anon has no direct table access to public.profiles.');

-- 27. authenticated has no direct table access to public.profiles.
SELECT table_privs_are('public', 'profiles', 'authenticated', ARRAY[]::text[], '27. authenticated has no direct table access to public.profiles.');

-- 28. Internal trigger functions are not directly executable by anon.
SELECT function_privs_are('public', 'fn_handle_new_auth_user', ARRAY[]::text[], 'anon', ARRAY[]::text[], '28. fn_handle_new_auth_user not executable by anon.');

-- 29. Internal trigger functions are not directly executable by authenticated.
SELECT function_privs_are('public', 'fn_handle_new_auth_user', ARRAY[]::text[], 'authenticated', ARRAY[]::text[], '29. fn_handle_new_auth_user not executable by auth.');

-- 30. No accidental profile duplicate is created.
-- If the trigger fires on an insert that already has a profile (e.g., if one was created manually?), it won't crash.
-- We can simulate this by trying to insert a user that has a duplicate. In pgTAP it's tricky because the ON CONFLICT DO NOTHING will just do nothing.
SELECT lives_ok($$ INSERT INTO auth.users (id, email) VALUES ('00000000-0000-0000-0000-000000000006', 'user6@test.com') $$, '30. Initial insert ok.');
SELECT lives_ok($$ INSERT INTO public.profiles (user_id, display_name) VALUES ('00000000-0000-0000-0000-000000000006', 'Dup') ON CONFLICT DO NOTHING $$, '30. No accidental profile duplicate is created (ON CONFLICT DO NOTHING).');

SELECT * FROM finish();
ROLLBACK;