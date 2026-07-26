import Link from "next/link";
import { BarChart3, Clock3, Gauge, Route as RouteIcon } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardContent } from "@/components/ui/Card";

const MODULES = [
  { label: "Hub Analysis", href: "/analytics/hubs", icon: BarChart3, description: "Inter-scan interval analysis by hub." },
  { label: "SLA Compliance", href: "/analytics/sla", icon: Gauge, description: "Delivery SLA performance." },
  { label: "Driver Performance", href: "/analytics/drivers", icon: Clock3, description: "Driver ranking by delivery outcomes." },
  { label: "Route Explorer", href: "/analytics/routes", icon: RouteIcon, description: "Multi-hop route discovery." },
];

export default async function AnalyticsOverviewPage() {
  await requireRouteAccess(["ANALYST"]);

  return (
    <PageContainer>
      <PageHeader title="Analytics" description="Reporting views backed by approved read-only RPCs." />
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {MODULES.map((module) => {
          const Icon = module.icon;
          return (
            <Link key={module.href} href={module.href}>
              <Card className="h-full transition-colors hover:border-primary/40 hover:bg-muted/40">
                <CardContent className="flex flex-col items-start gap-2">
                  <span className="flex size-9 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary">
                    <Icon className="size-5" aria-hidden="true" />
                  </span>
                  <p className="text-sm font-medium text-foreground">{module.label}</p>
                  <p className="text-caption">{module.description}</p>
                </CardContent>
              </Card>
            </Link>
          );
        })}
      </div>
    </PageContainer>
  );
}
