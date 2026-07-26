import Link from "next/link";
import { Clock } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { APP_ROLES, ROLE_LABELS } from "@/lib/auth/roles";
import { getNavForRole } from "@/lib/navigation/nav-config";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardContent } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";

const ROLE_DESCRIPTIONS: Record<(typeof APP_ROLES)[number], string> = {
  CUSTOMER: "Track and manage packages you send or receive.",
  HUB_OPERATOR: "Record checkpoint scans and manage inventory at your assigned hub.",
  DISPATCHER: "Plan trips, assign packages to routes, and oversee network operations.",
  ANALYST: "Review SLA compliance, hub throughput, and driver performance analytics.",
};

export default async function DashboardPage() {
  const auth = await requireRouteAccess(APP_ROLES);
  const shortcuts = getNavForRole(auth.appRole).filter(
    (item) => item.label !== "Dashboard" && item.label !== "Profile",
  );

  return (
    <PageContainer>
      <PageHeader
        title={`Welcome back${auth.displayName ? `, ${auth.displayName}` : ""}`}
        description={ROLE_DESCRIPTIONS[auth.appRole]}
      />

      {shortcuts.length > 0 && (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {shortcuts.map((item) => {
            const Icon = item.icon;
            return (
              <Link key={item.label} href={item.href}>
                <Card className="h-full transition-colors hover:border-primary/40 hover:bg-muted/40">
                  <CardContent className="flex items-center gap-3">
                    <span className="flex size-9 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary">
                      <Icon className="size-5" aria-hidden="true" />
                    </span>
                    <div>
                      <p className="text-sm font-medium text-foreground">{item.label}</p>
                      <p className="text-caption">
                        {item.children ? `${item.children.length} sections` : "Open module"}
                      </p>
                    </div>
                  </CardContent>
                </Card>
              </Link>
            );
          })}
        </div>
      )}

      <EmptyState
        icon={Clock}
        title="Data widgets arrive in a later phase"
        description="Live KPI cards for this dashboard (package volume, SLA compliance, hub throughput) are wired up once the operational RPC integrations land, starting in Phase 12. This shell intentionally shows no fabricated numbers in the meantime."
      />

      <p className="text-caption">
        Signed in as {ROLE_LABELS[auth.appRole]}.
      </p>
    </PageContainer>
  );
}
