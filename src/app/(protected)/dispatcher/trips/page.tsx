import { Truck } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";

export default async function TripsPage() {
  await requireRouteAccess(["DISPATCHER"]);

  return (
    <PageContainer>
      <PageHeader title="Trips" description="Scheduled and in-progress trips across the network." />
      <EmptyState
        icon={Truck}
        title="Trip creation and assignment arrives in Phase 11"
        description="This page will list real trips once trip and leg assignment RPCs are implemented."
      />
    </PageContainer>
  );
}
