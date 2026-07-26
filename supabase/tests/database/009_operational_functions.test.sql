BEGIN;
SELECT plan(20);
-- Fixture
INSERT INTO public.transit_hub (hub_id, hub_code, hub_name) VALUES 
(901, 'TST-01', 'Test Hub 1'),
(902, 'TST-02', 'Test Hub 2');

INSERT INTO public.staff (staff_id, full_name, hub_id) VALUES 
(901, 'Staff Hub 1', 901),
(902, 'Staff Hub 2', 902);

INSERT INTO public.customer (customer_id, full_name, email, phone) VALUES 
(901, 'Sender', 'sender@test.com', '555-1001'),
(902, 'Receiver', 'receiver@test.com', '555-1002');

INSERT INTO public.service_type (service_id, service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES 
(901, 'Standard Test', 10.0, 2.0, 48, 20.0);

SELECT set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
SET LOCAL ROLE service_role;

-- 1. Create a package manually for F3 tests
INSERT INTO public.package (package_id, tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status) VALUES
(9001, 'TRK-9001', 901, 902, 901, 5.0, 901, 902, 'REGISTERED');

INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES 
(9001, 901, 'REGISTERED', now() - interval '2 hours', NULL);

-- 1. F3: Record checkpoint scan with correct staff
SELECT lives_ok($$ SELECT public.fn_record_checkpoint_scan('TRK-9001', 901, 'PICKED_UP', now() - interval '1 hour', 901) $$, 'Valid scan by correct staff succeeds');

-- 2. F3: Record checkpoint scan with wrong hub staff
PREPARE test_wrong_staff AS
SELECT public.fn_record_checkpoint_scan('TRK-9001', 901, 'IN_TRANSIT', now(), 902);
SELECT throws_ok('test_wrong_staff', 'Staff 902 does not belong to hub 901.', 'Staff from wrong hub is rejected');

-- 3. F3: Null staff rejected for operator scan
PREPARE test_null_staff AS
SELECT public.fn_record_checkpoint_scan('TRK-9001', 901, 'IN_TRANSIT', now(), NULL);
SELECT throws_ok('test_null_staff', 'Operator scan requires recorded_by staff ID.', 'Null staff rejected for operator scan');

-- 4. F4: Current hub inventory (TRK-9001 is at 901)
SELECT results_eq(
    $$ SELECT tracking_no FROM public.fn_current_hub_inventory(901) $$,
    $$ VALUES ('TRK-9001') $$,
    'TRK-9001 is in hub 901 inventory'
);

-- 5. F4: Hub 902 inventory is empty
SELECT is_empty(
    $$ SELECT tracking_no FROM public.fn_current_hub_inventory(902) $$,
    'Hub 902 inventory is empty'
);

-- 6. F5: Customer update successful partial update
SELECT results_eq(
    $$ SELECT email FROM public.fn_update_customer(901, p_email := 'newsender@test.com') $$,
    $$ VALUES ('newsender@test.com') $$,
    'Customer email updated correctly'
);
SELECT results_eq(
    $$ SELECT phone FROM public.customer WHERE customer_id = 901 $$,
    $$ VALUES ('555-1001') $$,
    'Customer phone was not changed by partial email update'
);

-- 7. F3: REGISTERED with NULL staff rejected
PREPARE test_registered_null_staff AS
SELECT public.fn_record_checkpoint_scan('TRK-9001', 901, 'REGISTERED', now(), NULL);
SELECT throws_ok('test_registered_null_staff', 'Operator scan requires recorded_by staff ID.', 'REGISTERED with NULL staff rejected in F3');

-- 8. F3: Non-REGISTERED with NULL staff rejected
PREPARE test_intransit_null_staff AS
SELECT public.fn_record_checkpoint_scan('TRK-9001', 901, 'IN_TRANSIT', now(), NULL);
SELECT throws_ok('test_intransit_null_staff', 'Operator scan requires recorded_by staff ID.', 'Non-REGISTERED with NULL staff rejected in F3');

-- 9. F5: Customer duplicate email rejected
PREPARE test_duplicate_email AS
SELECT public.fn_update_customer(902, p_email := 'newsender@test.com');
SELECT throws_like('test_duplicate_email', '%unique constraint "customer_email_key"%', 'Customer duplicate email rejected');

-- 10. F5: Customer blank name rejected
PREPARE test_blank_name AS
SELECT public.fn_update_customer(901, p_name := '   ');
SELECT throws_ok('test_blank_name', 'Customer name cannot be blank.', 'Blank name rejected');

-- 11. Verify cache and count unchanged after F3 rejection
SELECT results_eq(
    $$ SELECT count(*)::integer FROM public.tracking_event WHERE package_id = (SELECT package_id FROM public.package WHERE tracking_no = 'TRK-9001') $$,
    $$ VALUES (2::integer) $$,
    'Tracking event count unchanged after F3 rejections'
);

-- 12. F5: Missing customer ID rejected
PREPARE test_missing_customer AS
SELECT public.fn_update_customer(999, p_name := 'Nowhere');
SELECT throws_ok('test_missing_customer', 'Customer not found: 999', 'Missing customer rejected');

-- 13. F5: Blank email rejected
PREPARE test_blank_email AS
SELECT public.fn_update_customer(901, p_email := '   ');
SELECT throws_ok('test_blank_email', 'Customer email cannot be blank.', 'Blank email rejected');

-- 14. F5: Blank phone rejected
PREPARE test_blank_phone AS
SELECT public.fn_update_customer(901, p_phone := '   ');
SELECT throws_ok('test_blank_phone', 'Customer phone cannot be blank.', 'Blank phone rejected');

-- 15. F5: Duplicate phone rejected
PREPARE test_duplicate_phone AS
SELECT public.fn_update_customer(902, p_phone := '555-1001');
SELECT throws_like('test_duplicate_phone', '%unique constraint "customer_phone_key"%', 'Customer duplicate phone rejected');

-- 16. F5: NULL preserves existing values
SELECT results_eq(
    $$ SELECT full_name || email || phone FROM public.fn_update_customer(901, p_name := NULL, p_email := NULL, p_phone := NULL) $$,
    $$ VALUES ('Sender' || 'newsender@test.com' || '555-1001') $$,
    'NULL parameters explicitly preserve existing name, email and phone'
);

-- 17. F5: No partial mutation after duplicate phone rejection
SELECT results_eq(
    $$ SELECT customer_id::text || full_name || email FROM public.customer WHERE customer_id = 902 $$,
    $$ VALUES ('902Receiverreceiver@test.com') $$,
    'Rejected duplicate phone update does not partially modify customer_id, name or email'
);

-- 18. F5: No mutation to other customers
SELECT results_eq(
    $$ SELECT full_name FROM public.customer WHERE customer_id = 901 $$,
    $$ VALUES ('Sender') $$,
    'Rejected call for customer 902 did not mutate another customer (901)'
);

-- 19. F5: No package mutation
SELECT results_eq(
    $$ SELECT count(*)::integer FROM public.package $$,
    $$ VALUES (1::integer) $$,
    'No package is added or removed during F5 failures'
);

SELECT * FROM finish();
ROLLBACK;
