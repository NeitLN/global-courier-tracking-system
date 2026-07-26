import type { ReactNode } from "react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { AppShell } from "@/components/layout/AppShell";

export const dynamic = "force-dynamic";

/**
 * Base gate for every page under the (protected) group: unauthenticated
 * visitors go to /login, and any account that is missing a profile,
 * unassigned, or inactive is sent to /account (which explains that state).
 * Role-specific restrictions are layered on top per-page via the same
 * `requireRouteAccess` helper — this layout only enforces "is there an
 * active, assigned profile at all".
 */
export default async function ProtectedLayout({ children }: { children: ReactNode }) {
  const auth = await requireRouteAccess();

  return (
    <AppShell role={auth.appRole} displayName={auth.displayName} email={auth.email}>
      {children}
    </AppShell>
  );
}
