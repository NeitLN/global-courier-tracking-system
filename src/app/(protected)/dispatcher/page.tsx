import Link from "next/link";
import { Map, Truck, Route as RouteIcon, UserRound, Car } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardContent } from "@/components/ui/Card";

const MODULES = [
  { label: "Plan & Track", href: "/dispatcher/plan-track", icon: Map, description: "Assign unassigned packages to scheduled trips." },
  { label: "Trips", href: "/dispatcher/trips", icon: Truck, description: "Scheduled and in-progress trips." },
  { label: "Routes", href: "/dispatcher/routes", icon: RouteIcon, description: "Directed hub-to-hub routes." },
  { label: "Drivers", href: "/dispatcher/drivers", icon: UserRound, description: "Driver roster and availability." },
  { label: "Vehicles", href: "/dispatcher/vehicles", icon: Car, description: "Fleet roster and capacity." },
];

export default async function DispatcherOverviewPage() {
  await requireRouteAccess(["DISPATCHER"]);

  return (
    <PageContainer>
      <PageHeader title="Dispatcher Overview" description="Network-wide operational tools." />
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {MODULES.map((module) => {
          const Icon = module.icon;
          return (
            <Link key={module.href} href={module.href}>
              <Card className="h-full transition-colors hover:border-primary/40 hover:bg-muted/40">
                <CardContent className="flex items-start gap-3">
                  <span className="flex size-9 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary">
                    <Icon className="size-5" aria-hidden="true" />
                  </span>
                  <div>
                    <p className="text-sm font-medium text-foreground">{module.label}</p>
                    <p className="text-caption">{module.description}</p>
                  </div>
                </CardContent>
              </Card>
            </Link>
          );
        })}
      </div>
    </PageContainer>
  );
}
