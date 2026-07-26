-- MIGRATION 3: Harden Read and Analytics RPCs

-- 1. Revoke public execution for all trigger functions
REVOKE EXECUTE ON FUNCTION public.fn_validate_tracking_status() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_sync_package_status() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_prevent_history_mutation() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_profiles_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_handle_new_auth_user() FROM PUBLIC, anon;

-- 2. Read Functions (Remain SECURITY INVOKER)

-- F2: Track Package
CREATE OR REPLACE FUNCTION public.fn_track_package(
    p_tracking_no text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
STABLE
SET search_path = public
AS $$
DECLARE
    v_is_trusted_backend boolean;
    v_result jsonb;
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
        IF COALESCE(authz_private.current_app_role(), '') NOT IN ('CUSTOMER', 'HUB_OPERATOR', 'DISPATCHER') THEN
            RAISE EXCEPTION 'Unauthorized: must be CUSTOMER, HUB_OPERATOR, or DISPATCHER';
        END IF;
    END IF;

    SELECT jsonb_build_object(
        'package_id', p.package_id,
        'tracking_no', p.tracking_no,
        'sender_id', p.sender_id,
        'receiver_id', p.receiver_id,
        'service', (SELECT service_name FROM public.service_type WHERE service_id = p.service_id),
        'shipping_fee', p.shipping_fee,
        'origin_hub_id', p.origin_hub_id,
        'dest_hub_id', p.dest_hub_id,
        'current_status', p.current_status,
        'history', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'event_id', te.event_id,
                    'hub_id', te.hub_id,
                    'status_code', te.status_code,
                    'event_time', te.event_time,
                    'recorded_by', te.recorded_by
                ) ORDER BY te.event_time ASC
            ), '[]'::jsonb)
            FROM public.tracking_event te
            WHERE te.package_id = p.package_id
        )
    ) INTO v_result
    FROM public.package p
    WHERE p.tracking_no = p_tracking_no;

    IF v_result IS NULL THEN
        RAISE EXCEPTION 'Tracking number not found: %', p_tracking_no;
    END IF;

    RETURN v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_track_package(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_track_package(text) TO authenticated, service_role;


-- F6: Chain of Custody
CREATE OR REPLACE FUNCTION public.fn_chain_of_custody(
    p_tracking_no text
)
RETURNS TABLE (
    event_id bigint,
    event_time timestamptz,
    hub_id bigint,
    status_code text,
    recorded_by bigint,
    previous_hub_id bigint,
    previous_staff_id bigint,
    previous_event_time timestamptz,
    elapsed_interval interval
)
LANGUAGE plpgsql
SECURITY INVOKER
STABLE
SET search_path = public
AS $$
DECLARE
    v_is_trusted_backend boolean;
    v_package_id bigint;
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
        IF COALESCE(authz_private.current_app_role(), '') NOT IN ('CUSTOMER', 'HUB_OPERATOR', 'DISPATCHER') THEN
            RAISE EXCEPTION 'Unauthorized: must be CUSTOMER, HUB_OPERATOR, or DISPATCHER';
        END IF;
    END IF;

    SELECT package_id INTO v_package_id
    FROM public.package
    WHERE tracking_no = p_tracking_no;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tracking number not found: %', p_tracking_no;
    END IF;

    RETURN QUERY
    SELECT 
        te.event_id,
        te.event_time,
        te.hub_id,
        te.status_code,
        te.recorded_by,
        LAG(te.hub_id) OVER (ORDER BY te.event_time ASC) AS previous_hub_id,
        LAG(te.recorded_by) OVER (ORDER BY te.event_time ASC) AS previous_staff_id,
        LAG(te.event_time) OVER (ORDER BY te.event_time ASC) AS previous_event_time,
        te.event_time - LAG(te.event_time) OVER (ORDER BY te.event_time ASC) AS elapsed_interval
    FROM public.tracking_event te
    WHERE te.package_id = v_package_id
    ORDER BY te.event_time ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_chain_of_custody(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_chain_of_custody(text) TO authenticated, service_role;


-- F4: Current Hub Inventory
CREATE OR REPLACE FUNCTION public.fn_current_hub_inventory(
    p_hub_id bigint
)
RETURNS TABLE (
    package_id bigint,
    tracking_no text,
    current_status text,
    latest_event_time timestamptz
)
LANGUAGE plpgsql
SECURITY INVOKER
STABLE
SET search_path = public
AS $$
DECLARE
    v_is_trusted_backend boolean;
    v_role text;
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
        v_role := COALESCE(authz_private.current_app_role(), '');
        IF v_role NOT IN ('HUB_OPERATOR', 'DISPATCHER') THEN
            RAISE EXCEPTION 'Unauthorized: must be HUB_OPERATOR or DISPATCHER';
        END IF;
        IF v_role = 'HUB_OPERATOR' AND p_hub_id <> authz_private.current_staff_hub() THEN
            RAISE EXCEPTION 'Unauthorized: cannot view inventory for another hub';
        END IF;
    END IF;

    RETURN QUERY
    WITH RankedEvents AS (
        SELECT 
            te.package_id,
            te.hub_id,
            te.status_code,
            te.event_time,
            sc.is_terminal,
            ROW_NUMBER() OVER(PARTITION BY te.package_id ORDER BY te.event_time DESC) as rn
        FROM public.tracking_event te
        JOIN public.status_code sc ON te.status_code = sc.status_code
    )
    SELECT 
        p.package_id,
        p.tracking_no,
        re.status_code AS current_status,
        re.event_time AS latest_event_time
    FROM RankedEvents re
    JOIN public.package p ON re.package_id = p.package_id
    WHERE re.rn = 1
      AND re.hub_id = p_hub_id
      AND re.is_terminal = false;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_current_hub_inventory(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_current_hub_inventory(bigint) TO authenticated, service_role;


-- F10: Find Routes
CREATE OR REPLACE FUNCTION public.fn_find_routes(
    p_origin_hub_id bigint,
    p_dest_hub_id bigint,
    p_max_hops integer DEFAULT 3
)
RETURNS TABLE (
    path_array bigint[],
    total_distance_km numeric,
    total_planned_hours numeric,
    hop_count integer
)
LANGUAGE plpgsql
SECURITY INVOKER
STABLE
SET search_path = public
AS $$
DECLARE
    v_is_trusted_backend boolean;
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
        IF COALESCE(authz_private.current_app_role(), '') NOT IN ('DISPATCHER', 'ANALYST') THEN
            RAISE EXCEPTION 'Unauthorized: must be DISPATCHER or ANALYST';
        END IF;
    END IF;

    IF p_max_hops IS NULL OR p_max_hops < 1 OR p_max_hops > 10 THEN
        RAISE EXCEPTION 'p_max_hops must be between 1 and 10.';
    END IF;

    IF p_origin_hub_id = p_dest_hub_id THEN
        RETURN;
    END IF;

    RETURN QUERY
    WITH RECURSIVE RoutePath AS (
        SELECT 
            r.dest_hub_id AS current_hub_id,
            ARRAY[r.origin_hub_id, r.dest_hub_id] AS hubs_visited,
            r.distance_km::numeric AS agg_distance,
            r.planned_hours::numeric AS agg_hours,
            1 AS hops
        FROM public.route r
        WHERE r.origin_hub_id = p_origin_hub_id

        UNION ALL

        SELECT 
            next_route.dest_hub_id AS current_hub_id,
            rp.hubs_visited || next_route.dest_hub_id AS hubs_visited,
            (rp.agg_distance + next_route.distance_km)::numeric AS agg_distance,
            (rp.agg_hours + next_route.planned_hours)::numeric AS agg_hours,
            rp.hops + 1 AS hops
        FROM RoutePath rp
        JOIN public.route next_route ON rp.current_hub_id = next_route.origin_hub_id
        WHERE rp.hops < p_max_hops
          AND next_route.dest_hub_id != ALL(rp.hubs_visited)
    )
    SELECT 
        rp.hubs_visited AS path_array,
        rp.agg_distance AS total_distance_km,
        rp.agg_hours AS total_planned_hours,
        rp.hops AS hop_count
    FROM RoutePath rp
    WHERE rp.current_hub_id = p_dest_hub_id
    ORDER BY rp.agg_hours ASC, rp.hops ASC, rp.hubs_visited ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_find_routes(bigint, bigint, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_find_routes(bigint, bigint, integer) TO authenticated, service_role;


-- 3. Analytics Functions (Convert to SECURITY DEFINER)

-- F7: Inter-scan Hub Analysis
CREATE OR REPLACE FUNCTION public.fn_inter_scan_hub_analysis()
RETURNS TABLE (
    hub_id bigint,
    hub_code text,
    segment_count bigint,
    avg_hours numeric,
    min_hours numeric,
    max_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
    v_is_trusted_backend boolean;
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
        IF COALESCE(authz_private.current_app_role(), '') NOT IN ('DISPATCHER', 'ANALYST') THEN
            RAISE EXCEPTION 'Unauthorized: must be DISPATCHER or ANALYST';
        END IF;
    END IF;

    RETURN QUERY
    WITH NextEvents AS (
        SELECT 
            te.package_id,
            te.hub_id,
            te.event_time,
            LEAD(te.event_time) OVER (PARTITION BY te.package_id ORDER BY te.event_time ASC) AS next_event_time
        FROM public.tracking_event te
    ),
    Segments AS (
        SELECT 
            ne.hub_id,
            EXTRACT(EPOCH FROM (ne.next_event_time - ne.event_time))/3600.0 AS duration_hours
        FROM NextEvents ne
        WHERE ne.next_event_time IS NOT NULL
          AND ne.next_event_time >= ne.event_time
    )
    SELECT 
        th.hub_id,
        th.hub_code,
        COUNT(s.duration_hours) AS segment_count,
        ROUND(AVG(s.duration_hours)::numeric, 2) AS avg_hours,
        ROUND(MIN(s.duration_hours)::numeric, 2) AS min_hours,
        ROUND(MAX(s.duration_hours)::numeric, 2) AS max_hours
    FROM public.transit_hub th
    JOIN Segments s ON th.hub_id = s.hub_id
    GROUP BY th.hub_id, th.hub_code;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_inter_scan_hub_analysis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_inter_scan_hub_analysis() TO authenticated, service_role;


-- F8: SLA Compliance
CREATE OR REPLACE FUNCTION public.fn_sla_compliance(
    p_start_date date DEFAULT NULL,
    p_end_date date DEFAULT NULL
)
RETURNS TABLE (
    package_id bigint,
    tracking_no text,
    service_name text,
    registered_at timestamptz,
    delivered_at timestamptz,
    elapsed_hours numeric,
    sla_hours integer,
    compliance_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
    v_is_trusted_backend boolean;
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
        IF COALESCE(authz_private.current_app_role(), '') NOT IN ('DISPATCHER', 'ANALYST') THEN
            RAISE EXCEPTION 'Unauthorized: must be DISPATCHER or ANALYST';
        END IF;
    END IF;

    RETURN QUERY
    WITH PackageTimestamps AS (
        SELECT 
            p.package_id,
            p.tracking_no,
            st.service_name,
            st.sla_hours,
            p.current_status,
            (SELECT event_time FROM public.tracking_event te WHERE te.package_id = p.package_id AND te.status_code = 'REGISTERED' ORDER BY te.event_time ASC LIMIT 1) AS registered_at,
            (SELECT event_time FROM public.tracking_event te WHERE te.package_id = p.package_id AND te.status_code = 'DELIVERED' ORDER BY te.event_time ASC LIMIT 1) AS delivered_at
        FROM public.package p
        JOIN public.service_type st ON p.service_id = st.service_id
    )
    SELECT 
        pt.package_id,
        pt.tracking_no,
        pt.service_name,
        pt.registered_at,
        pt.delivered_at,
        CASE 
            WHEN pt.delivered_at IS NOT NULL THEN ROUND(EXTRACT(EPOCH FROM (pt.delivered_at - pt.registered_at))/3600.0::numeric, 2)
            ELSE ROUND(EXTRACT(EPOCH FROM (now() - pt.registered_at))/3600.0::numeric, 2)
        END AS elapsed_hours,
        pt.sla_hours,
        CASE
            WHEN pt.current_status = 'RETURNED' THEN 'RETURNED'
            WHEN pt.delivered_at IS NOT NULL THEN
                CASE WHEN EXTRACT(EPOCH FROM (pt.delivered_at - pt.registered_at))/3600.0 <= pt.sla_hours THEN 'MET' ELSE 'BREACHED' END
            ELSE 
                CASE WHEN EXTRACT(EPOCH FROM (now() - pt.registered_at))/3600.0 <= pt.sla_hours THEN 'OPEN' ELSE 'BREACHED' END
        END AS compliance_status
    FROM PackageTimestamps pt
    WHERE pt.registered_at IS NOT NULL
      AND (p_start_date IS NULL OR pt.registered_at >= p_start_date)
      AND (p_end_date IS NULL OR pt.registered_at < (p_end_date + INTERVAL '1 day'));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_sla_compliance(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_sla_compliance(date, date) TO authenticated, service_role;


-- F9: Driver Performance Ranking
CREATE OR REPLACE FUNCTION public.fn_rank_driver_performance()
RETURNS TABLE (
    driver_id bigint,
    driver_name text,
    total_attempts bigint,
    successful_attempts bigint,
    failed_attempts bigint,
    success_rate numeric,
    performance_rank integer
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
    v_is_trusted_backend boolean;
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

    RETURN QUERY
    WITH DriverStats AS (
        SELECT 
            d.driver_id,
            d.full_name AS driver_name,
            COUNT(da.attempt_id) AS total_attempts,
            COUNT(da.attempt_id) FILTER (WHERE da.outcome = 'SUCCESS') AS successful_attempts,
            COUNT(da.attempt_id) FILTER (WHERE da.outcome = 'FAILED') AS failed_attempts
        FROM public.driver d
        LEFT JOIN public.delivery_attempt da ON d.driver_id = da.driver_id
        GROUP BY d.driver_id, d.full_name
    ),
    Rates AS (
        SELECT 
            ds.driver_id,
            ds.driver_name,
            ds.total_attempts,
            ds.successful_attempts,
            ds.failed_attempts,
            CASE 
                WHEN ds.total_attempts = 0 THEN 0.00
                ELSE ROUND((ds.successful_attempts::numeric / ds.total_attempts::numeric) * 100.0, 2)
            END AS success_rate
        FROM DriverStats ds
    )
    SELECT 
        r.driver_id,
        r.driver_name,
        r.total_attempts,
        r.successful_attempts,
        r.failed_attempts,
        r.success_rate,
        DENSE_RANK() OVER (ORDER BY r.success_rate DESC, r.total_attempts DESC)::integer AS performance_rank
    FROM Rates r
    ORDER BY performance_rank ASC, r.driver_id ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_rank_driver_performance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rank_driver_performance() TO authenticated, service_role;
