import { Car } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";
import { Reveal } from "@/components/motion/Reveal";

export default async function DispatcherVehiclesPage() {
  await requireRouteAccess(["DISPATCHER"]);

  return (
    <PageContainer>
      <PageHeader title="Vehicles" description="Fleet roster and capacity." />
      <Reveal>
        <EmptyState
          icon={Car}
          title="Vehicle assignment tools arrive in Phase 11"
          description="This page will support real vehicle assignment once trip and leg assignment RPCs are implemented."
        />
      </Reveal>
    </PageContainer>
  );
}
