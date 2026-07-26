-- MIGRATION 1: Authorization Schema and Helpers

-- Create schema for authorization helpers
CREATE SCHEMA authz_private;

-- Secure the schema
REVOKE ALL ON SCHEMA authz_private FROM PUBLIC;
REVOKE ALL ON SCHEMA authz_private FROM anon;
GRANT USAGE ON SCHEMA authz_private TO authenticated;

-- Helper 1: is_active_user()
CREATE OR REPLACE FUNCTION authz_private.is_active_user()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    v_is_active boolean;
BEGIN
    SELECT is_active INTO v_is_active
    FROM public.profiles
    WHERE user_id = auth.uid();
    
    RETURN COALESCE(v_is_active, false);
END;
$$;

-- Helper 2: current_app_role()
CREATE OR REPLACE FUNCTION authz_private.current_app_role()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    v_role text;
BEGIN
    SELECT app_role INTO v_role
    FROM public.profiles
    WHERE user_id = auth.uid() AND is_active = true;
    
    RETURN v_role;
END;
$$;

-- Helper 3: current_customer_id()
CREATE OR REPLACE FUNCTION authz_private.current_customer_id()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    v_customer_id bigint;
BEGIN
    SELECT customer_id INTO v_customer_id
    FROM public.profiles
    WHERE user_id = auth.uid() AND is_active = true AND app_role = 'CUSTOMER';
    
    RETURN v_customer_id;
END;
$$;

-- Helper 4: current_staff_id()
CREATE OR REPLACE FUNCTION authz_private.current_staff_id()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    v_staff_id bigint;
BEGIN
    SELECT staff_id INTO v_staff_id
    FROM public.profiles
    WHERE user_id = auth.uid() AND is_active = true AND app_role = 'HUB_OPERATOR';
    
    RETURN v_staff_id;
END;
$$;

-- Helper 5: current_staff_hub()
CREATE OR REPLACE FUNCTION authz_private.current_staff_hub()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    v_hub_id bigint;
BEGIN
    SELECT s.hub_id INTO v_hub_id
    FROM public.profiles p
    JOIN public.staff s ON p.staff_id = s.staff_id
    WHERE p.user_id = auth.uid() AND p.is_active = true AND p.app_role = 'HUB_OPERATOR';
    
    RETURN v_hub_id;
END;
$$;

-- Helper 6: current_user_owns_package()
CREATE OR REPLACE FUNCTION authz_private.current_user_owns_package(p_package_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    v_customer_id bigint;
    v_owns boolean;
BEGIN
    v_customer_id := authz_private.current_customer_id();
    IF v_customer_id IS NULL THEN
        RETURN false;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.package
        WHERE package_id = p_package_id
          AND (sender_id = v_customer_id OR receiver_id = v_customer_id)
    ) INTO v_owns;
    
    RETURN COALESCE(v_owns, false);
END;
$$;

-- Helper 7: latest_package_hub()
CREATE OR REPLACE FUNCTION authz_private.latest_package_hub(p_package_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    v_hub_id bigint;
BEGIN
    SELECT hub_id INTO v_hub_id
    FROM public.tracking_event
    WHERE package_id = p_package_id
    ORDER BY event_time DESC, event_id DESC
    LIMIT 1;
    
    RETURN v_hub_id;
END;
$$;

-- Revoke execute from PUBLIC and anon, grant to authenticated for all helpers
REVOKE EXECUTE ON FUNCTION authz_private.is_active_user() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION authz_private.is_active_user() TO authenticated;

REVOKE EXECUTE ON FUNCTION authz_private.current_app_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION authz_private.current_app_role() TO authenticated;

REVOKE EXECUTE ON FUNCTION authz_private.current_customer_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION authz_private.current_customer_id() TO authenticated;

REVOKE EXECUTE ON FUNCTION authz_private.current_staff_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION authz_private.current_staff_id() TO authenticated;

REVOKE EXECUTE ON FUNCTION authz_private.current_staff_hub() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION authz_private.current_staff_hub() TO authenticated;

REVOKE EXECUTE ON FUNCTION authz_private.current_user_owns_package(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION authz_private.current_user_owns_package(bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION authz_private.latest_package_hub(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION authz_private.latest_package_hub(bigint) TO authenticated;

-- Index Audit & Creation
-- existing:
-- profiles: user_id (PK), customer_id (UQ), staff_id (UQ)
-- package: current_status, (origin_hub_id, dest_hub_id)
-- tracking_event: (hub_id, event_time)

-- new indexes:
CREATE INDEX idx_package_sender_id ON public.package(sender_id);
CREATE INDEX idx_package_receiver_id ON public.package(receiver_id);
-- skipping origin_hub_id as it is prefix of existing idx_package_origin_dest
CREATE INDEX idx_package_dest_hub_id ON public.package(dest_hub_id);

CREATE INDEX idx_tracking_event_package_latest ON public.tracking_event(package_id, event_time DESC, event_id DESC);
CREATE INDEX idx_package_leg_package_id ON public.package_leg(package_id);
CREATE INDEX idx_delivery_attempt_package_id ON public.delivery_attempt(package_id);
