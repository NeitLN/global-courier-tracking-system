-- MIGRATION 2: Operational Functions F1-F5 (Phase 3)

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
            IF i = 5 THEN
                RAISE EXCEPTION 'Failed to generate a unique tracking number after 5 attempts.';
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
    v_result jsonb;
BEGIN
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
BEGIN
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
