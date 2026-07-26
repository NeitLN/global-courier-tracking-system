import { BarChart3 } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";

export default async function AnalyticsHubsPage() {
  await requireRouteAccess(["ANALYST"]);

  return (
    <PageContainer>
      <PageHeader title="Hub Analysis" description="Inter-scan interval analysis by hub." />
      <EmptyState
        icon={BarChart3}
        title="Hub analytics charts arrive in Phase 14"
        description="This view will render results from fn_inter_scan_hub_analysis once hub inventory and transit analytics are implemented. Charting (Recharts) is introduced in Phase 11–12, not before."
      />
    </PageContainer>
  );
}
