import { PackageX } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";

export default async function OperatorDeliveryAttemptsPage() {
  await requireRouteAccess(["HUB_OPERATOR"]);

  return (
    <PageContainer>
      <PageHeader title="Delivery Attempts" description="Recorded delivery outcomes for your hub's drivers." />
      <EmptyState
        icon={PackageX}
        title="Delivery attempt recording arrives in Phase 12"
        description="Failed and successful delivery attempts will appear here once checkpoint and delivery workflows are implemented."
      />
    </PageContainer>
  );
}
