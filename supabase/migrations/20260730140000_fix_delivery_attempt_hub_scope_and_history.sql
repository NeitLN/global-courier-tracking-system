-- MIGRATION: fix_delivery_attempt_hub_scope_and_history
-- Description: Closes an authorization gap in fn_record_delivery_attempt (a Hub Operator
-- could record a delivery attempt for any driver/package system-wide, not just their own
-- hub) and removes the undocumented auto-insert of a DELIVERED tracking_event, which
-- contradicted docs/DECISION_LOG.md ("creating a DELIVERY_ATTEMPT does not automatically
-- insert a TRACKING_EVENT"). DELIVERED must now be recorded explicitly via
-- fn_record_checkpoint_scan (see ScanForm.tsx DELIVERED option).

CREATE OR REPLACE FUNCTION public.fn_record_delivery_attempt(
    p_tracking_number text,
    p_driver_id bigint,
    p_attempt_time timestamptz,
    p_outcome text,
    p_failure_reason text DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS public.delivery_attempt
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_is_trusted_backend boolean;
    v_package_id bigint;
    v_hub_id bigint;
    v_attempt public.delivery_attempt;
BEGIN
    -- Trusted backend check
    v_is_trusted_backend := (
        auth.role() = 'service_role'
        AND current_setting('role', true) = 'service_role'
    );

    IF NOT v_is_trusted_backend THEN
        IF auth.uid() IS NULL THEN
            RAISE EXCEPTION 'Not authenticated';
        END IF;
        IF NOT authz_private.is_active_user() THEN
            RAISE EXCEPTION 'User profile is not active';
        END IF;
        IF COALESCE(authz_private.current_app_role(), '') <> 'HUB_OPERATOR' THEN
            RAISE EXCEPTION 'Unauthorized: must be HUB_OPERATOR';
        END IF;
        v_hub_id := authz_private.current_staff_hub();
    ELSE
        -- Service role bypasses hub scoping; v_hub_id stays NULL and the check below is skipped.
        v_hub_id := NULL;
    END IF;

    -- Validate outcome values
    IF p_outcome NOT IN ('SUCCESS', 'FAILED') THEN
        RAISE EXCEPTION 'Invalid outcome: must be SUCCESS or FAILED';
    END IF;

    -- Validate failure reason consistency
    IF p_outcome = 'SUCCESS' AND p_failure_reason IS NOT NULL THEN
        RAISE EXCEPTION 'Failure reason must be null for a successful delivery attempt.';
    END IF;
    IF p_outcome = 'FAILED' AND (p_failure_reason IS NULL OR btrim(p_failure_reason) = '') THEN
        RAISE EXCEPTION 'Failure reason is required for a failed delivery attempt.';
    END IF;

    -- Get package_id
    SELECT package_id INTO v_package_id
    FROM public.package
    WHERE tracking_no = p_tracking_number;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tracking number not found: %', p_tracking_number;
    END IF;

    -- Validate driver exists
    IF NOT EXISTS (SELECT 1 FROM public.driver WHERE driver_id = p_driver_id) THEN
        RAISE EXCEPTION 'Driver not found: %', p_driver_id;
    END IF;

    -- Hub Operators may only record attempts for drivers based at their own hub
    -- (same restriction already enforced for reads in fn_get_hub_drivers).
    IF NOT v_is_trusted_backend THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.driver
            WHERE driver_id = p_driver_id AND base_hub_id = v_hub_id
        ) THEN
            RAISE EXCEPTION 'Unauthorized: cannot record a delivery attempt for a driver outside your hub';
        END IF;
    END IF;

    -- Insert delivery attempt
    INSERT INTO public.delivery_attempt (
        package_id, driver_id, attempt_time, outcome, failure_reason, notes
    ) VALUES (
        v_package_id, p_driver_id, p_attempt_time, p_outcome, p_failure_reason, p_notes
    ) RETURNING * INTO v_attempt;

    RETURN v_attempt;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_record_delivery_attempt(text, bigint, timestamptz, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_record_delivery_attempt(text, bigint, timestamptz, text, text, text) TO authenticated, service_role;
