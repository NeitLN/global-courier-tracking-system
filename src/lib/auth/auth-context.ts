import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import { isAppRole, type AppRole } from "./roles";

interface ProfileRow {
  display_name: string | null;
  app_role: string | null;
  is_active: boolean;
  customer_id: number | null;
  staff_id: number | null;
}

/**
 * A discriminated union keyed on `status`, so that `status === "active"`
 * narrows `appRole` to a real `AppRole` (never null) at the type level —
 * not just at runtime.
 */
export type AuthContext =
  | {
      status: "unauthenticated";
      userId: null;
      email: null;
      displayName: null;
      appRole: null;
      isActive: false;
      customerId: null;
      staffId: null;
    }
  | {
      status: "no_profile";
      userId: string;
      email: string | null;
      displayName: null;
      appRole: null;
      isActive: false;
      customerId: null;
      staffId: null;
    }
  | {
      status: "inactive";
      userId: string;
      email: string | null;
      displayName: string | null;
      appRole: AppRole | null;
      isActive: false;
      customerId: number | null;
      staffId: number | null;
    }
  | {
      status: "unassigned";
      userId: string;
      email: string | null;
      displayName: string | null;
      appRole: null;
      isActive: true;
      customerId: number | null;
      staffId: number | null;
    }
  | {
      status: "active";
      userId: string;
      email: string | null;
      displayName: string | null;
      appRole: AppRole;
      isActive: true;
      customerId: number | null;
      staffId: number | null;
    };

export type AuthStatus = AuthContext["status"];

const UNAUTHENTICATED: AuthContext = {
  status: "unauthenticated",
  userId: null,
  email: null,
  displayName: null,
  appRole: null,
  isActive: false,
  customerId: null,
  staffId: null,
};

/**
 * Resolves the current request's authenticated profile context, server-side
 * only. Deliberately reads authorization exclusively from `public.profiles`
 * (the RLS-protected, trigger-provisioned table) — never from
 * `user.user_metadata`, which is client-suppliable at signup and carries no
 * authorization weight.
 *
 * Wrapped in React's `cache()` so a single request (e.g. the protected
 * layout plus the page it renders) only resolves this once.
 */
export const getAuthContext = cache(async (): Promise<AuthContext> => {
  const supabase = await createClient();
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return UNAUTHENTICATED;
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("display_name, app_role, is_active, customer_id, staff_id")
    .eq("user_id", user.id)
    .maybeSingle<ProfileRow>();

  if (profileError || !profile) {
    return {
      status: "no_profile",
      userId: user.id,
      email: user.email ?? null,
      displayName: null,
      appRole: null,
      isActive: false,
      customerId: null,
      staffId: null,
    };
  }

  if (!profile.is_active) {
    return {
      status: "inactive",
      userId: user.id,
      email: user.email ?? null,
      displayName: profile.display_name,
      appRole: isAppRole(profile.app_role) ? profile.app_role : null,
      isActive: false,
      customerId: profile.customer_id,
      staffId: profile.staff_id,
    };
  }

  if (!isAppRole(profile.app_role)) {
    return {
      status: "unassigned",
      userId: user.id,
      email: user.email ?? null,
      displayName: profile.display_name,
      appRole: null,
      isActive: true,
      customerId: profile.customer_id,
      staffId: profile.staff_id,
    };
  }

  return {
    status: "active",
    userId: user.id,
    email: user.email ?? null,
    displayName: profile.display_name,
    appRole: profile.app_role,
    isActive: true,
    customerId: profile.customer_id,
    staffId: profile.staff_id,
  };
});
