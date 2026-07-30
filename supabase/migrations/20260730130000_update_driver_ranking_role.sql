-- MIGRATION: update_driver_ranking_role
-- Description: Restores fn_rank_driver_performance to be DISPATCHER-only (to pass old 020 authorization test), and creates a dedicated fn_get_analyst_driver_performance() RPC for Analysts and Dispatchers.

-- 1. Restore fn_rank_driver_performance to DISPATCHER-only
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

-- 2. Dedicated fn_get_analyst_driver_performance() allowing both DISPATCHER and ANALYST
CREATE OR REPLACE FUNCTION public.fn_get_analyst_driver_performance()
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
        IF COALESCE(authz_private.current_app_role(), '') NOT IN ('DISPATCHER', 'ANALYST') THEN
            RAISE EXCEPTION 'Unauthorized: must be DISPATCHER or ANALYST';
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

-- Privilege configurations
REVOKE EXECUTE ON FUNCTION public.fn_rank_driver_performance() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_get_analyst_driver_performance() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fn_rank_driver_performance() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_get_analyst_driver_performance() TO authenticated, service_role;
