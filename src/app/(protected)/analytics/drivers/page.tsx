import { Clock3 } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { courierErrorMessage } from "@/lib/courier/errors";
import { DataTableShell } from "@/components/ui/DataTableShell";
import { Reveal } from "@/components/motion/Reveal";

export default async function AnalyticsDriversPage() {
  const auth = await requireRouteAccess(["ANALYST", "DISPATCHER"]);

  const supabase = await createClient();
  const { data: rankings = [], error } = await supabase.rpc("fn_get_analyst_driver_performance");

  return (
    <PageContainer>
      <PageHeader
        title="Driver Performance"
        description="Driver ranking by successful delivery outcomes."
      />

      <Card>
        <CardHeader>
          <CardTitle>Driver Performance Leaderboard</CardTitle>
        </CardHeader>
        <CardContent>
          {error && (
            <div className="rounded-md bg-danger-soft p-3 text-sm text-danger-soft-foreground mb-4">
              Failed to load driver rankings: {courierErrorMessage(error.message, "ANALYTICS_DRIVER_PERFORMANCE", auth.userId)}
            </div>
          )}

          {rankings && rankings.length > 0 ? (
            <Reveal>
              <DataTableShell
                columns={["Rank", "Driver Name", "Total Attempts", "Successes", "Failures", "Success Rate"]}
                caption="Driver performance leaderboard"
              >
                {((rankings || []) as Array<{
                  driver_id: number;
                  driver_name: string;
                  total_attempts: number;
                  successful_attempts: number;
                  failed_attempts: number;
                  success_rate: number;
                  performance_rank: number;
                }>).map((r) => (
                  <tr key={r.driver_id} className="transition-colors duration-150 hover:bg-muted/40">
                    <td className="px-3 py-3 text-center font-bold text-foreground w-16">
                      #{r.performance_rank}
                    </td>
                    <td className="px-3 py-3 text-foreground font-medium">
                      {r.driver_name}
                    </td>
                    <td className="px-3 py-3 text-right text-foreground font-mono">
                      {r.total_attempts}
                    </td>
                    <td className="px-3 py-3 text-right text-success font-mono font-medium">
                      {r.successful_attempts}
                    </td>
                    <td className="px-3 py-3 text-right text-danger font-mono font-medium">
                      {r.failed_attempts}
                    </td>
                    <td className="px-3 py-3 text-right text-foreground font-mono font-bold">
                      {r.success_rate}%
                    </td>
                  </tr>
                ))}
              </DataTableShell>
            </Reveal>
          ) : (
            <EmptyState
              icon={Clock3}
              title="No driver rankings found"
              description="No delivery attempts have been recorded to establish a driver performance leaderboard."
            />
          )}
        </CardContent>
      </Card>
    </PageContainer>
  );
}
