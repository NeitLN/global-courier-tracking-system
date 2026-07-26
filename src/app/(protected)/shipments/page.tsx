import { Package } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";

export default async function ShipmentsPage() {
  const auth = await requireRouteAccess(["CUSTOMER", "DISPATCHER"]);
  const isCustomer = auth.appRole === "CUSTOMER";

  return (
    <PageContainer>
      <PageHeader
        title={isCustomer ? "My Shipments" : "Shipments"}
        description={
          isCustomer
            ? "Packages you have sent or are receiving."
            : "All packages currently moving through the network."
        }
      />
      <EmptyState
        icon={Package}
        title="Package registration and tracking arrive in Phase 8"
        description="This page will list real shipments once the register-package and track-package RPCs are wired up. No sample records are shown here."
      />
    </PageContainer>
  );
}
