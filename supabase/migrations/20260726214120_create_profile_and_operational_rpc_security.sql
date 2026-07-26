-- MIGRATION 2: Profile and Operational RPC Security

-- A. Display-name constraint
ALTER TABLE public.profiles ADD CONSTRAINT chk_profiles_display_name_length CHECK (display_name IS NULL OR char_length(display_name) <= 100);

-- B. Create Display-name RPC
CREATE OR REPLACE FUNCTION public.fn_update_display_name(p_display_name text)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_profile public.profiles;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT authz_private.is_active_user() THEN
        RAISE EXCEPTION 'User profile is not active';
    END IF;

    IF p_display_name IS NOT NULL AND btrim(p_display_name) = '' THEN
        RAISE EXCEPTION 'Display name cannot be whitespace only';
    END IF;

    IF char_length(p_display_name) > 100 THEN
        RAISE EXCEPTION 'Display name exceeds 100 characters';
    END IF;

    UPDATE public.profiles
    SET display_name = p_display_name
    WHERE user_id = auth.uid()
    RETURNING * INTO v_profile;

    RETURN v_profile;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_update_display_name(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_update_display_name(text) TO authenticated, service_role;

-- C. Harden Existing Write RPCs

-- F1: Register Package
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
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_is_trusted_backend boolean;
    v_service record;
    v_tracking_no text;
    v_shipping_fee numeric(12,2);
    v_package public.package;
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
        IF COALESCE(authz_private.current_app_role(), '') <> 'CUSTOMER' THEN
            RAISE EXCEPTION 'Unauthorized: must be CUSTOMER';
        END IF;
        IF p_sender_id <> authz_private.current_customer_id() THEN
            RAISE EXCEPTION 'Unauthorized: cannot register package for another customer';
        END IF;
    END IF;

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
            v_tracking_no := 'GC-' || to_char(now() at time zone 'UTC', 'YYYYMMDD') || '-' || upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 10));

            INSERT INTO public.package (
                tracking_no, sender_id, receiver_id, service_id, weight_kg,
                length_cm, width_cm, height_cm, shipping_fee,
                origin_hub_id, dest_hub_id, current_status
            ) VALUES (
                v_tracking_no, p_sender_id, p_receiver_id, p_service_id, p_weight_kg,
                p_length_cm, p_width_cm, p_height_cm, v_shipping_fee,
                p_origin_hub_id, p_dest_hub_id, 'REGISTERED'
            ) RETURNING * INTO v_package;
            
            EXIT; 
        EXCEPTION WHEN unique_violation THEN
            IF i = 5 THEN
                RAISE EXCEPTION 'Failed to generate a unique tracking number after 5 attempts.';
            END IF;
        END;
    END LOOP;

    INSERT INTO public.tracking_event (
        package_id, hub_id, status_code, event_time, recorded_by
    ) VALUES (
        v_package.package_id, p_origin_hub_id, 'REGISTERED', now(), NULL
    );

    RETURN v_package;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_register_package(bigint, bigint, bigint, numeric, numeric, numeric, numeric, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_register_package(bigint, bigint, bigint, numeric, numeric, numeric, numeric, bigint, bigint) TO authenticated, service_role;


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
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_is_trusted_backend boolean;
    v_package_id bigint;
    v_staff_hub_id bigint;
    v_event public.tracking_event;
    v_package_origin_hub bigint;
    v_package_dest_hub bigint;
BEGIN
    -- Trusted backend check: see fn_register_package for rationale.
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
        IF p_recorded_by <> authz_private.current_staff_id() THEN
            RAISE EXCEPTION 'Unauthorized: cannot record scan for another staff member';
        END IF;
        IF p_hub_id <> authz_private.current_staff_hub() THEN
            RAISE EXCEPTION 'Unauthorized: cannot record scan for another hub';
        END IF;
    END IF;

    SELECT package_id, origin_hub_id, dest_hub_id INTO v_package_id, v_package_origin_hub, v_package_dest_hub
    FROM public.package
    WHERE tracking_no = p_tracking_no;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tracking number not found: %', p_tracking_no;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.transit_hub WHERE hub_id = p_hub_id) THEN
        RAISE EXCEPTION 'Hub not found: %', p_hub_id;
    END IF;

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

    IF NOT v_is_trusted_backend THEN
        IF v_package_origin_hub <> p_hub_id AND v_package_dest_hub <> p_hub_id AND COALESCE(authz_private.latest_package_hub(v_package_id), 0) <> p_hub_id THEN
            RAISE EXCEPTION 'Unauthorized: package is not at this hub';
        END IF;
    END IF;

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
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_is_trusted_backend boolean;
    v_customer public.customer;
BEGIN
    -- Trusted backend check: see fn_register_package for rationale.
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
        IF COALESCE(authz_private.current_app_role(), '') <> 'CUSTOMER' THEN
            RAISE EXCEPTION 'Unauthorized: must be CUSTOMER';
        END IF;
        IF p_customer_id <> authz_private.current_customer_id() THEN
            RAISE EXCEPTION 'Unauthorized: cannot update another customer';
        END IF;
    END IF;

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
REVOKE EXECUTE ON FUNCTION public.fn_record_checkpoint_scan FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_record_checkpoint_scan TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_update_customer FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_update_customer TO authenticated, service_role;
