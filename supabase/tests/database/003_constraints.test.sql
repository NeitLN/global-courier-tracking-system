BEGIN;
SELECT plan(21);

-- We need to setup some basic data to test constraints
INSERT INTO customer (customer_id, full_name, phone, email) VALUES (1, 'Sender', '123', 's@e.com');
INSERT INTO customer (customer_id, full_name, phone, email) VALUES (2, 'Receiver', '456', 'r@e.com');
INSERT INTO transit_hub (hub_id, hub_code, hub_name) VALUES (1, 'H1', 'Hub 1'), (2, 'H2', 'Hub 2');
INSERT INTO service_type (service_id, service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES (1, 'Standard', 10, 2, 48, 100);
INSERT INTO staff (staff_id, full_name, hub_id) VALUES (1, 'Staff 1', 1);
INSERT INTO driver (driver_id, full_name, license_no, phone, base_hub_id) VALUES (1, 'Driver 1', 'L1', 'P1', 1);
INSERT INTO vehicle (vehicle_id, plate_no, vehicle_type, capacity_kg, home_hub_id) VALUES (1, 'V1', 'Truck', 1000, 1);
INSERT INTO route (route_id, origin_hub_id, dest_hub_id, mode, distance_km, planned_hours) VALUES (1, 1, 2, 'ROAD', 100, 2);

-- B. R1: package sender equal to receiver is rejected
PREPARE insert_package_same_sender_receiver AS
INSERT INTO package (tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status)
VALUES ('TRK1', 1, 1, 1, 10, 1, 2, 'REGISTERED');
SELECT throws_ok('insert_package_same_sender_receiver', '23514', NULL, 'package sender equal to receiver should be rejected');

-- C. R2: duplicate tracking number is rejected
INSERT INTO package (package_id, tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status)
VALUES (1, 'TRK2', 1, 2, 1, 10, 1, 2, 'REGISTERED');
PREPARE insert_duplicate_tracking AS
INSERT INTO package (tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status)
VALUES ('TRK2', 1, 2, 1, 10, 1, 2, 'REGISTERED');
SELECT throws_ok('insert_duplicate_tracking', '23505', NULL, 'duplicate tracking number is rejected');

-- D. R4: route origin equals destination is rejected
PREPARE insert_route_same_hubs AS
INSERT INTO route (origin_hub_id, dest_hub_id, mode, distance_km, planned_hours) VALUES (1, 1, 'ROAD', 100, 2);
SELECT throws_ok('insert_route_same_hubs', '23514', NULL, 'route origin equal to destination is rejected');

PREPARE insert_route_duplicate AS
INSERT INTO route (origin_hub_id, dest_hub_id, mode, distance_km, planned_hours) VALUES (1, 2, 'ROAD', 100, 2);
SELECT throws_ok('insert_route_duplicate', '23505', NULL, 'duplicate route origin, destination and mode is rejected');

-- E. R5: duplicate vehicle and depart is rejected; duplicate driver and depart is rejected
INSERT INTO trip (route_id, vehicle_id, driver_id, depart) VALUES (1, 1, 1, '2026-07-26 10:00:00+00');

INSERT INTO driver (driver_id, full_name, license_no, phone, base_hub_id) VALUES (2, 'Driver 2', 'L2', 'P2', 1);
INSERT INTO vehicle (vehicle_id, plate_no, vehicle_type, capacity_kg, home_hub_id) VALUES (2, 'V2', 'Truck', 1000, 1);

PREPARE insert_trip_dup_vehicle AS
INSERT INTO trip (route_id, vehicle_id, driver_id, depart) VALUES (1, 1, 2, '2026-07-26 10:00:00+00');
SELECT throws_ok('insert_trip_dup_vehicle', '23505', NULL, 'duplicate vehicle and depart is rejected');

PREPARE insert_trip_dup_driver AS
INSERT INTO trip (route_id, vehicle_id, driver_id, depart) VALUES (1, 2, 1, '2026-07-26 10:00:00+00');
SELECT throws_ok('insert_trip_dup_driver', '23505', NULL, 'duplicate driver and depart is rejected'); 

-- F. R8: FAILED without reason is rejected; FAILED with blank reason is rejected; SUCCESS with reason is rejected
PREPARE insert_failed_no_reason AS
INSERT INTO delivery_attempt (package_id, driver_id, attempt_time, outcome) VALUES (1, 1, now(), 'FAILED');
SELECT throws_ok('insert_failed_no_reason', '23514', NULL, 'FAILED without reason is rejected');

PREPARE insert_failed_blank_reason AS
INSERT INTO delivery_attempt (package_id, driver_id, attempt_time, outcome, failure_reason) VALUES (1, 1, now(), 'FAILED', '   ');
SELECT throws_ok('insert_failed_blank_reason', '23514', NULL, 'FAILED with blank reason is rejected');

PREPARE insert_success_with_reason AS
INSERT INTO delivery_attempt (package_id, driver_id, attempt_time, outcome, failure_reason) VALUES (1, 1, now(), 'SUCCESS', 'Some reason');
SELECT throws_ok('insert_success_with_reason', '23514', NULL, 'SUCCESS with reason is rejected');

PREPARE insert_valid_failed AS
INSERT INTO delivery_attempt (package_id, driver_id, attempt_time, outcome, failure_reason) VALUES (1, 1, now(), 'FAILED', 'Customer not home');
SELECT lives_ok('insert_valid_failed', 'valid FAILED with reason succeeds');

PREPARE insert_valid_success AS
INSERT INTO delivery_attempt (package_id, driver_id, attempt_time, outcome) VALUES (1, 1, now() + interval '1 day', 'SUCCESS');
SELECT lives_ok('insert_valid_success', 'valid SUCCESS without reason succeeds');

-- G. R10 structural validation
PREPARE insert_zero_weight_package AS
INSERT INTO package (tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status)
VALUES ('TRK3', 1, 2, 1, 0, 1, 2, 'REGISTERED');
SELECT throws_ok('insert_zero_weight_package', '23514', NULL, 'zero package weight is rejected');

PREPARE insert_negative_weight_package AS
INSERT INTO package (tracking_no, sender_id, receiver_id, service_id, weight_kg, origin_hub_id, dest_hub_id, current_status)
VALUES ('TRK4', 1, 2, 1, -1, 1, 2, 'REGISTERED');
SELECT throws_ok('insert_negative_weight_package', '23514', NULL, 'negative package weight is rejected');

PREPARE insert_zero_capacity_vehicle AS
INSERT INTO vehicle (plate_no, vehicle_type, capacity_kg, home_hub_id) VALUES ('V3', 'Truck', 0, 1);
SELECT throws_ok('insert_zero_capacity_vehicle', '23514', NULL, 'zero vehicle capacity is rejected');

PREPARE insert_negative_capacity_vehicle AS
INSERT INTO vehicle (plate_no, vehicle_type, capacity_kg, home_hub_id) VALUES ('V4', 'Truck', -10, 1);
SELECT throws_ok('insert_negative_capacity_vehicle', '23514', NULL, 'negative vehicle capacity is rejected');

PREPARE insert_negative_base_rate AS
INSERT INTO service_type (service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES ('S2', -1, 2, 48, 100);
SELECT throws_ok('insert_negative_base_rate', '23514', NULL, 'negative base rate is rejected');

PREPARE insert_negative_per_kg_rate AS
INSERT INTO service_type (service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES ('S3', 10, -1, 48, 100);
SELECT throws_ok('insert_negative_per_kg_rate', '23514', NULL, 'negative per kg rate is rejected');

PREPARE insert_zero_sla AS
INSERT INTO service_type (service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES ('S4', 10, 2, 0, 100);
SELECT throws_ok('insert_zero_sla', '23514', NULL, 'zero sla hours is rejected');

PREPARE insert_negative_sla AS
INSERT INTO service_type (service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES ('S5', 10, 2, -1, 100);
SELECT throws_ok('insert_negative_sla', '23514', NULL, 'negative sla hours is rejected');

PREPARE insert_zero_max_weight AS
INSERT INTO service_type (service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES ('S6', 10, 2, 48, 0);
SELECT throws_ok('insert_zero_max_weight', '23514', NULL, 'zero max weight is rejected');

PREPARE insert_negative_max_weight AS
INSERT INTO service_type (service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES ('S7', 10, 2, 48, -10);
SELECT throws_ok('insert_negative_max_weight', '23514', NULL, 'negative max weight is rejected');

SELECT * FROM finish();
ROLLBACK;