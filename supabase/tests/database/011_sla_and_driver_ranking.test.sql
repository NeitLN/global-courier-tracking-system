BEGIN;
SELECT plan(4);

-- Fixture
INSERT INTO public.transit_hub (hub_id, hub_code, hub_name) VALUES 
(901, 'TST-01', 'Test Hub 1'),
(902, 'TST-02', 'Test Hub 2');

INSERT INTO public.staff (staff_id, full_name, hub_id) VALUES 
(901, 'Driver 1', 901),
(902, 'Driver 2', 902),
(903, 'Driver 3', 901),
(904, 'Driver 4', 902);

INSERT INTO public.driver (driver_id, full_name, license_no, phone, base_hub_id) VALUES
(901, 'Driver 1', 'LIC901', '555-D901', 901),
(902, 'Driver 2', 'LIC902', '555-D902', 902),
(903, 'Driver 3', 'LIC903', '555-D903', 901),
(904, 'Driver 4', 'LIC904', '555-D904', 902);

INSERT INTO public.customer (customer_id, full_name, email, phone) VALUES 
(901, 'Sender', 'sender@test.com', '555-1001'),
(902, 'Receiver', 'receiver@test.com', '555-1002');

INSERT INTO public.service_type (service_id, service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES 
(901, 'Standard Test', 10.0, 2.0, 48, 20.0);

INSERT INTO public.package (package_id, tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status) VALUES
(9001, 'TRK-9001', 901, 902, 901, 5.0, 901, 902, 'DELIVERED'),
(9002, 'TRK-9002', 901, 902, 901, 5.0, 901, 902, 'DELIVERED'),
(9003, 'TRK-9003', 901, 902, 901, 5.0, 901, 902, 'RETURNED'),
(9004, 'TRK-9004', 901, 902, 901, 5.0, 901, 902, 'REGISTERED');

-- TRK-9001: 24h (SLA MET)
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES 
(9001, 901, 'REGISTERED', '2026-07-26 10:00:00+00', NULL),
(9001, 901, 'PICKED_UP', '2026-07-26 12:00:00+00', NULL),
(9001, 901, 'IN_TRANSIT', '2026-07-26 14:00:00+00', NULL),
(9001, 902, 'OUT_FOR_DELIVERY', '2026-07-27 08:00:00+00', NULL),
(9001, 902, 'DELIVERED', '2026-07-27 10:00:00+00', NULL);

-- TRK-9002: 72h (SLA BREACHED)
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES 
(9002, 901, 'REGISTERED', '2026-07-26 10:00:00+00', NULL),
(9002, 901, 'PICKED_UP', '2026-07-26 12:00:00+00', NULL),
(9002, 901, 'IN_TRANSIT', '2026-07-26 14:00:00+00', NULL),
(9002, 902, 'OUT_FOR_DELIVERY', '2026-07-29 08:00:00+00', NULL),
(9002, 902, 'DELIVERED', '2026-07-29 10:00:00+00', NULL);

-- TRK-9003: RETURNED
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES 
(9003, 901, 'REGISTERED', '2026-07-26 10:00:00+00', NULL),
(9003, 902, 'RETURNED', '2026-07-27 10:00:00+00', NULL);

-- TRK-9004: OPEN
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES 
(9004, 901, 'REGISTERED', now() - interval '1 hour', NULL);

-- Delivery Attempts
INSERT INTO public.delivery_attempt (package_id, driver_id, attempt_time, outcome, failure_reason) VALUES
(9001, 901, '2026-07-27 09:00:00+00', 'FAILED', 'Not home'),
(9001, 901, '2026-07-27 10:00:00+00', 'SUCCESS', NULL),
(9002, 902, '2026-07-29 10:00:00+00', 'SUCCESS', NULL),
(9003, 903, '2026-07-27 09:00:00+00', 'SUCCESS', NULL);

-- 1. F8: SLA Compliance Results
SELECT results_eq(
    $$ SELECT compliance_status FROM public.fn_sla_compliance() ORDER BY tracking_no $$,
    $$ VALUES ('MET'), ('BREACHED'), ('RETURNED'), ('OPEN') $$,
    'SLA accurately computes MET, BREACHED, RETURNED, and OPEN'
);

-- 2. F9: Driver Ranking with ties and zero attempts
SELECT results_eq(
    $$ SELECT driver_id, success_rate, performance_rank FROM public.fn_rank_driver_performance() ORDER BY performance_rank ASC, driver_id ASC $$,
    $$ VALUES (902::bigint, 100.00::numeric, 1::integer), (903::bigint, 100.00::numeric, 1::integer), (901::bigint, 50.00::numeric, 2::integer), (904::bigint, 0.00::numeric, 3::integer) $$,
    'Driver 902 and 903 tie for 1st (100%), Driver 901 is 2nd (50%), Driver 904 is 3rd (0 attempts)'
);

-- 3. F9: Driver totals
SELECT results_eq(
    $$ SELECT total_attempts, successful_attempts, failed_attempts FROM public.fn_rank_driver_performance() WHERE driver_id = 901 $$,
    $$ VALUES (2::bigint, 1::bigint, 1::bigint) $$,
    'Driver 901 totals are correct'
);

-- 4. F9: Driver zero attempts totals
SELECT results_eq(
    $$ SELECT total_attempts, successful_attempts, failed_attempts FROM public.fn_rank_driver_performance() WHERE driver_id = 904 $$,
    $$ VALUES (0::bigint, 0::bigint, 0::bigint) $$,
    'Driver 904 (zero attempts) totals are correct'
);

SELECT * FROM finish();
ROLLBACK;