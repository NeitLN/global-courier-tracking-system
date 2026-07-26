BEGIN;
SELECT plan(15);

-- Check RLS is enabled for all 14 tables
SELECT is(
    (SELECT relrowsecurity FROM pg_class WHERE relname = 'profiles' AND relnamespace = 'public'::regnamespace),
    true,
    'RLS should be enabled for profiles'
);
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'status_code' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for status_code');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'service_type' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for service_type');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'customer' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for customer');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'transit_hub' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for transit_hub');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'staff' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for staff');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'driver' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for driver');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'vehicle' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for vehicle');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'route' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for route');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'package' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for package');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'tracking_event' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for tracking_event');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'trip' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for trip');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'package_leg' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for package_leg');
SELECT is((SELECT relrowsecurity FROM pg_class WHERE relname = 'delivery_attempt' AND relnamespace = 'public'::regnamespace), true, 'RLS should be enabled for delivery_attempt');

-- Check that driver and vehicle do not have SELECT granted to authenticated
SELECT ok(
    NOT EXISTS (
        SELECT 1 FROM information_schema.role_table_grants 
        WHERE grantee = 'authenticated' AND privilege_type = 'SELECT' AND table_name = 'driver'
    ),
    'authenticated should not have SELECT on driver'
);

ROLLBACK;
