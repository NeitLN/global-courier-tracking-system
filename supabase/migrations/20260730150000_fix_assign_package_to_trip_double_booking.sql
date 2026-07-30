-- MIGRATION: fix_assign_package_to_trip_double_booking
-- Description: Closes a TOCTOU race and a missing cross-trip check in
-- fn_assign_package_to_trip that allowed the same package to be assigned onto more than
-- one trip at a time. The original migration only rejected a duplicate assignment on the
-- SAME trip; it never checked whether the package already had an active leg
-- (unloaded_at IS NULL) on a DIFFERENT trip, and performed no row lock, so two concurrent
-- dispatcher calls could both pass the check before either inserted.

CREATE OR REPLACE FUNCTION public.fn_assign_package_to_trip(
    p_trip_id bigint,
    p_package_id bigint
)
RETURNS public.package_leg
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_is_trusted_backend boolean;
    v_route_id bigint;
    v_origin_hub_id bigint;
    v_current_hub_id bigint;
    v_latest_status text;
    v_leg public.package_leg;
BEGIN
    -- Trusted backend check: Require both service_role JWT claim and PostgreSQL role.
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
        IF COALESCE(authz_private.current_app_role(), '') <> 'DISPATCHER' THEN
            RAISE EXCEPTION 'Unauthorized: must be DISPATCHER';
        END IF;
    END IF;

    -- Validate input parameters
    IF p_trip_id IS NULL THEN
        RAISE EXCEPTION 'Trip ID is required';
    END IF;
    IF p_package_id IS NULL THEN
        RAISE EXCEPTION 'Package ID is required';
    END IF;

    -- Validate trip exists
    SELECT route_id INTO v_route_id FROM public.trip WHERE trip_id = p_trip_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trip not found: %', p_trip_id;
    END IF;

    -- Validate package exists
    IF NOT EXISTS (SELECT 1 FROM public.package WHERE package_id = p_package_id) THEN
        RAISE EXCEPTION 'Package not found: %', p_package_id;
    END IF;

    -- Lock the package row to serialize concurrent assignment attempts for the same
    -- package and prevent a check-then-insert race (mirrors fn_validate_tracking_status).
    PERFORM 1 FROM public.package WHERE package_id = p_package_id FOR UPDATE;

    -- Prevent duplicate assignment on the same trip
    IF EXISTS (SELECT 1 FROM public.package_leg WHERE trip_id = p_trip_id AND package_id = p_package_id) THEN
        RAISE EXCEPTION 'Package % is already assigned to trip %', p_package_id, p_trip_id;
    END IF;

    -- Prevent assigning a package that already has an active (not yet unloaded) leg on
    -- any other trip.
    IF EXISTS (
        SELECT 1 FROM public.package_leg
        WHERE package_id = p_package_id AND unloaded_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Package % is already assigned to an active trip', p_package_id;
    END IF;

    -- Check if package is in terminal status
    SELECT current_status INTO v_latest_status FROM public.package WHERE package_id = p_package_id;
    IF v_latest_status IN ('DELIVERED', 'RETURNED') THEN
        RAISE EXCEPTION 'Cannot assign package with terminal status: %', v_latest_status;
    END IF;

    -- Determine package's current location (latest tracking event hub, fallback to origin_hub_id)
    SELECT hub_id, status_code INTO v_current_hub_id, v_latest_status
    FROM public.tracking_event
    WHERE package_id = p_package_id
    ORDER BY event_time DESC, event_id DESC
    LIMIT 1;

    IF v_current_hub_id IS NULL THEN
        SELECT origin_hub_id INTO v_current_hub_id FROM public.package WHERE package_id = p_package_id;
    END IF;

    -- Get trip route origin hub
    SELECT origin_hub_id INTO v_origin_hub_id FROM public.route WHERE route_id = v_route_id;

    -- Validate location compatibility (package must be at the trip route's origin hub to be loaded)
    IF v_current_hub_id <> v_origin_hub_id THEN
        RAISE EXCEPTION 'Package is located at hub %, but trip route origin is hub %', v_current_hub_id, v_origin_hub_id;
    END IF;

    -- Insert package leg
    INSERT INTO public.package_leg (
        trip_id, package_id, loaded_at, unloaded_at
    ) VALUES (
        p_trip_id, p_package_id, NULL, NULL
    ) RETURNING * INTO v_leg;

    RETURN v_leg;
END;
$$;

-- Function Privilege configurations
REVOKE EXECUTE ON FUNCTION public.fn_assign_package_to_trip(bigint, bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_assign_package_to_trip(bigint, bigint) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_assign_package_to_trip(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_assign_package_to_trip(bigint, bigint) TO service_role;
