BEGIN;
SELECT plan(1);

-- Fixture
INSERT INTO public.transit_hub (hub_id, hub_code, hub_name) VALUES 
(901, 'TST-01', 'Test Hub 1'),
(902, 'TST-02', 'Test Hub 2');

INSERT INTO public.customer (customer_id, full_name, email, phone) VALUES 
(901, 'Sender', 'sender@test.com', '555-1001'),
(902, 'Receiver', 'receiver@test.com', '555-1002');

INSERT INTO public.service_type (service_id, service_name, base_rate, per_kg_rate, sla_hours, max_weight_kg) VALUES 
(901, 'Standard Test', 10.0, 2.0, 48, 20.0);

-- F1 package registration atomicity
-- Try to register with an invalid hub (999) which should fail foreign key constraint.
-- Verify that NO package is created and NO event is created.
-- In pgTAP, since functions run in one transaction, a raised exception rolls back the savepoint.
PREPARE test_atomicity AS
SELECT public.fn_register_package(901, 902, 901, 5.0, 10, 10, 10, 901, 999);
SELECT throws_ok('test_atomicity', 'Destination hub not found: 999', 'F1 fails atomically without partial commit');

-- Concurrency note:
-- The public.fn_validate_tracking_status() trigger uses `PERFORM 1 FROM public.package WHERE package_id = NEW.package_id FOR NO KEY UPDATE;`
-- This acquires a row-level lock on the package, forcing any concurrent inserts for the SAME package to serialize.
-- Once the first transaction commits, the second one wakes up, reads the strictly latest event time, and validates R6 against it.

SELECT * FROM finish();
ROLLBACK;
