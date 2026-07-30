-- MIGRATION: create_dispatcher_read_rpcs
-- Description: Adds secure read RPCs for Dispatchers to safely list routes, drivers, vehicles, trips, and unassigned packages without violating RLS/PII.

-- 1. fn_get_dispatcher_drivers
CREATE OR REPLACE FUNCTION public.fn_get_dispatcher_drivers()
RETURNS TABLE (
    driver_id bigint,
    full_name text,
    base_hub_id bigint,
    base_hub_code text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Authorization check
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT authz_private.is_active_user() THEN
        RAISE EXCEPTION 'User profile is not active';
    END IF;
    IF COALESCE(authz_private.current_app_role(), '') <> 'DISPATCHER' THEN
        RAISE EXCEPTION 'Unauthorized: must be DISPATCHER';
    END IF;

    RETURN QUERY
    SELECT d.driver_id, d.full_name, d.base_hub_id, h.hub_code
    FROM public.driver d
    JOIN public.transit_hub h ON d.base_hub_id = h.hub_id
    ORDER BY d.full_name ASC;
END;
$$;

-- 2. fn_get_dispatcher_vehicles
CREATE OR REPLACE FUNCTION public.fn_get_dispatcher_vehicles()
RETURNS TABLE (
    vehicle_id bigint,
    plate_no text,
    vehicle_type text,
    home_hub_id bigint,
    home_hub_code text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Authorization check
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT authz_private.is_active_user() THEN
        RAISE EXCEPTION 'User profile is not active';
    END IF;
    IF COALESCE(authz_private.current_app_role(), '') <> 'DISPATCHER' THEN
        RAISE EXCEPTION 'Unauthorized: must be DISPATCHER';
    END IF;

    RETURN QUERY
    SELECT v.vehicle_id, v.plate_no, v.vehicle_type, v.home_hub_id, h.hub_code
    FROM public.vehicle v
    JOIN public.transit_hub h ON v.home_hub_id = h.hub_id
    ORDER BY v.plate_no ASC;
END;
$$;

-- 3. fn_get_dispatcher_trips
CREATE OR REPLACE FUNCTION public.fn_get_dispatcher_trips()
RETURNS TABLE (
    trip_id bigint,
    route_id bigint,
    origin_hub_code text,
    dest_hub_code text,
    mode text,
    driver_name text,
    vehicle_plate text,
    depart timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Authorization check
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT authz_private.is_active_user() THEN
        RAISE EXCEPTION 'User profile is not active';
    END IF;
    IF COALESCE(authz_private.current_app_role(), '') <> 'DISPATCHER' THEN
        RAISE EXCEPTION 'Unauthorized: must be DISPATCHER';
    END IF;

    RETURN QUERY
    SELECT 
        t.trip_id,
        t.route_id,
        h1.hub_code AS origin_hub_code,
        h2.hub_code AS dest_hub_code,
        r.mode,
        d.full_name AS driver_name,
        v.plate_no AS vehicle_plate,
        t.depart
    FROM public.trip t
    JOIN public.route r ON t.route_id = r.route_id
    JOIN public.transit_hub h1 ON r.origin_hub_id = h1.hub_id
    JOIN public.transit_hub h2 ON r.dest_hub_id = h2.hub_id
    JOIN public.driver d ON t.driver_id = d.driver_id
    JOIN public.vehicle v ON t.vehicle_id = v.vehicle_id
    ORDER BY t.depart DESC;
END;
$$;

-- 4. fn_get_dispatcher_routes
CREATE OR REPLACE FUNCTION public.fn_get_dispatcher_routes()
RETURNS TABLE (
    route_id bigint,
    origin_hub_id bigint,
    origin_hub_code text,
    origin_hub_name text,
    dest_hub_id bigint,
    dest_hub_code text,
    dest_hub_name text,
    mode text,
    distance_km numeric,
    planned_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Authorization check
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT authz_private.is_active_user() THEN
        RAISE EXCEPTION 'User profile is not active';
    END IF;
    IF COALESCE(authz_private.current_app_role(), '') <> 'DISPATCHER' THEN
        RAISE EXCEPTION 'Unauthorized: must be DISPATCHER';
    END IF;

    RETURN QUERY
    SELECT 
        r.route_id,
        r.origin_hub_id,
        h1.hub_code AS origin_hub_code,
        h1.hub_name AS origin_hub_name,
        r.dest_hub_id,
        h2.hub_code AS dest_hub_code,
        h2.hub_name AS dest_hub_name,
        r.mode,
        r.distance_km,
        r.planned_hours
    FROM public.route r
    JOIN public.transit_hub h1 ON r.origin_hub_id = h1.hub_id
    JOIN public.transit_hub h2 ON r.dest_hub_id = h2.hub_id
    ORDER BY h1.hub_code ASC, h2.hub_code ASC;
END;
$$;

-- 5. fn_get_dispatcher_unassigned_packages
CREATE OR REPLACE FUNCTION public.fn_get_dispatcher_unassigned_packages(p_hub_id bigint)
RETURNS TABLE (
    package_id bigint,
    tracking_no text,
    origin_hub_code text,
    dest_hub_code text,
    weight_kg numeric,
    current_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Authorization check
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT authz_private.is_active_user() THEN
        RAISE EXCEPTION 'User profile is not active';
    END IF;
    IF COALESCE(authz_private.current_app_role(), '') <> 'DISPATCHER' THEN
        RAISE EXCEPTION 'Unauthorized: must be DISPATCHER';
    END IF;

    RETURN QUERY
    WITH LatestEvents AS (
        SELECT DISTINCT ON (te.package_id) 
            te.package_id,
            te.hub_id,
            te.status_code
        FROM public.tracking_event te
        ORDER BY te.package_id, te.event_time DESC, te.event_id DESC
    ),
    PackageLocations AS (
        SELECT 
            p.package_id,
            COALESCE(le.hub_id, p.origin_hub_id) AS current_hub_id,
            p.current_status
        FROM public.package p
        LEFT JOIN LatestEvents le ON p.package_id = le.package_id
    )
    SELECT 
        p.package_id,
        p.tracking_no,
        h1.hub_code AS origin_hub_code,
        h2.hub_code AS dest_hub_code,
        p.weight_kg,
        p.current_status
    FROM public.package p
    JOIN PackageLocations pl ON p.package_id = pl.package_id
    JOIN public.transit_hub h1 ON p.origin_hub_id = h1.hub_id
    JOIN public.transit_hub h2 ON p.dest_hub_id = h2.hub_id
    WHERE pl.current_status NOT IN ('DELIVERED', 'RETURNED')
      -- Must be physically at the specified hub
      AND pl.current_hub_id = p_hub_id
      -- Must NOT be currently assigned to a scheduled/active trip leg
      AND NOT EXISTS (
          SELECT 1 FROM public.package_leg plg
          WHERE plg.package_id = p.package_id
            AND plg.unloaded_at IS NULL
      )
    ORDER BY p.tracking_no ASC;
END;
$$;

-- Privileges configurations
REVOKE EXECUTE ON FUNCTION public.fn_get_dispatcher_drivers() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_get_dispatcher_vehicles() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_get_dispatcher_trips() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_get_dispatcher_routes() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_get_dispatcher_unassigned_packages(bigint) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fn_get_dispatcher_drivers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_dispatcher_vehicles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_dispatcher_trips() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_dispatcher_routes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_dispatcher_unassigned_packages(bigint) TO authenticated;
