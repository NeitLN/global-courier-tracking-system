import { ScanLine } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";

export default async function OperatorScansPage() {
  await requireRouteAccess(["HUB_OPERATOR"]);

  return (
    <PageContainer>
      <PageHeader title="Record Scan" description="Log a checkpoint scan for a package at your hub." />
      <EmptyState
        icon={ScanLine}
        title="Checkpoint scanning arrives in Phase 12"
        description="This form will call the approved fn_record_checkpoint_scan RPC once scan workflows are implemented. It does not submit anything yet."
      />
    </PageContainer>
  );
}
