BEGIN;
SELECT plan(14);

-- 1. Setup reference and domain data
INSERT INTO public.transit_hub (hub_code, hub_name) VALUES ('P9-H1', 'Phase 9 Hub 1');
INSERT INTO public.service_type (service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES ('Phase 9 Service', 15, 3, 24, 25);
INSERT INTO public.customer (full_name, phone, email) VALUES
  ('Phase 9 Sender', 'P9-S001', 'p9-sender@example.com'),
  ('Phase 9 Receiver', 'P9-R002', 'p9-receiver@example.com');

INSERT INTO public.staff (full_name, hub_id) VALUES
  ('Phase 9 Operator', (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'P9-H1'));

INSERT INTO public.driver (full_name, license_no, phone, base_hub_id) VALUES
  ('Phase 9 Driver', 'P9-LIC001', 'P9-PH001', (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'P9-H1'));

INSERT INTO public.package (tracking_no, sender_id, receiver_id, service_id, origin_hub_id, dest_hub_id, weight_kg, shipping_fee, current_status) VALUES
  ('P9-TRACK001',
   (SELECT customer_id FROM public.customer WHERE email = 'p9-sender@example.com'),
   (SELECT customer_id FROM public.customer WHERE email = 'p9-receiver@example.com'),
   (SELECT service_id FROM public.service_type WHERE service_name = 'Phase 9 Service'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'P9-H1'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'P9-H1'),
   5, 30.00, 'REGISTERED');

-- Insert initial REGISTERED, PICKED_UP, IN_TRANSIT, and OUT_FOR_DELIVERY events to set up package status
INSERT INTO public.tracking_event (package_id, hub_id, status_code, event_time, recorded_by) VALUES
  ((SELECT package_id FROM public.package WHERE tracking_no = 'P9-TRACK001'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'P9-H1'),
   'REGISTERED', now() - interval '2 hours', NULL),
  ((SELECT package_id FROM public.package WHERE tracking_no = 'P9-TRACK001'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'P9-H1'),
   'PICKED_UP', now() - interval '1 hour 45 minutes', (SELECT staff_id FROM public.staff WHERE full_name = 'Phase 9 Operator')),
  ((SELECT package_id FROM public.package WHERE tracking_no = 'P9-TRACK001'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'P9-H1'),
   'IN_TRANSIT', now() - interval '1 hour 30 minutes', (SELECT staff_id FROM public.staff WHERE full_name = 'Phase 9 Operator')),
  ((SELECT package_id FROM public.package WHERE tracking_no = 'P9-TRACK001'),
   (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'P9-H1'),
   'OUT_FOR_DELIVERY', now() - interval '1 hour', (SELECT staff_id FROM public.staff WHERE full_name = 'Phase 9 Operator'));

-- 2. Setup auth context for HUB_OPERATOR
INSERT INTO auth.users (id, email) VALUES ('99999999-9999-9999-9999-999999999999', 'p9-operator@example.com');
UPDATE public.profiles
SET app_role = 'HUB_OPERATOR',
    staff_id = (SELECT staff_id FROM public.staff WHERE full_name = 'Phase 9 Operator')
WHERE user_id = '99999999-9999-9999-9999-999999999999';

SELECT set_config('test.p9_driver_id', (SELECT driver_id::text FROM public.driver WHERE license_no = 'P9-LIC001'), true);
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '99999999-9999-9999-9999-999999999999', 'role', 'authenticated')::text, true);

SET LOCAL ROLE authenticated;

-- Test 1: Valid failed delivery attempt (requires failure reason)
SELECT lives_ok(format(
  'SELECT public.fn_record_delivery_attempt(%L, %s, now(), %L, %L, %L)',
  'P9-TRACK001',
  current_setting('test.p9_driver_id'),
  'FAILED',
  'Customer was not home',
  'Left a delivery attempt notice card.'
), 'Hub Operator can record a failed delivery attempt with failure reason');

RESET ROLE;

-- Test 2: Verify the failed delivery attempt exists
SELECT is((
  SELECT count(*)::int
  FROM public.delivery_attempt da
  JOIN public.package p ON da.package_id = p.package_id
  WHERE p.tracking_no = 'P9-TRACK001' AND da.outcome = 'FAILED'
), 1, 'Failed delivery attempt was inserted correctly');

SET LOCAL ROLE authenticated;

-- Test 3: Failed attempt without failure reason should fail
SELECT throws_ok(format(
  'SELECT public.fn_record_delivery_attempt(%L, %s, now(), %L, NULL, %L)',
  'P9-TRACK001',
  current_setting('test.p9_driver_id'),
  'FAILED',
  'Some notes'
), NULL, NULL, 'Cannot record a failed delivery attempt without a failure reason');

-- Test 4: Successful attempt with failure reason should fail
SELECT throws_ok(format(
  'SELECT public.fn_record_delivery_attempt(%L, %s, now(), %L, %L, %L)',
  'P9-TRACK001',
  current_setting('test.p9_driver_id'),
  'SUCCESS',
  'No reason',
  'Some notes'
), NULL, NULL, 'Cannot record a successful delivery attempt with a failure reason');

-- Test 5: Valid successful delivery attempt (failure reason must be null)
SELECT lives_ok(format(
  'SELECT public.fn_record_delivery_attempt(%L, %s, now() + interval %L, %L, NULL, %L)',
  'P9-TRACK001',
  current_setting('test.p9_driver_id'),
  '1 minute',
  'SUCCESS',
  'Delivered to front door.'
), 'Hub Operator can record a successful delivery attempt with null failure reason');

RESET ROLE;

-- Test 6: Verify successful delivery attempt exists
SELECT is((
  SELECT count(*)::int
  FROM public.delivery_attempt da
  JOIN public.package p ON da.package_id = p.package_id
  WHERE p.tracking_no = 'P9-TRACK001' AND da.outcome = 'SUCCESS'
), 1, 'Successful delivery attempt was inserted correctly');

-- Test 7: A successful delivery attempt must NOT automatically create a tracking_event.
-- DELIVERED must be recorded explicitly via fn_record_checkpoint_scan (see DECISION_LOG.md).
SELECT is((
  SELECT count(*)::int
  FROM public.tracking_event te
  JOIN public.package p ON te.package_id = p.package_id
  WHERE p.tracking_no = 'P9-TRACK001' AND te.status_code = 'DELIVERED'
), 0, 'Successful delivery attempt does not implicitly insert a DELIVERED tracking event');

-- Test 8: Non-Hub Operator user should be rejected
RESET ROLE;
INSERT INTO public.customer (full_name, phone, email) VALUES ('Phase 9 Cust', 'P9-C001', 'p9-customer@example.com');
INSERT INTO auth.users (id, email) VALUES ('88888888-8888-8888-8888-888888888888', 'p9-customer@example.com');
UPDATE public.profiles
SET app_role = 'CUSTOMER',
    customer_id = (SELECT customer_id FROM public.customer WHERE email = 'p9-customer@example.com')
WHERE user_id = '88888888-8888-8888-8888-888888888888';

SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '88888888-8888-8888-8888-888888888888', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

SELECT throws_ok(format(
  'SELECT public.fn_record_delivery_attempt(%L, %s, now(), %L, NULL, %L)',
  'P9-TRACK001',
  current_setting('test.p9_driver_id'),
  'SUCCESS',
  'Delivered'
), NULL, NULL, 'CUSTOMER role cannot record a delivery attempt');

-- Test 9: Anonymous role should be rejected
RESET ROLE;
SET LOCAL ROLE anon;
SELECT throws_ok(format(
  'SELECT public.fn_record_delivery_attempt(%L, %s, now(), %L, NULL, %L)',
  'P9-TRACK001',
  current_setting('test.p9_driver_id'),
  'SUCCESS',
  'Delivered'
), NULL, NULL, 'Anon role cannot record a delivery attempt');

-- Test 10: Tracking events are immutable (no updates/deletes)
RESET ROLE;
SELECT throws_ok(
  'UPDATE public.tracking_event SET status_code = ''PICKED_UP'' WHERE status_code = ''OUT_FOR_DELIVERY''',
  NULL,
  NULL,
  'Cannot update tracking events as they are append-only'
);

-- Test 11: Active HUB_OPERATOR can call fn_get_hub_drivers for their assigned hub
RESET ROLE;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '99999999-9999-9999-9999-999999999999', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

SELECT lives_ok(format(
  'SELECT * FROM public.fn_get_hub_drivers(%s)',
  (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'P9-H1')
), 'Hub Operator can retrieve drivers for their own hub');

-- Test 12: HUB_OPERATOR cannot call fn_get_hub_drivers for a different hub
SELECT throws_ok(
  'SELECT * FROM public.fn_get_hub_drivers(999999)',
  NULL,
  'Unauthorized: cannot view drivers for another hub',
  'Hub Operator cannot retrieve drivers for another hub'
);

-- Test 13: Active HUB_OPERATOR can call fn_get_hub_delivery_attempts for their assigned hub
SELECT lives_ok(format(
  'SELECT * FROM public.fn_get_hub_delivery_attempts(%s)',
  (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'P9-H1')
), 'Hub Operator can retrieve delivery attempts for their own hub');

-- Test 14: HUB_OPERATOR cannot record a delivery attempt for a driver based at another hub
RESET ROLE;
INSERT INTO public.transit_hub (hub_code, hub_name) VALUES ('P9-H2', 'Phase 9 Hub 2');
INSERT INTO public.driver (full_name, license_no, phone, base_hub_id) VALUES
  ('Phase 9 Other-Hub Driver', 'P9-LIC002', 'P9-PH002', (SELECT hub_id FROM public.transit_hub WHERE hub_code = 'P9-H2'));

-- Capture the driver_id while still superuser: the "driver" table is denied to
-- "authenticated" (see RLS_AUTHORIZATION.md), so this must not be re-queried after
-- switching role below.
SELECT set_config('test.p9_other_hub_driver_id', (SELECT driver_id::text FROM public.driver WHERE license_no = 'P9-LIC002'), true);

SELECT set_config('request.jwt.claims', jsonb_build_object('sub', '99999999-9999-9999-9999-999999999999', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;

SELECT throws_ok(format(
  'SELECT public.fn_record_delivery_attempt(%L, %s, now(), %L, %L, %L)',
  'P9-TRACK001',
  current_setting('test.p9_other_hub_driver_id'),
  'FAILED',
  'Customer was not home',
  'Attempt using a driver from another hub'
), NULL, NULL, 'Hub Operator cannot record a delivery attempt for a driver outside their hub');

SELECT * FROM finish();
ROLLBACK;
