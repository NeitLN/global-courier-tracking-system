BEGIN;
SELECT plan(4);

-- Fixture
INSERT INTO public.transit_hub (hub_id, hub_code, hub_name) VALUES 
(901, 'TST-01', 'Test Hub 1'),
(902, 'TST-02', 'Test Hub 2');

INSERT INTO public.staff (staff_id, full_name, hub_id) VALUES 
(901, 'Staff 1', 901),
(902, 'Staff 2', 902);

INSERT INTO public.customer (customer_id, full_name, email, phone) VALUES 
(901, 'Sender', 'sender@test.com', '555-1001'),
(902, 'Receiver', 'receiver@test.com', '555-1002');

INSERT INTO public.service_type (service_id, service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES 
(901, 'Standard Test', 10.0, 2.0, 48, 20.0);

INSERT INTO public.package (package_id, tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status) VALUES
(9001, 'TRK-9001', 901, 902, 901, 5.0, 901, 902, 'DELIVERED');

INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES 
(9001, 901, 'REGISTERED', '2026-07-26 10:00:00+00', NULL),
(9001, 901, 'PICKED_UP', '2026-07-26 11:00:00+00', 901),
(9001, 901, 'IN_TRANSIT', '2026-07-26 12:00:00+00', 901),
(9001, 902, 'IN_TRANSIT', '2026-07-26 14:00:00+00', 902),
(9001, 902, 'OUT_FOR_DELIVERY', '2026-07-26 15:00:00+00', 902),
(9001, 902, 'DELIVERED', '2026-07-26 16:00:00+00', 902);

-- 1. F6: Chain of Custody test LAG values
SELECT results_eq(
    $$ SELECT previous_hub_id FROM public.fn_chain_of_custody('TRK-9001') WHERE status_code = 'PICKED_UP' $$,
    $$ VALUES (901::bigint) $$,
    'Previous hub for PICKED_UP is 901'
);

-- 2. F6: First row has null previous values
SELECT results_eq(
    $$ SELECT previous_hub_id FROM public.fn_chain_of_custody('TRK-9001') WHERE status_code = 'REGISTERED' $$,
    $$ VALUES (NULL::bigint) $$,
    'Previous hub for REGISTERED is NULL'
);

-- 3. F7: Hub 901 segment count (3 segments: 10->11, 11->12, 12->14)
SELECT results_eq(
    $$ SELECT segment_count FROM public.fn_inter_scan_hub_analysis() WHERE hub_id = 901 $$,
    $$ VALUES (3::bigint) $$,
    'Hub 901 has 3 segments (time until next event)'
);

-- 4. F7: Hub 902 segment count (2 segments: 14->15, 15->16)
SELECT results_eq(
    $$ SELECT segment_count FROM public.fn_inter_scan_hub_analysis() WHERE hub_id = 902 $$,
    $$ VALUES (2::bigint) $$,
    'Hub 902 has 2 segments'
);

SELECT * FROM finish();
ROLLBACK;
