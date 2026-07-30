import { Route as RouteIcon } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";
import { Reveal } from "@/components/motion/Reveal";

export default async function DispatcherRoutesPage() {
  await requireRouteAccess(["DISPATCHER"]);

  return (
    <PageContainer>
      <PageHeader title="Routes" description="Directed hub-to-hub routes available for trip planning." />
      <Reveal>
        <EmptyState
          icon={RouteIcon}
          title="Route management arrives in Phase 17"
          description="Multi-hop route planning and management is not implemented yet."
        />
      </Reveal>
    </PageContainer>
  );
}
