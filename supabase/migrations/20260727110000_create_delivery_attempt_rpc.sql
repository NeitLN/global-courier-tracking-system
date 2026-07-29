-- MIGRATION: create_delivery_attempt_rpc
-- Description: Adds fn_record_delivery_attempt write RPC, fn_get_hub_drivers, and fn_get_hub_delivery_attempts read RPCs for Hub Operators.

-- 1. Ensure public.delivery_attempt has the notes column
ALTER TABLE public.delivery_attempt ADD COLUMN IF NOT EXISTS notes text;

-- 2. Create the delivery attempt recording RPC
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


-- 3. Create fn_get_hub_drivers (SECURITY DEFINER read RPC)
CREATE OR REPLACE FUNCTION public.fn_get_hub_drivers(
    p_hub_id bigint
)
RETURNS TABLE (
    driver_id bigint,
    full_name text,
    license_no text
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
    v_is_trusted_backend boolean;
    v_role text;
BEGIN
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
        v_role := COALESCE(authz_private.current_app_role(), '');
        IF v_role NOT IN ('HUB_OPERATOR', 'DISPATCHER') THEN
            RAISE EXCEPTION 'Unauthorized: must be HUB_OPERATOR or DISPATCHER';
        END IF;
        IF v_role = 'HUB_OPERATOR' AND p_hub_id <> authz_private.current_staff_hub() THEN
            RAISE EXCEPTION 'Unauthorized: cannot view drivers for another hub';
        END IF;
    END IF;

    RETURN QUERY
    SELECT d.driver_id, d.full_name, d.license_no
    FROM public.driver d
    WHERE d.base_hub_id = p_hub_id
    ORDER BY d.full_name;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_get_hub_drivers(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_get_hub_drivers(bigint) TO authenticated, service_role;


-- 4. Create fn_get_hub_delivery_attempts (SECURITY DEFINER read RPC)
CREATE OR REPLACE FUNCTION public.fn_get_hub_delivery_attempts(
    p_hub_id bigint,
    p_limit integer DEFAULT 50
)
RETURNS TABLE (
    delivery_attempt_id bigint,
    attempt_time timestamptz,
    outcome text,
    failure_reason text,
    notes text,
    tracking_no text,
    driver_name text,
    driver_license text
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
    v_is_trusted_backend boolean;
    v_role text;
BEGIN
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
        v_role := COALESCE(authz_private.current_app_role(), '');
        IF v_role NOT IN ('HUB_OPERATOR', 'DISPATCHER') THEN
            RAISE EXCEPTION 'Unauthorized: must be HUB_OPERATOR or DISPATCHER';
        END IF;
        IF v_role = 'HUB_OPERATOR' AND p_hub_id <> authz_private.current_staff_hub() THEN
            RAISE EXCEPTION 'Unauthorized: cannot view delivery attempts for another hub';
        END IF;
    END IF;

    RETURN QUERY
    SELECT 
        da.attempt_id AS delivery_attempt_id,
        da.attempt_time,
        da.outcome,
        da.failure_reason,
        da.notes,
        p.tracking_no,
        d.full_name AS driver_name,
        d.license_no AS driver_license
    FROM public.delivery_attempt da
    JOIN public.package p ON da.package_id = p.package_id
    JOIN public.driver d ON da.driver_id = d.driver_id
    WHERE d.base_hub_id = p_hub_id
    ORDER BY da.attempt_time DESC
    LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_get_hub_delivery_attempts(bigint, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_get_hub_delivery_attempts(bigint, integer) TO authenticated, service_role;
