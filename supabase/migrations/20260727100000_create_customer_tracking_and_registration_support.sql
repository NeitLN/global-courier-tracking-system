-- PHASE 7 + 8: public-safe tracking, customer dashboard, and receiver-email registration.
-- Existing migrations 1-16 remain immutable; this migration only adds new RPCs.

CREATE OR REPLACE FUNCTION public.fn_public_track_package(p_tracking_no text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
    v_result jsonb;
BEGIN
    IF p_tracking_no IS NULL OR btrim(p_tracking_no) = '' THEN
        RAISE EXCEPTION 'Tracking number is required';
    END IF;

    SELECT jsonb_build_object(
        'tracking_no', p.tracking_no,
        'current_status', p.current_status,
        'service_type', st.service_name,
        'origin_hub', jsonb_build_object('code', oh.hub_code, 'name', oh.hub_name),
        'destination_hub', jsonb_build_object('code', dh.hub_code, 'name', dh.hub_name),
        'latest_update', (
            SELECT max(te.event_time)
            FROM public.tracking_event te
            WHERE te.package_id = p.package_id
        ),
        'timeline', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'event_order', timeline.event_order,
                    'status', timeline.status_code,
                    'event_time', timeline.event_time,
                    'hub', jsonb_build_object('code', timeline.hub_code, 'name', timeline.hub_name),
                    'is_current', timeline.event_order = timeline.total_events
                ) ORDER BY timeline.event_order
            ), '[]'::jsonb)
            FROM (
                SELECT
                    row_number() OVER (ORDER BY te.event_time, te.event_id) AS event_order,
                    count(*) OVER () AS total_events,
                    te.status_code,
                    te.event_time,
                    h.hub_code,
                    h.hub_name
                FROM public.tracking_event te
                JOIN public.transit_hub h ON h.hub_id = te.hub_id
                WHERE te.package_id = p.package_id
            ) timeline
        )
    )
    INTO v_result
    FROM public.package p
    JOIN public.service_type st ON st.service_id = p.service_id
    JOIN public.transit_hub oh ON oh.hub_id = p.origin_hub_id
    JOIN public.transit_hub dh ON dh.hub_id = p.dest_hub_id
    WHERE p.tracking_no = upper(btrim(p_tracking_no));

    IF v_result IS NULL THEN
        RAISE EXCEPTION 'Tracking number not found';
    END IF;

    RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_public_track_package(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_public_track_package(text) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_register_package_by_receiver_email(
    p_receiver_email text,
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
    v_sender_id bigint;
    v_receiver_id bigint;
    v_package public.package;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT authz_private.is_active_user() THEN
        RAISE EXCEPTION 'User profile is not active';
    END IF;
    IF COALESCE(authz_private.current_app_role(), '') <> 'CUSTOMER' THEN
        RAISE EXCEPTION 'Unauthorized: must be CUSTOMER';
    END IF;
    IF p_receiver_email IS NULL OR btrim(p_receiver_email) = '' THEN
        RAISE EXCEPTION 'Receiver email is required';
    END IF;

    v_sender_id := authz_private.current_customer_id();

    SELECT c.customer_id INTO v_receiver_id
    FROM public.customer c
    WHERE c.email = btrim(p_receiver_email);

    IF v_receiver_id IS NULL THEN
        RAISE EXCEPTION 'Receiver customer not found';
    END IF;

    SELECT * INTO v_package
    FROM public.fn_register_package(
        v_sender_id,
        v_receiver_id,
        p_service_id,
        p_weight_kg,
        p_length_cm,
        p_width_cm,
        p_height_cm,
        p_origin_hub_id,
        p_dest_hub_id
    );

    RETURN v_package;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_register_package_by_receiver_email(text, bigint, numeric, numeric, numeric, numeric, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_register_package_by_receiver_email(text, bigint, numeric, numeric, numeric, numeric, bigint, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_customer_dashboard_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
STABLE
SET search_path = ''
AS $$
DECLARE
    v_customer_id bigint;
    v_result jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT authz_private.is_active_user() THEN
        RAISE EXCEPTION 'User profile is not active';
    END IF;
    IF COALESCE(authz_private.current_app_role(), '') <> 'CUSTOMER' THEN
        RAISE EXCEPTION 'Unauthorized: must be CUSTOMER';
    END IF;

    v_customer_id := authz_private.current_customer_id();

    SELECT jsonb_build_object(
        'active_shipments', count(*) FILTER (WHERE p.current_status NOT IN ('DELIVERED', 'RETURNED')),
        'delivered_shipments', count(*) FILTER (WHERE p.current_status = 'DELIVERED'),
        'returned_shipments', count(*) FILTER (WHERE p.current_status = 'RETURNED'),
        'latest_update', (
            SELECT max(te.event_time)
            FROM public.tracking_event te
            JOIN public.package owned ON owned.package_id = te.package_id
            WHERE owned.sender_id = v_customer_id OR owned.receiver_id = v_customer_id
        )
    ) INTO v_result
    FROM public.package p
    WHERE p.sender_id = v_customer_id OR p.receiver_id = v_customer_id;

    RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_customer_dashboard_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_customer_dashboard_summary() TO authenticated;
