-- MIGRATION: create_delivery_attempt_rpc
-- Description: Adds fn_record_delivery_attempt write RPC for Hub Operators.

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
    v_staff_id bigint;
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
        v_staff_id := authz_private.current_staff_id();
        v_hub_id := authz_private.current_staff_hub();
    ELSE
        -- Service role can optionally supply recorded_by / hub context or resolve it
        v_staff_id := NULL;
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

    -- Insert delivery attempt
    INSERT INTO public.delivery_attempt (
        package_id, driver_id, attempt_time, outcome, failure_reason, notes
    ) VALUES (
        v_package_id, p_driver_id, p_attempt_time, p_outcome, p_failure_reason, p_notes
    ) RETURNING * INTO v_attempt;

    -- If successful, record explicit 'DELIVERED' tracking event
    IF p_outcome = 'SUCCESS' THEN
        IF v_hub_id IS NULL THEN
            -- In service_role context, get the package's destination hub as a fallback
            SELECT dest_hub_id INTO v_hub_id
            FROM public.package
            WHERE package_id = v_package_id;
        END IF;

        INSERT INTO public.tracking_event (
            package_id, hub_id, status_code, event_time, recorded_by
        ) VALUES (
            v_package_id, v_hub_id, 'DELIVERED', p_attempt_time, v_staff_id
        );
    END IF;

    RETURN v_attempt;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_record_delivery_attempt(text, bigint, timestamptz, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_record_delivery_attempt(text, bigint, timestamptz, text, text, text) TO authenticated, service_role;
