BEGIN;
SELECT plan(3);

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

INSERT INTO public.tracking_event (event_id, package_id, hub_id, status_code, event_time) VALUES 
(9001, 9001, 901, 'REGISTERED', now() - interval '1 hour');

-- 1. Test update rejected
PREPARE test_update AS
UPDATE public.tracking_event SET status_code = 'PICKED_UP' WHERE event_id = 9001;
SELECT throws_ok('test_update', 'Tracking history is append-only. Updates and deletions are forbidden (R7).', 'Tracking event update is rejected');

-- 2. Test delete rejected
PREPARE test_delete AS
DELETE FROM public.tracking_event WHERE event_id = 9001;
SELECT throws_ok('test_delete', 'Tracking history is append-only. Updates and deletions are forbidden (R7).', 'Tracking event deletion is rejected');

-- 3. Test insert remains allowed
SELECT lives_ok($$ INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time) VALUES (9001, 901, 'PICKED_UP', now()) $$, 'Tracking event insert is allowed');

SELECT * FROM finish();
ROLLBACK;
