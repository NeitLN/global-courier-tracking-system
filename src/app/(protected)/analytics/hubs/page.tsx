import { BarChart3 } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { courierErrorMessage } from "@/lib/courier/errors";
import { DataTableShell } from "@/components/ui/DataTableShell";
import { Reveal } from "@/components/motion/Reveal";

export default async function AnalyticsHubsPage() {
  const auth = await requireRouteAccess(["ANALYST", "DISPATCHER"]);

  const supabase = await createClient();
  const { data: analysis = [], error } = await supabase.rpc("fn_inter_scan_hub_analysis");

  return (
    <PageContainer>
      <PageHeader
        title="Hub Processing Analysis"
        description="Average and range of package processing times between checkpoint scans grouped by transit hub."
      />

      <Card>
        <CardHeader>
          <CardTitle>Hub Latency Metrics</CardTitle>
        </CardHeader>
        <CardContent>
          {error && (
            <div className="rounded-md bg-danger-soft p-3 text-sm text-danger-soft-foreground mb-4">
              Failed to load hub latency analysis: {courierErrorMessage(error.message, "ANALYTICS_HUB_LATENCY", auth.userId)}
            </div>
          )}

          {analysis && analysis.length > 0 ? (
            <Reveal>
              <DataTableShell
                columns={["Hub Code", "Processed Shipments", "Average Lag (hours)", "Min Lag (hours)", "Max Lag (hours)"]}
                caption="Hub latency metrics"
              >
                {((analysis || []) as Array<{
                  hub_id: number;
                  hub_code: string;
                  segment_count: number;
                  avg_hours: number;
                  min_hours: number;
                  max_hours: number;
                }>).map((h) => (
                  <tr key={h.hub_id} className="transition-colors duration-150 hover:bg-muted/40">
                    <td className="px-3 py-3 font-semibold text-foreground">
                      {h.hub_code}
                    </td>
                    <td className="px-3 py-3 text-right text-foreground font-mono">
                      {h.segment_count}
                    </td>
                    <td className="px-3 py-3 text-right text-primary font-mono font-bold">
                      {h.avg_hours}h
                    </td>
                    <td className="px-3 py-3 text-right text-success font-mono">
                      {h.min_hours}h
                    </td>
                    <td className="px-3 py-3 text-right text-danger font-mono">
                      {h.max_hours}h
                    </td>
                  </tr>
                ))}
              </DataTableShell>
            </Reveal>
          ) : (
            <EmptyState
              icon={BarChart3}
              title="No scan latency records"
              description="No segment scans have been recorded to analyze processing speeds."
            />
          )}
        </CardContent>
      </Card>
    </PageContainer>
  );
}
