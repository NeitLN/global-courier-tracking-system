import { Gauge } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { courierErrorMessage } from "@/lib/courier/errors";

export default async function AnalyticsSlaPage() {
  const auth = await requireRouteAccess(["ANALYST", "DISPATCHER"]);

  const supabase = await createClient();
  const { data: rawRecords = [], error } = await supabase.rpc("fn_sla_compliance");

  const records = (rawRecords || []) as Array<{
    package_id: number;
    tracking_no: string;
    service_name: string;
    registered_at: string;
    delivered_at: string | null;
    elapsed_hours: number | null;
    sla_hours: number;
    compliance_status: string;
  }>;

  // Safe SLA aggregation handling division-by-zero
  const total = records ? records.length : 0;
  const met = records ? records.filter((r) => r.compliance_status === "MET").length : 0;
  const breached = records ? records.filter((r) => r.compliance_status === "BREACHED").length : 0;
  const open = records ? records.filter((r) => r.compliance_status === "OPEN").length : 0;
  const returned = records ? records.filter((r) => r.compliance_status === "RETURNED").length : 0;

  const pctMet = total === 0 ? "0.0" : ((met / total) * 100).toFixed(1);
  const pctBreached = total === 0 ? "0.0" : ((breached / total) * 100).toFixed(1);

  return (
    <PageContainer>
      <PageHeader
        title="SLA Compliance"
        description="Delivery SLA compliance rates and tracking metrics across service tiers."
      />

      {/* Aggregate KPI Summary Row */}
      <div className="grid gap-4 md:grid-cols-4 mb-6">
        <Card>
          <CardContent className="pt-4 flex flex-col gap-1">
            <span className="text-caption">SLA COMPLIANCE RATE</span>
            <span className="text-2xl font-bold text-success">{pctMet}%</span>
            <span className="text-[10px] text-muted-foreground">{met} met out of {total} total</span>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-4 flex flex-col gap-1">
            <span className="text-caption">BREACH RATE</span>
            <span className="text-2xl font-bold text-danger">{pctBreached}%</span>
            <span className="text-[10px] text-muted-foreground">{breached} shipments breached</span>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-4 flex flex-col gap-1">
            <span className="text-caption">OPEN ORDERS</span>
            <span className="text-2xl font-bold text-primary">{open}</span>
            <span className="text-[10px] text-muted-foreground">In-progress transit</span>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-4 flex flex-col gap-1">
            <span className="text-caption">RETURNED ORDERS</span>
            <span className="text-2xl font-bold text-foreground">{returned}</span>
            <span className="text-[10px] text-muted-foreground">Returned to sender</span>
          </CardContent>
        </Card>
      </div>

      {/* SLA Manifest Table */}
      <Card>
        <CardHeader>
          <CardTitle>Shipment SLA Roster</CardTitle>
        </CardHeader>
        <CardContent>
          {error && (
            <div className="rounded-md bg-danger-soft p-3 text-sm text-danger-soft-foreground mb-4">
              Failed to load SLA records: {courierErrorMessage(error.message, "ANALYTICS_SLA_COMPLIANCE", auth.userId)}
            </div>
          )}

          {records && records.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/50 text-caption font-medium">
                    <th className="p-3">Tracking No</th>
                    <th className="p-3">Service Type</th>
                    <th className="p-3">Registered At</th>
                    <th className="p-3 text-right">Elapsed Time</th>
                    <th className="p-3 text-right">SLA Limit</th>
                    <th className="p-3 text-center pr-6">SLA Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {records.map((r) => (
                    <tr key={r.package_id} className="hover:bg-muted/20">
                      <td className="p-3 font-mono font-medium text-foreground">
                        {r.tracking_no}
                      </td>
                      <td className="p-3 text-foreground">{r.service_name}</td>
                      <td className="p-3 text-muted-foreground">
                        {new Date(r.registered_at).toLocaleString()}
                      </td>
                      <td className="p-3 text-right font-mono text-foreground font-medium">
                        {r.elapsed_hours}h
                      </td>
                      <td className="p-3 text-right font-mono text-muted-foreground">
                        {r.sla_hours}h
                      </td>
                      <td className="p-3 text-center pr-6">
                        <span
                          className={`rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase ${
                            r.compliance_status === "MET"
                              ? "bg-success-soft text-success-soft-foreground"
                              : r.compliance_status === "BREACHED"
                                ? "bg-danger-soft text-danger-soft-foreground"
                                : r.compliance_status === "RETURNED"
                                  ? "bg-muted text-foreground"
                                  : "bg-info-soft text-info-soft-foreground"
                          }`}
                        >
                          {r.compliance_status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <EmptyState
              icon={Gauge}
              title="No SLA records found"
              description="No registered packages exist to calculate SLA performance metrics."
            />
          )}
        </CardContent>
      </Card>
    </PageContainer>
  );
}
