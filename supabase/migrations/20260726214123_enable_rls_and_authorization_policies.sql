-- MIGRATION 4: Table Privileges, RLS, and Policies

-- A. Remove Ambient Privileges
REVOKE ALL PRIVILEGES ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.status_code FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.service_type FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.customer FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.transit_hub FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.staff FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.driver FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.vehicle FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.route FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.package FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.tracking_event FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.trip FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.package_leg FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.delivery_attempt FROM PUBLIC, anon, authenticated;

-- Explicit Admin Grants for service_role and postgres
GRANT ALL PRIVILEGES ON TABLE public.profiles TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.status_code TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.service_type TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.customer TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.transit_hub TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.staff TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.driver TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.vehicle TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.route TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.package TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.tracking_event TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.trip TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.package_leg TO postgres, service_role;
GRANT ALL PRIVILEGES ON TABLE public.delivery_attempt TO postgres, service_role;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO postgres, service_role;

-- C. Authenticated SELECT Grants (no driver, no vehicle)
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT SELECT ON TABLE public.status_code TO authenticated;
GRANT SELECT ON TABLE public.service_type TO authenticated;
GRANT SELECT ON TABLE public.customer TO authenticated;
GRANT SELECT ON TABLE public.transit_hub TO authenticated;
GRANT SELECT ON TABLE public.staff TO authenticated;
GRANT SELECT ON TABLE public.route TO authenticated;
GRANT SELECT ON TABLE public.package TO authenticated;
GRANT SELECT ON TABLE public.tracking_event TO authenticated;
GRANT SELECT ON TABLE public.trip TO authenticated;
GRANT SELECT ON TABLE public.package_leg TO authenticated;
GRANT SELECT ON TABLE public.delivery_attempt TO authenticated;

-- B. Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.status_code ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transit_hub ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracking_event ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_leg ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_attempt ENABLE ROW LEVEL SECURITY;

-- D. Exact SELECT Policies

-- 1. profiles_self_select
CREATE POLICY profiles_self_select ON public.profiles
    FOR SELECT TO authenticated
    USING (user_id = (select auth.uid()));

-- 2. status_code_active_assigned_select
CREATE POLICY status_code_active_assigned_select ON public.status_code
    FOR SELECT TO authenticated
    USING ((select authz_private.is_active_user()) AND (select authz_private.current_app_role()) IS NOT NULL);

-- 3. service_type_active_assigned_select
CREATE POLICY service_type_active_assigned_select ON public.service_type
    FOR SELECT TO authenticated
    USING ((select authz_private.is_active_user()) AND (select authz_private.current_app_role()) IS NOT NULL);

-- 4. transit_hub_active_assigned_select
CREATE POLICY transit_hub_active_assigned_select ON public.transit_hub
    FOR SELECT TO authenticated
    USING ((select authz_private.is_active_user()) AND (select authz_private.current_app_role()) IS NOT NULL);

-- 5. customer_customer_self_select
CREATE POLICY customer_customer_self_select ON public.customer
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'CUSTOMER'
        AND customer_id = (select authz_private.current_customer_id())
    );

-- 6. staff_hub_operator_self_select
CREATE POLICY staff_hub_operator_self_select ON public.staff
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'HUB_OPERATOR'
        AND staff_id = (select authz_private.current_staff_id())
    );

-- 7. route_dispatcher_analyst_select
CREATE POLICY route_dispatcher_analyst_select ON public.route
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) IN ('DISPATCHER', 'ANALYST')
    );

-- 8. package_customer_select
CREATE POLICY package_customer_select ON public.package
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'CUSTOMER'
        AND (
            sender_id = (select authz_private.current_customer_id())
            OR receiver_id = (select authz_private.current_customer_id())
        )
    );

-- 9. package_hub_operator_select
CREATE POLICY package_hub_operator_select ON public.package
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'HUB_OPERATOR'
        AND (
            origin_hub_id = (select authz_private.current_staff_hub())
            OR dest_hub_id = (select authz_private.current_staff_hub())
            OR (select authz_private.latest_package_hub(package_id)) = (select authz_private.current_staff_hub())
        )
    );

-- 10. package_dispatcher_select
CREATE POLICY package_dispatcher_select ON public.package
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'DISPATCHER'
    );

-- 11. tracking_event_customer_select
CREATE POLICY tracking_event_customer_select ON public.tracking_event
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'CUSTOMER'
        AND (select authz_private.current_user_owns_package(package_id))
    );

-- 12. tracking_event_hub_operator_select
CREATE POLICY tracking_event_hub_operator_select ON public.tracking_event
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'HUB_OPERATOR'
        AND hub_id = (select authz_private.current_staff_hub())
    );

-- 13. tracking_event_dispatcher_select
CREATE POLICY tracking_event_dispatcher_select ON public.tracking_event
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'DISPATCHER'
    );

-- 14. trip_dispatcher_select
CREATE POLICY trip_dispatcher_select ON public.trip
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'DISPATCHER'
    );

-- 15. package_leg_customer_select
CREATE POLICY package_leg_customer_select ON public.package_leg
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'CUSTOMER'
        AND (select authz_private.current_user_owns_package(package_id))
    );

-- 16. package_leg_dispatcher_select
CREATE POLICY package_leg_dispatcher_select ON public.package_leg
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'DISPATCHER'
    );

-- 17. delivery_attempt_customer_select
CREATE POLICY delivery_attempt_customer_select ON public.delivery_attempt
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'CUSTOMER'
        AND (select authz_private.current_user_owns_package(package_id))
    );

-- 18. delivery_attempt_dispatcher_select
CREATE POLICY delivery_attempt_dispatcher_select ON public.delivery_attempt
    FOR SELECT TO authenticated
    USING (
        (select authz_private.is_active_user())
        AND (select authz_private.current_app_role()) = 'DISPATCHER'
    );
