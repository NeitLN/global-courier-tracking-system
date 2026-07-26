BEGIN;
SELECT plan(1);

-- The status_code reference data should be seeded and present.
SELECT results_eq(
    'SELECT status_code FROM status_code ORDER BY sequence_no',
    $$VALUES ('REGISTERED'), ('PICKED_UP'), ('IN_TRANSIT'), ('OUT_FOR_DELIVERY'), ('DELIVERED'), ('RETURNED')$$,
    'Status codes should be seeded correctly'
);

SELECT * FROM finish();
ROLLBACK;