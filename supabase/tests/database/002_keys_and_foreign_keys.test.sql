BEGIN;
SELECT plan(50);

-- Primary Keys
SELECT has_pk('status_code', 'status_code has primary key');
SELECT has_pk('service_type', 'service_type has primary key');
SELECT has_pk('customer', 'customer has primary key');
SELECT has_pk('transit_hub', 'transit_hub has primary key');
SELECT has_pk('staff', 'staff has primary key');
SELECT has_pk('driver', 'driver has primary key');
SELECT has_pk('vehicle', 'vehicle has primary key');
SELECT has_pk('route', 'route has primary key');
SELECT has_pk('package', 'package has primary key');
SELECT has_pk('tracking_event', 'tracking_event has primary key');
SELECT has_pk('trip', 'trip has primary key');
SELECT has_pk('package_leg', 'package_leg has primary key');
SELECT has_pk('delivery_attempt', 'delivery_attempt has primary key');

-- Alternate Keys (Unique constraints)
SELECT col_is_unique('status_code', 'status_name', 'status_code has unique status_name');
SELECT col_is_unique('status_code', 'sequence_no', 'status_code has unique sequence_no');
SELECT col_is_unique('service_type', 'service_name', 'service_type has unique service_name');
SELECT col_is_unique('customer', 'phone', 'customer has unique phone');
SELECT col_is_unique('customer', 'email', 'customer has unique email');
SELECT col_is_unique('transit_hub', 'hub_code', 'transit_hub has unique hub_code');
SELECT col_is_unique('driver', 'license_no', 'driver has unique license_no');
SELECT col_is_unique('driver', 'phone', 'driver has unique phone');
SELECT col_is_unique('vehicle', 'plate_no', 'vehicle has unique plate_no');
SELECT col_is_unique('route', ARRAY['origin_hub_id', 'dest_hub_id', 'mode'], 'route has unique origin, dest, mode');
SELECT col_is_unique('package', 'tracking_no', 'package has unique tracking_no');
SELECT col_is_unique('tracking_event', ARRAY['package_id', 'event_time'], 'tracking_event has unique package_id, event_time');
SELECT col_is_unique('trip', ARRAY['vehicle_id', 'depart'], 'trip has unique vehicle, depart');
SELECT col_is_unique('trip', ARRAY['driver_id', 'depart'], 'trip has unique driver, depart');
SELECT col_is_unique('delivery_attempt', ARRAY['package_id', 'attempt_time'], 'delivery_attempt has unique package_id, attempt_time');

-- Specific Foreign Key Assertions (22 relationships)
SELECT fk_ok('public', 'staff', 'hub_id', 'public', 'transit_hub', 'hub_id');
SELECT fk_ok('public', 'driver', 'base_hub_id', 'public', 'transit_hub', 'hub_id');
SELECT fk_ok('public', 'vehicle', 'home_hub_id', 'public', 'transit_hub', 'hub_id');
SELECT fk_ok('public', 'route', 'origin_hub_id', 'public', 'transit_hub', 'hub_id');
SELECT fk_ok('public', 'route', 'dest_hub_id', 'public', 'transit_hub', 'hub_id');
SELECT fk_ok('public', 'package', 'sender_id', 'public', 'customer', 'customer_id');
SELECT fk_ok('public', 'package', 'receiver_id', 'public', 'customer', 'customer_id');
SELECT fk_ok('public', 'package', 'service_id', 'public', 'service_type', 'service_id');
SELECT fk_ok('public', 'package', 'origin_hub_id', 'public', 'transit_hub', 'hub_id');
SELECT fk_ok('public', 'package', 'dest_hub_id', 'public', 'transit_hub', 'hub_id');
SELECT fk_ok('public', 'package', 'current_status', 'public', 'status_code', 'status_code');
SELECT fk_ok('public', 'tracking_event', 'package_id', 'public', 'package', 'package_id');
SELECT fk_ok('public', 'tracking_event', 'hub_id', 'public', 'transit_hub', 'hub_id');
SELECT fk_ok('public', 'tracking_event', 'status_code', 'public', 'status_code', 'status_code');
SELECT fk_ok('public', 'tracking_event', 'recorded_by', 'public', 'staff', 'staff_id');
SELECT fk_ok('public', 'trip', 'route_id', 'public', 'route', 'route_id');
SELECT fk_ok('public', 'trip', 'vehicle_id', 'public', 'vehicle', 'vehicle_id');
SELECT fk_ok('public', 'trip', 'driver_id', 'public', 'driver', 'driver_id');
SELECT fk_ok('public', 'package_leg', 'trip_id', 'public', 'trip', 'trip_id');
SELECT fk_ok('public', 'package_leg', 'package_id', 'public', 'package', 'package_id');
SELECT fk_ok('public', 'delivery_attempt', 'package_id', 'public', 'package', 'package_id');
SELECT fk_ok('public', 'delivery_attempt', 'driver_id', 'public', 'driver', 'driver_id');

SELECT * FROM finish();
ROLLBACK;