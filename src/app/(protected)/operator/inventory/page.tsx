import { ClipboardList } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";

export default async function OperatorInventoryPage() {
  await requireRouteAccess(["HUB_OPERATOR"]);

  return (
    <PageContainer>
      <PageHeader title="Current Inventory" description="Packages currently held at your hub." />
      <EmptyState
        icon={ClipboardList}
        title="Hub inventory arrives in Phase 14"
        description="This table will list live results from the fn_current_hub_inventory RPC once hub inventory and transit analytics are implemented."
      />
    </PageContainer>
  );
}
