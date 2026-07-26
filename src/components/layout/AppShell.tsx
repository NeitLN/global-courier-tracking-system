import type { ReactNode } from "react";
import type { AppRole } from "@/lib/auth/roles";
import { AppSidebar } from "./AppSidebar";
import { AppHeader } from "./AppHeader";

export interface AppShellProps {
  role: AppRole;
  displayName: string | null;
  email: string | null;
  children: ReactNode;
}

/**
 * The shared authenticated application shell: sidebar + header + main
 * content area. Navigation is role-derived for usability only — every
 * route rendered inside `children` must still enforce its own access via
 * `requireRouteAccess` server-side.
 *
 * Only `role` (a plain string) crosses the Server -> Client Component
 * boundary here — AppSidebar/AppHeader/MobileNavigation each resolve their
 * own nav items from it internally. Nav items carry Lucide icon component
 * references, which cannot be serialized as props across that boundary.
 */
export function AppShell({ role, displayName, email, children }: AppShellProps) {
  return (
    <div className="flex h-dvh min-h-0 w-full overflow-hidden bg-background">
      <AppSidebar role={role} />
      <div className="flex min-w-0 flex-1 flex-col">
        <AppHeader role={role} displayName={displayName} email={email} />
        <main className="flex-1 overflow-y-auto">{children}</main>
      </div>
    </div>
  );
}
