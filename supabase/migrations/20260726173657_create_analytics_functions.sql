-- MIGRATION 3: Analytics Functions F6-F10 (Phase 3)

-- F6: Chain of Custody (LAG)
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
    v_package_id bigint;
BEGIN
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


-- F7: Inter-scan Hub Analysis (LEAD, CTE)
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
SECURITY INVOKER
STABLE
SET search_path = public
AS $$
BEGIN
    -- This analyzes the time spent AFTER a scan at a given hub UNTIL the very next scan (which could be at the same or different hub).
    -- Excludes rows with no next event (i.e. terminal or latest event).
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
          AND ne.next_event_time >= ne.event_time -- avoid negative durations
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
SECURITY INVOKER
STABLE
SET search_path = public
AS $$
BEGIN
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


-- F9: Driver Performance Ranking (DENSE_RANK)
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
SECURITY INVOKER
STABLE
SET search_path = public
AS $$
BEGIN
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


-- F10: Recursive Multi-hop Routes
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
BEGIN
    IF p_max_hops IS NULL OR p_max_hops < 1 OR p_max_hops > 10 THEN
        RAISE EXCEPTION 'p_max_hops must be between 1 and 10.';
    END IF;

    IF p_origin_hub_id = p_dest_hub_id THEN
        -- Origin = destination policy: No path needed or handled explicitly
        RETURN;
    END IF;

    RETURN QUERY
    WITH RECURSIVE RoutePath AS (
        -- Base Case
        SELECT 
            r.dest_hub_id AS current_hub_id,
            ARRAY[r.origin_hub_id, r.dest_hub_id] AS hubs_visited,
            r.distance_km::numeric AS agg_distance,
            r.planned_hours::numeric AS agg_hours,
            1 AS hops
        FROM public.route r
        WHERE r.origin_hub_id = p_origin_hub_id

        UNION ALL

        -- Recursive Step
        SELECT 
            next_route.dest_hub_id AS current_hub_id,
            rp.hubs_visited || next_route.dest_hub_id AS hubs_visited,
            (rp.agg_distance + next_route.distance_km)::numeric AS agg_distance,
            (rp.agg_hours + next_route.planned_hours)::numeric AS agg_hours,
            rp.hops + 1 AS hops
        FROM RoutePath rp
        JOIN public.route next_route ON rp.current_hub_id = next_route.origin_hub_id
        WHERE rp.hops < p_max_hops
          AND next_route.dest_hub_id != ALL(rp.hubs_visited) -- Cycle guard
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
