BEGIN;
SELECT plan(15);

-- Fixture
INSERT INTO public.transit_hub (hub_id, hub_code, hub_name) VALUES 
(901, 'TST-01', 'Test Hub 1'),
(902, 'TST-02', 'Test Hub 2');

INSERT INTO public.customer (customer_id, full_name, email, phone) VALUES 
(901, 'Sender', 'sender@test.com', '555-1001'),
(902, 'Receiver', 'receiver@test.com', '555-1002');

INSERT INTO public.service_type (service_id, service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES 
(901, 'Standard Test', 10.0, 2.0, 48, 20.0);

INSERT INTO public.package (package_id, tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status) VALUES
(9001, 'TRK-9001', 901, 902, 901, 5.0, 901, 902, 'REGISTERED');

-- 1. Test first event must be REGISTERED
PREPARE test_first_event_invalid AS 
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 901, 'IN_TRANSIT', now());
SELECT throws_ok('test_first_event_invalid', 'First tracking event must be REGISTERED (R6).', 'First event other than REGISTERED should be rejected');

-- 2. Test valid first event REGISTERED
SELECT lives_ok($$ INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 901, 'REGISTERED', now() - interval '1 hour') $$, 'Valid first event REGISTERED accepted');

-- 3. Cache verification
SELECT results_eq(
    $$ SELECT current_status FROM public.package WHERE package_id = 9001 $$,
    $$ VALUES ('REGISTERED') $$,
    'Cache updated to REGISTERED'
);

-- 4. Test repeated REGISTERED
SELECT lives_ok($$ INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 901, 'REGISTERED', now() - interval '55 minutes') $$, 'REGISTERED -> REGISTERED allowed');

-- 5. Test invalid jump REGISTERED -> IN_TRANSIT
PREPARE test_invalid_jump AS
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 901, 'IN_TRANSIT', now() - interval '50 minutes');
SELECT throws_ok('test_invalid_jump', 'Invalid status transition from REGISTERED to IN_TRANSIT (R6).', 'REGISTERED -> IN_TRANSIT rejected');

-- 6. Test valid advance REGISTERED -> PICKED_UP
SELECT lives_ok($$ INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 901, 'PICKED_UP', now() - interval '45 minutes') $$, 'REGISTERED -> PICKED_UP allowed');

-- 7. Test backward transition PICKED_UP -> REGISTERED
PREPARE test_backward AS
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 901, 'REGISTERED', now() - interval '40 minutes');
SELECT throws_ok('test_backward', 'Invalid status transition from PICKED_UP to REGISTERED (R6).', 'Backward transition rejected');

-- 8. Valid advance PICKED_UP -> IN_TRANSIT
SELECT lives_ok($$ INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 901, 'IN_TRANSIT', now() - interval '35 minutes') $$, 'PICKED_UP -> IN_TRANSIT allowed');

-- 9. Repeated IN_TRANSIT
SELECT lives_ok($$ INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 902, 'IN_TRANSIT', now() - interval '30 minutes') $$, 'IN_TRANSIT -> IN_TRANSIT allowed');

-- 10. Valid advance IN_TRANSIT -> OUT_FOR_DELIVERY
SELECT lives_ok($$ INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 902, 'OUT_FOR_DELIVERY', now() - interval '25 minutes') $$, 'IN_TRANSIT -> OUT_FOR_DELIVERY allowed');

-- 11. OUT_FOR_DELIVERY -> DELIVERED
SELECT lives_ok($$ INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 902, 'DELIVERED', now() - interval '20 minutes') $$, 'OUT_FOR_DELIVERY -> DELIVERED allowed');

-- 12. Test event after terminal DELIVERED
PREPARE test_after_terminal AS
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 902, 'RETURNED', now() - interval '15 minutes');
SELECT throws_ok('test_after_terminal', 'Cannot add tracking event after a terminal status (DELIVERED).', 'Event after DELIVERED rejected');

-- 13. Test non-terminal -> RETURNED (using a new package)
INSERT INTO public.package (package_id, tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status) VALUES
(9002, 'TRK-9002', 901, 902, 901, 5.0, 901, 902, 'REGISTERED');
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9002, 901, 'REGISTERED', now() - interval '2 hours');
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9002, 901, 'PICKED_UP', now() - interval '1.5 hours');
SELECT lives_ok($$ INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9002, 901, 'RETURNED', now() - interval '1 hour') $$, 'PICKED_UP -> RETURNED allowed');

-- 14. Event after RETURNED
PREPARE test_after_returned AS
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9002, 901, 'DELIVERED', now());
SELECT throws_ok('test_after_returned', 'Cannot add tracking event after a terminal status (RETURNED).', 'Event after RETURNED rejected');

-- 15. Invalid old event timestamp
PREPARE test_old_timestamp AS
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 902, 'DELIVERED', now() - interval '30 minutes');
SELECT throws_ok('test_old_timestamp', 'New event time must be strictly later than the latest existing event time.', 'Event timestamp not strictly later rejected');

SELECT * FROM finish();
ROLLBACK;
