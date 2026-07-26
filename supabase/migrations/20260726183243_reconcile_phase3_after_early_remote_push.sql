-- MIGRATION: reconcile_phase3_after_early_remote_push
-- Purpose: Reconciles the remote schema after an accidental early deployment of Phase 3.
-- Corrects operational constraints, analytics bugs, and downgrades overly permissive SECURITY DEFINERs.

-- F1: Register Package F1, R9, R10
CREATE OR REPLACE FUNCTION public.fn_register_package(
    p_sender_id bigint,
    p_receiver_id bigint,
    p_service_id bigint,
    p_weight_kg numeric,
    p_length_cm numeric DEFAULT NULL,
    p_width_cm numeric DEFAULT NULL,
    p_height_cm numeric DEFAULT NULL,
    p_origin_hub_id bigint DEFAULT NULL,
    p_dest_hub_id bigint DEFAULT NULL
)
RETURNS public.package
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_service record;
    v_tracking_no text;
    v_shipping_fee numeric(12,2);
    v_package public.package;
    v_constraint_name text;
BEGIN
    -- Validate sender and receiver
    IF p_sender_id = p_receiver_id THEN
        RAISE EXCEPTION 'Sender and receiver cannot be the same customer.';
    END IF;

    -- Validate hubs
    IF p_origin_hub_id IS NULL THEN
        RAISE EXCEPTION 'Origin hub is required.';
    END IF;
    IF p_dest_hub_id IS NULL THEN
        RAISE EXCEPTION 'Destination hub is required.';
    END IF;
    IF p_origin_hub_id = p_dest_hub_id THEN
        RAISE EXCEPTION 'Origin and destination hubs cannot be the same.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.transit_hub WHERE hub_id = p_origin_hub_id) THEN
        RAISE EXCEPTION 'Origin hub not found: %', p_origin_hub_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.transit_hub WHERE hub_id = p_dest_hub_id) THEN
        RAISE EXCEPTION 'Destination hub not found: %', p_dest_hub_id;
    END IF;

    -- Fetch service details
    SELECT * INTO v_service
    FROM public.service_type
    WHERE service_id = p_service_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid service_id: %', p_service_id;
    END IF;

    -- Validate weight against service max_weight_kg
    IF p_weight_kg <= 0 THEN
        RAISE EXCEPTION 'Weight must be greater than 0.';
    END IF;
    IF p_weight_kg > v_service.max_weight_kg THEN
        RAISE EXCEPTION 'Weight % kg exceeds maximum allowed % kg for service %.', p_weight_kg, v_service.max_weight_kg, v_service.service_name;
    END IF;

    -- Calculate shipping fee
    v_shipping_fee := round(v_service.base_rate + (v_service.per_kg_rate * p_weight_kg), 2);

    -- Generate tracking number with bounded retry loop for collision safety
    FOR i IN 1..5 LOOP
        BEGIN
            -- Implementation convention: wider random component
            v_tracking_no := 'GC-' || to_char(now() at time zone 'UTC', 'YYYYMMDD') || '-' || upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 10));

            -- Insert package
            INSERT INTO public.package (
                tracking_no, sender_id, receiver_id, service_id, weight_kg,
                length_cm, width_cm, height_cm, shipping_fee,
                origin_hub_id, dest_hub_id, current_status
            ) VALUES (
                v_tracking_no, p_sender_id, p_receiver_id, p_service_id, p_weight_kg,
                p_length_cm, p_width_cm, p_height_cm, v_shipping_fee,
                p_origin_hub_id, p_dest_hub_id, 'REGISTERED'
            ) RETURNING * INTO v_package;
            
            EXIT; -- Success, exit loop
        EXCEPTION WHEN unique_violation THEN
            GET STACKED DIAGNOSTICS v_constraint_name = CONSTRAINT_NAME;
            IF v_constraint_name = 'package_tracking_no_key' THEN
                IF i = 5 THEN
                    RAISE EXCEPTION 'Failed to generate a unique tracking number after 5 attempts.';
                END IF;
            ELSE
                RAISE; -- Re-raise unrelated unique violations
            END IF;
        END;
    END LOOP;

    -- Insert initial tracking event
    INSERT INTO public.tracking_event (
        package_id, hub_id, status_code, event_time, recorded_by
    ) VALUES (
        v_package.package_id, p_origin_hub_id, 'REGISTERED', now(), NULL
    );

    RETURN v_package;
END;
$$;


-- F3: Record Checkpoint Scan
CREATE OR REPLACE FUNCTION public.fn_record_checkpoint_scan(
    p_tracking_no text,
    p_hub_id bigint,
    p_status_code text,
    p_event_time timestamptz,
    p_recorded_by bigint DEFAULT NULL
)
RETURNS public.tracking_event
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_package_id bigint;
    v_staff_hub_id bigint;
    v_event public.tracking_event;
BEGIN
    -- Validate package exists
    SELECT package_id INTO v_package_id
    FROM public.package
    WHERE tracking_no = p_tracking_no;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tracking number not found: %', p_tracking_no;
    END IF;

    -- Validate hub exists
    IF NOT EXISTS (SELECT 1 FROM public.transit_hub WHERE hub_id = p_hub_id) THEN
        RAISE EXCEPTION 'Hub not found: %', p_hub_id;
    END IF;

    -- Validate recorded_by staff (F3 is always an operator scan path)
    IF p_recorded_by IS NULL THEN
        RAISE EXCEPTION 'Operator scan requires recorded_by staff ID.';
    END IF;

    SELECT hub_id INTO v_staff_hub_id
    FROM public.staff
    WHERE staff_id = p_recorded_by;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Staff not found: %', p_recorded_by;
    END IF;

    IF v_staff_hub_id <> p_hub_id THEN
        RAISE EXCEPTION 'Staff % does not belong to hub %.', p_recorded_by, p_hub_id;
    END IF;

    -- Insert tracking event (R6 validation handled by trigger)
    INSERT INTO public.tracking_event (
        package_id, hub_id, status_code, event_time, recorded_by
    ) VALUES (
        v_package_id, p_hub_id, p_status_code, p_event_time, p_recorded_by
    ) RETURNING * INTO v_event;

    RETURN v_event;
END;
$$;


-- F5: Update Customer Details
CREATE OR REPLACE FUNCTION public.fn_update_customer(
    p_customer_id bigint,
    p_name text DEFAULT NULL,
    p_email text DEFAULT NULL,
    p_phone text DEFAULT NULL
)
RETURNS public.customer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_customer public.customer;
BEGIN
    SELECT * INTO v_customer
    FROM public.customer
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer not found: %', p_customer_id;
    END IF;

    IF p_name IS NOT NULL AND btrim(p_name) = '' THEN
        RAISE EXCEPTION 'Customer name cannot be blank.';
    END IF;

    IF p_email IS NOT NULL AND btrim(p_email) = '' THEN
        RAISE EXCEPTION 'Customer email cannot be blank.';
    END IF;

    IF p_phone IS NOT NULL AND btrim(p_phone) = '' THEN
        RAISE EXCEPTION 'Customer phone cannot be blank.';
    END IF;

    UPDATE public.customer
    SET 
        full_name = COALESCE(p_name, full_name),
        email = COALESCE(p_email, email),
        phone = COALESCE(p_phone, phone)
    WHERE customer_id = p_customer_id
    RETURNING * INTO v_customer;

    RETURN v_customer;
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


-- TRIGGER SECURITY
-- Ensure trigger implementations correctly drop to INVOKER context

-- 1. Append-only enforcement for tracking_event (R7)
CREATE OR REPLACE FUNCTION public.fn_prevent_history_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    RAISE EXCEPTION 'Tracking history is append-only. Updates and deletions are forbidden (R7).';
END;
$$;

-- 3. Package current status cache synchronization
CREATE OR REPLACE FUNCTION public.fn_sync_package_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    UPDATE public.package
    SET current_status = NEW.status_code
    WHERE package_id = NEW.package_id;
    RETURN NEW;
END;
$$;