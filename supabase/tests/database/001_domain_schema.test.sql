BEGIN;
SELECT plan(15);

-- Test B: Authentication support tables
SELECT has_table('public', 'profiles', 'public.profiles is an authentication-support table.');

-- Test A: exactly 13 approved domain tables exist in public (excluding auth-support profiles)
SELECT set_eq(
    $$
        SELECT table_name::text
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE'
          AND table_name <> 'profiles'
    $$,
    ARRAY[
        'status_code',
        'service_type',
        'customer',
        'transit_hub',
        'staff',
        'driver',
        'vehicle',
        'route',
        'package',
        'tracking_event',
        'trip',
        'package_leg',
        'delivery_attempt'
    ],
    'Exactly 13 domain tables should exist in public schema (excluding auth-support profiles)'
);

SELECT has_table('public', 'status_code', 'Table status_code should exist');
SELECT has_table('public', 'service_type', 'Table service_type should exist');
SELECT has_table('public', 'customer', 'Table customer should exist');
SELECT has_table('public', 'transit_hub', 'Table transit_hub should exist');
SELECT has_table('public', 'staff', 'Table staff should exist');
SELECT has_table('public', 'driver', 'Table driver should exist');
SELECT has_table('public', 'vehicle', 'Table vehicle should exist');
SELECT has_table('public', 'route', 'Table route should exist');
SELECT has_table('public', 'package', 'Table package should exist');
SELECT has_table('public', 'tracking_event', 'Table tracking_event should exist');
SELECT has_table('public', 'trip', 'Table trip should exist');
SELECT has_table('public', 'package_leg', 'Table package_leg should exist');
SELECT has_table('public', 'delivery_attempt', 'Table delivery_attempt should exist');

SELECT * FROM finish();
ROLLBACK;