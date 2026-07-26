import { Clock3 } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";
import { Alert } from "@/components/ui/Alert";

export default async function AnalyticsDriversPage() {
  await requireRouteAccess(["ANALYST"]);

  return (
    <PageContainer>
      <PageHeader title="Driver Performance" description="Driver ranking by delivery outcomes." />
      <Alert tone="warning" title="Access scope still pending backend confirmation">
        The approved <code>fn_rank_driver_performance</code> RPC is currently DISPATCHER-only at the
        database layer. This page renders no data yet; access here will be finalized alongside Phase
        15 without ever exposing driver phone numbers or license details.
      </Alert>
      <EmptyState
        icon={Clock3}
        title="Driver performance reporting arrives in Phase 15"
        description="This view will render results from an approved analytics RPC once driver performance reporting is implemented."
      />
    </PageContainer>
  );
}
