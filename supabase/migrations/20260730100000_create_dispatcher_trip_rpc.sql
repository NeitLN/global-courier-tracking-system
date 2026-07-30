-- MIGRATION: create_dispatcher_trip_rpc
-- Description: Adds fn_create_trip write RPC for Dispatchers to schedule and record network-wide transit trips.

CREATE OR REPLACE FUNCTION public.fn_create_trip(
    p_route_id bigint,
    p_vehicle_id bigint,
    p_driver_id bigint,
    p_depart timestamptz
)
RETURNS public.trip
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_is_trusted_backend boolean;
    v_trip public.trip;
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
    IF p_route_id IS NULL THEN
        RAISE EXCEPTION 'Route ID is required';
    END IF;
    IF p_vehicle_id IS NULL THEN
        RAISE EXCEPTION 'Vehicle ID is required';
    END IF;
    IF p_driver_id IS NULL THEN
        RAISE EXCEPTION 'Driver ID is required';
    END IF;
    IF p_depart IS NULL THEN
        RAISE EXCEPTION 'Departure time is required';
    END IF;

    -- Check if route exists
    IF NOT EXISTS (SELECT 1 FROM public.route WHERE route_id = p_route_id) THEN
        RAISE EXCEPTION 'Route not found: %', p_route_id;
    END IF;

    -- Check if vehicle exists
    IF NOT EXISTS (SELECT 1 FROM public.vehicle WHERE vehicle_id = p_vehicle_id) THEN
        RAISE EXCEPTION 'Vehicle not found: %', p_vehicle_id;
    END IF;

    -- Check if driver exists
    IF NOT EXISTS (SELECT 1 FROM public.driver WHERE driver_id = p_driver_id) THEN
        RAISE EXCEPTION 'Driver not found: %', p_driver_id;
    END IF;

    -- Insert trip and return the row
    INSERT INTO public.trip (
        route_id, vehicle_id, driver_id, depart
    ) VALUES (
        p_route_id, p_vehicle_id, p_driver_id, p_depart
    ) RETURNING * INTO v_trip;

    RETURN v_trip;
END;
$$;

-- Function Privilege configurations
REVOKE EXECUTE ON FUNCTION public.fn_create_trip(bigint, bigint, bigint, timestamptz) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_create_trip(bigint, bigint, bigint, timestamptz) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_create_trip(bigint, bigint, bigint, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_create_trip(bigint, bigint, bigint, timestamptz) TO service_role;
