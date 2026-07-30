import { BarChart3 } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";

export default async function AnalyticsHubsPage() {
  await requireRouteAccess(["ANALYST", "DISPATCHER"]);

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
              Failed to load hub latency analysis: {error.message}
            </div>
          )}

          {analysis && analysis.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/50 text-caption font-medium">
                    <th className="p-3">Hub Code</th>
                    <th className="p-3 text-right">Processed Shipments</th>
                    <th className="p-3 text-right">Average Lag (hours)</th>
                    <th className="p-3 text-right">Min Lag (hours)</th>
                    <th className="p-3 text-right pr-6">Max Lag (hours)</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {((analysis || []) as Array<{
                    hub_id: number;
                    hub_code: string;
                    segment_count: number;
                    avg_hours: number;
                    min_hours: number;
                    max_hours: number;
                  }>).map((h) => (
                    <tr key={h.hub_id} className="hover:bg-muted/20">
                      <td className="p-3 font-semibold text-foreground">
                        {h.hub_code}
                      </td>
                      <td className="p-3 text-right text-foreground font-mono">
                        {h.segment_count}
                      </td>
                      <td className="p-3 text-right text-primary font-mono font-bold">
                        {h.avg_hours}h
                      </td>
                      <td className="p-3 text-right text-success font-mono">
                        {h.min_hours}h
                      </td>
                      <td className="p-3 text-right pr-6 text-danger font-mono">
                        {h.max_hours}h
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
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
