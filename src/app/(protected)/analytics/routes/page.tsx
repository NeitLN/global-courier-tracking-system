import { Route as RouteIcon } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";

export default async function AnalyticsRoutesPage() {
  await requireRouteAccess(["ANALYST"]);

  return (
    <PageContainer>
      <PageHeader title="Route Explorer" description="Multi-hop route discovery between hubs." />
      <EmptyState
        icon={RouteIcon}
        title="Route exploration arrives in Phase 17"
        description="This view will render results from fn_find_routes once multi-hop route planning is implemented."
      />
    </PageContainer>
  );
}
