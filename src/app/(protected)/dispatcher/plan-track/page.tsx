import { Map } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";

export default async function PlanTrackPage() {
  await requireRouteAccess(["DISPATCHER"]);

  return (
    <PageContainer>
      <PageHeader
        title="Plan & Track"
        description="Assign unassigned shipments to scheduled trips: unassigned packages, scheduled trips, and selected trip details."
      />
      <EmptyState
        icon={Map}
        title="Trip and leg assignment arrives in Phase 11"
        description="The three-column planning board (unassigned shipments, scheduled trips, trip detail) is not implemented yet. Drag-and-drop assignment belongs to Phase 10."
      />
    </PageContainer>
  );
}
