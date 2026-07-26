-- MIGRATION: create_auth_profiles

-- 1. Create public.profiles table (authentication-support table, not a domain relation)
CREATE TABLE public.profiles (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    display_name text NULL,
    app_role text NULL,
    customer_id bigint NULL UNIQUE REFERENCES public.customer(customer_id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    staff_id bigint NULL UNIQUE REFERENCES public.staff(staff_id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_profiles_display_name_not_blank CHECK (
        display_name IS NULL OR btrim(display_name) <> ''
    ),

    CONSTRAINT chk_profiles_app_role_valid CHECK (
        app_role IS NULL OR app_role IN ('CUSTOMER', 'HUB_OPERATOR', 'DISPATCHER', 'ANALYST')
    ),

    CONSTRAINT chk_profiles_role_binding_consistency CHECK (
        (app_role IS NULL AND customer_id IS NULL AND staff_id IS NULL)
        OR
        (app_role = 'CUSTOMER' AND customer_id IS NOT NULL AND staff_id IS NULL)
        OR
        (app_role = 'HUB_OPERATOR' AND staff_id IS NOT NULL AND customer_id IS NULL)
        OR
        (app_role IN ('DISPATCHER', 'ANALYST') AND customer_id IS NULL AND staff_id IS NULL)
    )
);

-- 2. Trigger for updated_at
CREATE OR REPLACE FUNCTION public.fn_profiles_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_profiles_updated_at();

-- 3. Automatic Profile Provisioning
-- SECURITY DEFINER is required because this trigger is fired by an auth.users insert,
-- which runs under the context of the user signing up, but needs to write to public.profiles.
CREATE OR REPLACE FUNCTION public.fn_handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_display_name text;
BEGIN
    -- Extract and trim display_name from raw_user_meta_data
    v_display_name := btrim(NEW.raw_user_meta_data->>'display_name');
    IF v_display_name = '' THEN
        v_display_name := NULL;
    END IF;

    -- Insert new profile, ignoring any supplied app_role, customer_id, or staff_id
    -- to prevent malicious role assignment during signup.
    INSERT INTO public.profiles (user_id, display_name, app_role, customer_id, staff_id, is_active)
    VALUES (NEW.id, v_display_name, NULL, NULL, NULL, true)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$;

-- Revoke direct execution privileges to prevent manual triggering
REVOKE EXECUTE ON FUNCTION public.fn_handle_new_auth_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_handle_new_auth_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_handle_new_auth_user() FROM authenticated;

CREATE TRIGGER trg_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_handle_new_auth_user();

-- 4. Minimal Phase 4 Privilege Safety
REVOKE ALL ON TABLE public.profiles FROM PUBLIC;
REVOKE ALL ON TABLE public.profiles FROM anon;
REVOKE ALL ON TABLE public.profiles FROM authenticated;

-- Allow database owner and service_role to administer the table
GRANT ALL ON TABLE public.profiles TO postgres;
GRANT ALL ON TABLE public.profiles TO service_role;
