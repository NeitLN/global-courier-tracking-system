import { Gauge } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";

export default async function AnalyticsSlaPage() {
  await requireRouteAccess(["ANALYST"]);

  return (
    <PageContainer>
      <PageHeader title="SLA Compliance" description="Delivery SLA performance across service tiers." />
      <EmptyState
        icon={Gauge}
        title="SLA compliance reporting arrives in Phase 16"
        description="This view will render results from fn_sla_compliance once SLA compliance tracking is implemented."
      />
    </PageContainer>
  );
}
