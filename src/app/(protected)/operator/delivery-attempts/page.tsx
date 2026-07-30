import { PackageX } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Alert } from "@/components/ui/Alert";
import { Badge } from "@/components/ui/Badge";
import { formatDateTime } from "@/lib/courier/format";
import { courierErrorMessage } from "@/lib/courier/errors";
import { DeliveryAttemptForm } from "./DeliveryAttemptForm";
import { DataTableShell } from "@/components/ui/DataTableShell";
import { Reveal } from "@/components/motion/Reveal";

export const dynamic = "force-dynamic";

interface DriverRow {
  driver_id: number;
  full_name: string;
  license_no: string;
}

interface AttemptRow {
  delivery_attempt_id: number;
  attempt_time: string;
  outcome: string;
  failure_reason: string | null;
  notes: string | null;
  package: { tracking_no: string };
  driver: { full_name: string; license_no: string };
}

interface HubDeliveryAttemptRow {
  delivery_attempt_id: number;
  attempt_time: string;
  outcome: string;
  failure_reason: string | null;
  notes: string | null;
  tracking_no: string;
  driver_name: string;
  driver_license: string;
}

export default async function OperatorDeliveryAttemptsPage() {
  const auth = await requireRouteAccess(["HUB_OPERATOR"]);
  const staffId = auth.staffId;

  if (!staffId) {
    return (
      <PageContainer>
        <PageHeader title="Delivery Attempts" description="Recorded delivery outcomes for your hub's drivers." />
        <Alert tone="danger" title="Account Mismatch">
          Your active profile is assigned as a Hub Operator, but is not linked to any row in the <code>staff</code> table.
        </Alert>
      </PageContainer>
    );
  }

  const supabase = await createClient();

  // 1. Fetch staff details and transit hub
  const { data: staff, error: staffError } = await supabase
    .from("staff")
    .select(`
      full_name,
      hub_id,
      transit_hub (
        hub_code,
        hub_name
      )
    `)
    .eq("staff_id", staffId)
    .single();

  if (staffError || !staff) {
    return (
      <PageContainer>
        <PageHeader title="Delivery Attempts" description="Recorded delivery outcomes for your hub's drivers." />
        <Alert tone="danger" title="Staff Data Error">
          Could not retrieve your staff record or assigned hub details from the database.
        </Alert>
      </PageContainer>
    );
  }

  const hubId = staff.hub_id;
  const hubRelation = staff.transit_hub as unknown as { hub_code: string; hub_name: string }[] | { hub_code: string; hub_name: string } | null;
  const hub = Array.isArray(hubRelation) ? hubRelation[0] : hubRelation;

  // 2. Fetch drivers based at this hub via RPC (direct SELECT on PII table "driver" is restricted under security policies)
  const { data: drivers, error: driversError } = await supabase.rpc("fn_get_hub_drivers", {
    p_hub_id: hubId,
  });

  if (driversError) {
    return (
      <PageContainer>
        <PageHeader title="Delivery Attempts" description="Recorded delivery outcomes for your hub's drivers." />
        <Alert tone="danger" title="Database Error">
          Could not load the drivers for your hub: {courierErrorMessage(driversError.message, "OPERATOR_GET_HUB_DRIVERS", auth.userId)}
        </Alert>
      </PageContainer>
    );
  }

  // 3. Fetch previous delivery attempts for drivers at this hub via RPC (direct SELECT/JOIN on "driver" is restricted under security policies)
  const { data: attempts, error: attemptsError } = await supabase.rpc("fn_get_hub_delivery_attempts", {
    p_hub_id: hubId,
    p_limit: 50,
  });

  const typedDrivers = (drivers || []) as DriverRow[];
  const typedAttempts = ((attempts || []) as HubDeliveryAttemptRow[]).map((att) => ({
    delivery_attempt_id: Number(att.delivery_attempt_id),
    attempt_time: att.attempt_time,
    outcome: att.outcome,
    failure_reason: att.failure_reason,
    notes: att.notes,
    package: { tracking_no: att.tracking_no },
    driver: { full_name: att.driver_name, license_no: att.driver_license },
  })) as AttemptRow[];

  return (
    <PageContainer>
      <PageHeader
        title="Delivery Attempts"
        description="Record and view delivery outcomes for your hub's drivers. Constraints, transactional rules, and failure reasons are validated directly by PostgreSQL."
      />

      <div className="grid gap-6 lg:grid-cols-3">
        {/* Left column: Form */}
        <div className="lg:col-span-1">
          {typedDrivers.length === 0 ? (
            <Alert tone="warning" title="No drivers available">
              No drivers are currently assigned to your hub ({hub?.hub_name}). You cannot record delivery attempts until drivers are assigned to this hub.
            </Alert>
          ) : (
            <DeliveryAttemptForm
              drivers={typedDrivers}
              hubCode={hub?.hub_code || "UNK"}
              hubName={hub?.hub_name || "Unknown Hub"}
            />
          )}
        </div>

        {/* Right column: List of previous attempts */}
        <div className="lg:col-span-2 space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Recent Attempts at Your Hub</CardTitle>
            </CardHeader>
            <CardContent>
              {attemptsError && (
                <Alert tone="danger" title="Could not load attempts">
                  {courierErrorMessage(attemptsError.message, "OPERATOR_GET_HUB_DELIVERY_ATTEMPTS", auth.userId)}
                </Alert>
              )}

              {!attemptsError && typedAttempts.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-12 text-center text-muted-foreground">
                  <PackageX className="size-12 text-muted-foreground/30 mb-3" />
                  <p className="text-sm font-semibold">No delivery attempts recorded yet</p>
                  <p className="text-xs mt-1">Use the form to record the first outcome.</p>
                </div>
              ) : (
                <Reveal>
                  <DataTableShell
                    columns={["Package", "Driver", "Outcome", "Attempt Time", "Details / Reasons"]}
                    caption="Recent delivery attempts at your hub"
                  >
                    {typedAttempts.map((attempt) => (
                      <tr key={attempt.delivery_attempt_id} className="transition-colors duration-150 hover:bg-muted/40">
                        <td className="px-3 py-3 font-mono font-medium text-foreground">
                          {attempt.package?.tracking_no}
                        </td>
                        <td className="px-3 py-3">
                          <div className="font-medium text-foreground">{attempt.driver?.full_name}</div>
                          <div className="text-xs text-muted-foreground">{attempt.driver?.license_no}</div>
                        </td>
                        <td className="px-3 py-3">
                          <Badge tone={attempt.outcome === "SUCCESS" ? "success" : "danger"}>
                            {attempt.outcome}
                          </Badge>
                        </td>
                        <td className="px-3 py-3 text-muted-foreground">
                          {formatDateTime(attempt.attempt_time)}
                        </td>
                        <td className="px-3 py-3 text-xs text-muted-foreground max-w-xs truncate">
                          {attempt.outcome === "FAILED" && (
                            <p className="font-semibold text-danger-foreground">
                              Reason: {attempt.failure_reason}
                            </p>
                          )}
                          {attempt.notes && <p className="italic">Note: {attempt.notes}</p>}
                        </td>
                      </tr>
                    ))}
                  </DataTableShell>
                </Reveal>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </PageContainer>
  );
}
