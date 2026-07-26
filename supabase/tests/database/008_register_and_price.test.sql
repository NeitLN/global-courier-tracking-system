BEGIN;
SELECT plan(16);

-- Fixture
INSERT INTO public.transit_hub (hub_id, hub_code, hub_name) VALUES 
(901, 'TST-01', 'Test Hub 1'),
(902, 'TST-02', 'Test Hub 2');

INSERT INTO public.customer (customer_id, full_name, email, phone) VALUES 
(901, 'Sender', 'sender@test.com', '555-1001'),
(902, 'Receiver', 'receiver@test.com', '555-1002');

INSERT INTO public.service_type (service_id, service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES 
(901, 'Standard Test', 10.0, 2.0, 48, 20.0);

SELECT set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
SET LOCAL ROLE service_role;

-- 1. Test sender = receiver rejected
PREPARE test_same_customer AS
SELECT public.fn_register_package(901, 901, 901, 5.0, 10, 10, 10, 901, 902);
SELECT throws_ok('test_same_customer', 'Sender and receiver cannot be the same customer.', 'Sender = Receiver is rejected');

-- 2. Test negative weight rejected
PREPARE test_negative_weight AS
SELECT public.fn_register_package(901, 902, 901, -5.0, 10, 10, 10, 901, 902);
SELECT throws_ok('test_negative_weight', 'Weight must be greater than 0.', 'Negative weight is rejected');

-- 3. Test weight > max_weight_kg rejected
PREPARE test_overweight AS
SELECT public.fn_register_package(901, 902, 901, 25.0, 10, 10, 10, 901, 902);
SELECT throws_ok('test_overweight', 'Weight 25.0 kg exceeds maximum allowed 20.00 kg for service Standard Test.', 'Weight exceeding max_weight_kg is rejected');

-- 4. Test invalid service rejected
PREPARE test_invalid_service AS
SELECT public.fn_register_package(901, 902, 999, 5.0, 10, 10, 10, 901, 902);
SELECT throws_ok('test_invalid_service', 'Invalid service_id: 999', 'Invalid service is rejected');

-- 5. Test successful registration
SELECT lives_ok($$ SELECT public.fn_register_package(901, 902, 901, 5.0, 10, 10, 10, 901, 902) $$, 'Valid package registration succeeds');

-- 6. Test fee calculation (10.0 + 2.0 * 5.0 = 20.00)
SELECT results_eq(
    $$ SELECT shipping_fee FROM public.package WHERE sender_id = 901 AND receiver_id = 902 LIMIT 1 $$,
    $$ VALUES (20.00::numeric) $$,
    'Shipping fee calculated correctly'
);

-- 7. Test initial event is REGISTERED
SELECT results_eq(
    $$ SELECT status_code FROM public.tracking_event WHERE package_id = (SELECT package_id FROM public.package WHERE sender_id = 901 LIMIT 1) LIMIT 1 $$,
    $$ VALUES ('REGISTERED') $$,
    'Initial event is REGISTERED'
);

-- 8. Test package current_status is REGISTERED
SELECT results_eq(
    $$ SELECT current_status FROM public.package WHERE sender_id = 901 LIMIT 1 $$,
    $$ VALUES ('REGISTERED') $$,
    'Package current_status is set to REGISTERED'
);

-- 9. Test omitted/defaulted hubs rejected
PREPARE test_omitted_hubs AS
SELECT public.fn_register_package(901, 902, 901, 5.0, 10, 10, 10);
SELECT throws_ok('test_omitted_hubs', 'Origin hub is required.', 'Omitted hubs are rejected');

-- 10. Test NULL origin rejected
PREPARE test_null_origin AS
SELECT public.fn_register_package(901, 902, 901, 5.0, 10, 10, 10, NULL, 902);
SELECT throws_ok('test_null_origin', 'Origin hub is required.', 'NULL origin is rejected');

-- 11. Test NULL destination rejected
PREPARE test_null_dest AS
SELECT public.fn_register_package(901, 902, 901, 5.0, 10, 10, 10, 901, NULL);
SELECT throws_ok('test_null_dest', 'Destination hub is required.', 'NULL destination is rejected');

-- 12. Test equal origin and destination
PREPARE test_equal_hubs AS
SELECT public.fn_register_package(901, 902, 901, 5.0, 10, 10, 10, 901, 901);
SELECT throws_ok('test_equal_hubs', 'Origin and destination hubs cannot be the same.', 'Equal origin and destination are rejected');

-- 13. Test unknown origin
PREPARE test_unknown_origin AS
SELECT public.fn_register_package(901, 902, 901, 5.0, 10, 10, 10, 999, 902);
SELECT throws_ok('test_unknown_origin', 'Origin hub not found: 999', 'Unknown origin is rejected');

-- 14. Test unknown destination
PREPARE test_unknown_dest AS
SELECT public.fn_register_package(901, 902, 901, 5.0, 10, 10, 10, 901, 999);
SELECT throws_ok('test_unknown_dest', 'Destination hub not found: 999', 'Unknown destination is rejected');

-- 15. Verify no partial packages remain
SELECT results_eq(
    $$ SELECT count(*)::integer FROM public.package $$,
    $$ VALUES (1::integer) $$,
    'Only the successful package remains, no partials'
);

-- 16. Test collision safety with multiple rapid insertions
SELECT isnt(
    (SELECT tracking_no FROM public.fn_register_package(901, 902, 901, 5.0, 10, 10, 10, 901, 902)),
    (SELECT tracking_no FROM public.fn_register_package(901, 902, 901, 5.0, 10, 10, 10, 901, 902)),
    'Rapid F1 calls generate distinct tracking numbers (retry branch reviewed statically)'
);

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
