BEGIN;
SELECT plan(13);

INSERT INTO public.transit_hub (hub_code, hub_name) VALUES ('P78-A', 'Phase 78 A'), ('P78-B', 'Phase 78 B');
INSERT INTO public.service_type (service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES ('Phase 78 Service', 10, 2, 24, 20);
INSERT INTO public.customer (full_name, phone, email) VALUES
  ('Phase Sender', 'P78001', 'phase-sender@example.com'),
  ('Phase Receiver', 'P78002', 'phase-receiver@example.com'),
  ('Phase Other', 'P78003', 'phase-other@example.com');
INSERT INTO auth.users (id, email) VALUES ('78787878-7878-7878-7878-787878787878', 'phase-sender@example.com');
UPDATE public.profiles
SET app_role = 'CUSTOMER',
    customer_id = (SELECT customer_id FROM public.customer WHERE email = 'phase-sender@example.com')
WHERE user_id = '78787878-7878-7878-7878-787878787878';

SELECT set_config('test.p78_service', (SELECT service_id::text FROM public.service_type WHERE service_name = 'Phase 78 Service'), true);
SELECT set_config('test.p78_hub_a', (SELECT hub_id::text FROM public.transit_hub WHERE hub_code = 'P78-A'), true);
SELECT set_config('test.p78_hub_b', (SELECT hub_id::text FROM public.transit_hub WHERE hub_code = 'P78-B'), true);
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '78787878-7878-7878-7878-787878787878', 'role', 'authenticated')::text, true);

SET LOCAL ROLE authenticated;

SELECT lives_ok(format(
  'SELECT public.fn_register_package_by_receiver_email(%L, %s, 2, 10, 10, 10, %s, %s)',
  'phase-receiver@example.com',
  current_setting('test.p78_service'),
  current_setting('test.p78_hub_a'),
  current_setting('test.p78_hub_b')
), 'Customer can register a valid package using an exact receiver email');

SELECT is((SELECT count(*)::int FROM public.package), 1, 'Exactly one customer-scoped package was inserted');
SELECT is((SELECT count(*)::int FROM public.tracking_event WHERE status_code = 'REGISTERED'), 1, 'REGISTERED event was inserted atomically');
SELECT is((SELECT shipping_fee FROM public.package LIMIT 1), 14.00::numeric, 'Shipping fee is calculated by the database');
SELECT is((public.fn_customer_dashboard_summary()->>'active_shipments')::int, 1, 'Customer dashboard summary counts the active shipment');
SELECT is((public.fn_customer_dashboard_summary()->>'delivered_shipments')::int, 0, 'Customer dashboard summary handles zero delivered shipments');

SELECT throws_ok(format(
  'SELECT public.fn_register_package_by_receiver_email(%L, %s, 2, NULL, NULL, NULL, %s, %s)',
  'phase-sender@example.com',
  current_setting('test.p78_service'),
  current_setting('test.p78_hub_a'),
  current_setting('test.p78_hub_b')
), NULL, NULL, 'Sender cannot register a package to themselves');

SELECT throws_ok(format(
  'SELECT public.fn_register_package_by_receiver_email(%L, %s, 2, NULL, NULL, NULL, %s, %s)',
  'missing@example.com',
  current_setting('test.p78_service'),
  current_setting('test.p78_hub_a'),
  current_setting('test.p78_hub_b')
), NULL, NULL, 'Unknown receiver email is rejected without exposing a directory');

SELECT set_config('test.p78_tracking', (SELECT tracking_no FROM public.package LIMIT 1), true);

RESET ROLE;
SET LOCAL ROLE anon;

SELECT lives_ok(
  format('SELECT public.fn_public_track_package(%L)', current_setting('test.p78_tracking')),
  'Anonymous user can call the public-safe tracking RPC'
);
SELECT ok(
  NOT (public.fn_public_track_package(current_setting('test.p78_tracking')) ? 'sender_id'),
  'Public tracking output excludes sender ID'
);
SELECT ok(
  NOT (public.fn_public_track_package(current_setting('test.p78_tracking')) ? 'receiver_id'),
  'Public tracking output excludes receiver ID'
);
SELECT ok(
  NOT ((public.fn_public_track_package(current_setting('test.p78_tracking'))->'timeline'->0) ? 'recorded_by'),
  'Public timeline excludes internal recorded-by staff identifiers'
);
SELECT throws_ok(
  $$ SELECT public.fn_register_package_by_receiver_email('phase-receiver@example.com', 1, 1, NULL, NULL, NULL, 1, 2); $$,
  '42501',
  NULL,
  'Anonymous user cannot execute the registration wrapper'
);

ROLLBACK;
