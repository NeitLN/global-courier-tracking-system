"use client";

import { usePathname } from "next/navigation";
import { Bell } from "lucide-react";
import type { AppRole } from "@/lib/auth/roles";
import { buildBreadcrumbs } from "@/lib/navigation/nav-config";
import { Breadcrumbs } from "./Breadcrumbs";
import { RoleBadge } from "./RoleBadge";
import { UserMenu } from "./UserMenu";
import { MobileNavigation } from "./MobileNavigation";

export interface AppHeaderProps {
  role: AppRole;
  displayName: string | null;
  email: string | null;
}

export function AppHeader({ role, displayName, email }: AppHeaderProps) {
  const pathname = usePathname();
  // Rendered on both server and client; a date-only label can only mismatch
  // in the rare case of a request crossing local midnight, which is cosmetic
  // and not worth a client-only effect.
  const today = new Date().toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  });

  return (
    <header className="flex h-14 shrink-0 items-center justify-between gap-3 border-b border-border bg-card px-4">
      <div className="flex min-w-0 items-center gap-3">
        <MobileNavigation role={role} />
        <Breadcrumbs items={buildBreadcrumbs(pathname)} />
      </div>

      <div className="flex items-center gap-3">
        <span className="hidden text-caption md:inline" suppressHydrationWarning>
          {today}
        </span>

        <button
          type="button"
          disabled
          title="Notifications are not yet available"
          aria-label="Notifications (not yet available)"
          className="relative hidden rounded-md p-2 text-muted-foreground opacity-60 sm:inline-flex"
        >
          <Bell className="size-5" aria-hidden="true" />
        </button>

        <RoleBadge role={role} className="hidden md:inline-flex" />

        <UserMenu displayName={displayName} email={email} role={role} />
      </div>
    </header>
  );
}
