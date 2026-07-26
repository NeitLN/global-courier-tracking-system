import { redirect } from "next/navigation";
import { getAuthContext, type AuthContext } from "./auth-context";
import type { AppRole } from "./roles";

export type ActiveAuthContext = Extract<AuthContext, { status: "active" }>;

export type RouteAccessResult =
  | { allowed: true; context: ActiveAuthContext }
  | { allowed: false; redirectTo: "/login" | "/account" | "/unauthorized" };

/**
 * The single, centralized authorization decision for every protected route.
 * Page and layout components must call this (directly or via
 * `requireRouteAccess`) instead of re-implementing role checks locally.
 *
 * - unauthenticated            -> /login
 * - no profile / unassigned / inactive -> /account (that page explains the
 *   specific state; it never renders operational content)
 * - active but wrong role      -> /unauthorized
 * - active with an allowed role (or no role restriction supplied) -> render
 */
export function resolveRouteAccess(
  auth: AuthContext,
  allowedRoles?: readonly AppRole[],
): RouteAccessResult {
  if (auth.status === "unauthenticated") {
    return { allowed: false, redirectTo: "/login" };
  }

  if (auth.status !== "active") {
    return { allowed: false, redirectTo: "/account" };
  }

  if (allowedRoles && !allowedRoles.includes(auth.appRole)) {
    return { allowed: false, redirectTo: "/unauthorized" };
  }

  return { allowed: true, context: auth };
}

/**
 * Server Component / Server Action convenience wrapper: resolves the
 * current auth context and redirects immediately if access is denied,
 * otherwise returns the active context for the caller to use.
 */
export async function requireRouteAccess(
  allowedRoles?: readonly AppRole[],
): Promise<ActiveAuthContext> {
  const auth = await getAuthContext();
  const result = resolveRouteAccess(auth, allowedRoles);

  if (!result.allowed) {
    redirect(result.redirectTo);
  }

  return result.context;
}
