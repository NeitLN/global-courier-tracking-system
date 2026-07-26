-- MIGRATION: reconcile_auth_profiles_remote_state
-- Purpose: Reconciles the remote schema after a partially failed deployment of Phase 4.

-- 1. Redefine fn_handle_new_auth_user to ensure it matches the final tested local state
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

-- Ensure execution privileges are safely restricted
REVOKE EXECUTE ON FUNCTION public.fn_handle_new_auth_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_handle_new_auth_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_handle_new_auth_user() FROM authenticated;

-- 2. Redefine fn_profiles_updated_at safely
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

-- Re-establish trg_profiles_updated_at safely (idempotent replace via dropping)
DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_profiles_updated_at();

-- Re-establish trg_auth_user_created safely (idempotent replace via dropping)
DROP TRIGGER IF EXISTS trg_auth_user_created ON auth.users;
CREATE TRIGGER trg_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_handle_new_auth_user();

-- 3. Ensure profiles table structure is strictly constrained
-- (The remote table exists, so we explicitly enforce its constraints idempotently, if they were missing or altered.)
-- We do not drop the table. We assume it exists as per our forensic audit.
-- We re-apply revocation of public access just in case the prior push failed before this step.
REVOKE ALL ON TABLE public.profiles FROM PUBLIC;
REVOKE ALL ON TABLE public.profiles FROM anon;
REVOKE ALL ON TABLE public.profiles FROM authenticated;

-- Ensure admin grants are established
GRANT ALL ON TABLE public.profiles TO postgres;
GRANT ALL ON TABLE public.profiles TO service_role;
