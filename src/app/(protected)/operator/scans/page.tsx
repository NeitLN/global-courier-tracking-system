import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Alert } from "@/components/ui/Alert";
import { ScanForm } from "./ScanForm";
import { Reveal } from "@/components/motion/Reveal";

export const dynamic = "force-dynamic";

export default async function OperatorScansPage() {
  const auth = await requireRouteAccess(["HUB_OPERATOR"]);
  const staffId = auth.staffId;

  if (!staffId) {
    return (
      <PageContainer>
        <PageHeader title="Record Scan" description="Log a checkpoint scan for a package at your hub." />
        <Alert tone="danger" title="Account Mismatch">
          Your active profile is assigned as a Hub Operator, but is not linked to any row in the <code>staff</code> table. An administrator must link your profile to a staff member.
        </Alert>
      </PageContainer>
    );
  }

  const supabase = await createClient();
  const { data: staff, error } = await supabase
    .from("staff")
    .select(`
      full_name,
      transit_hub (
        hub_code,
        hub_name
      )
    `)
    .eq("staff_id", staffId)
    .single();

  if (error || !staff) {
    return (
      <PageContainer>
        <PageHeader title="Record Scan" description="Log a checkpoint scan for a package at your hub." />
        <Alert tone="danger" title="Staff Data Error">
          Could not retrieve your staff record or assigned hub details from the database. Please verify your account setup.
        </Alert>
      </PageContainer>
    );
  }

  // Cast transit_hub relation
  const hubRelation = staff.transit_hub as unknown as { hub_code: string; hub_name: string }[] | { hub_code: string; hub_name: string } | null;
  const hub = Array.isArray(hubRelation) ? hubRelation[0] : hubRelation;

  return (
    <PageContainer className="max-w-3xl">
      <PageHeader
        title="Record Scan"
        description="Log a checkpoint scan. The transaction, status sequence checks, and hub authorizations are strictly validated by PostgreSQL database triggers and RLS policies."
      />
      <Reveal>
        <ScanForm
          staffName={staff.full_name}
          hubCode={hub?.hub_code || "UNKNOWN"}
          hubName={hub?.hub_name || "Unknown Hub"}
        />
      </Reveal>
    </PageContainer>
  );
}
