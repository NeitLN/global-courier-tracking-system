BEGIN;
SELECT plan(1);

-- H. R12: deleting a hub referenced by tracking_event is rejected.
INSERT INTO customer (customer_id, full_name, phone, email) VALUES (1, 'S', '1', 's@e.com'), (2, 'R', '2', 'r@e.com');
INSERT INTO transit_hub (hub_id, hub_code, hub_name) VALUES (1, 'H1', 'Hub 1'), (2, 'H2', 'Hub 2');
INSERT INTO service_type (service_id, service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES (1, 'S1', 10, 2, 48, 100);
INSERT INTO package (package_id, tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status)
VALUES (1, 'TRK1', 1, 2, 1, 10, 1, 2, 'REGISTERED');

INSERT INTO tracking_event (package_id, hub_id, status_code, event_time) VALUES (1, 1, 'REGISTERED', now());

PREPARE delete_hub AS DELETE FROM transit_hub WHERE hub_id = 1;
SELECT throws_ok('delete_hub', '23503', NULL, 'deleting a hub referenced by tracking history is rejected');

SELECT * FROM finish();
ROLLBACK;