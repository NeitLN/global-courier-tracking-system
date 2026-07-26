import { Route as RouteIcon } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";

export default async function DispatcherRoutesPage() {
  await requireRouteAccess(["DISPATCHER"]);

  return (
    <PageContainer>
      <PageHeader title="Routes" description="Directed hub-to-hub routes available for trip planning." />
      <EmptyState
        icon={RouteIcon}
        title="Route management arrives in Phase 17"
        description="Multi-hop route planning and management is not implemented yet."
      />
    </PageContainer>
  );
}
