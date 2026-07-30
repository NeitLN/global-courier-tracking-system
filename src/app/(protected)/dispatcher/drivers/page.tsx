import { UserRound } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";
import { Reveal } from "@/components/motion/Reveal";

export default async function DispatcherDriversPage() {
  await requireRouteAccess(["DISPATCHER"]);

  return (
    <PageContainer>
      <PageHeader title="Drivers" description="Driver roster and current availability." />
      <Reveal>
        <EmptyState
          icon={UserRound}
          title="Driver assignment tools arrive in Phase 11"
          description="This page will support real driver/vehicle assignment once trip and leg assignment RPCs are implemented."
        />
      </Reveal>
    </PageContainer>
  );
}
