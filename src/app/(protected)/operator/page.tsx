import Link from "next/link";
import { ScanLine, ClipboardList, PackageX } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardContent } from "@/components/ui/Card";
import { StaggerList, StaggerItem } from "@/components/motion/StaggerList";

const MODULES = [
  { label: "Record Scan", href: "/operator/scans", icon: ScanLine, description: "Log a checkpoint scan at your hub." },
  { label: "Current Inventory", href: "/operator/inventory", icon: ClipboardList, description: "Packages currently at your hub." },
  { label: "Delivery Attempts", href: "/operator/delivery-attempts", icon: PackageX, description: "Recorded delivery outcomes." },
];

export default async function OperatorOverviewPage() {
  await requireRouteAccess(["HUB_OPERATOR"]);

  return (
    <PageContainer>
      <PageHeader title="Hub Operations" description="Tools for your assigned transit hub." />
      <StaggerList className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {MODULES.map((module) => {
          const Icon = module.icon;
          return (
            <StaggerItem key={module.href}>
              <Link href={module.href}>
                <Card className="card-interactive h-full transition-colors hover:border-primary/40 hover:bg-muted/40">
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
            </StaggerItem>
          );
        })}
      </StaggerList>
    </PageContainer>
  );
}
