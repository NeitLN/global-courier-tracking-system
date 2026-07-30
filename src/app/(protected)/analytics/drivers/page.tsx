import { Clock3 } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { courierErrorMessage } from "@/lib/courier/errors";

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
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/50 text-caption font-medium">
                    <th className="p-3 text-center w-16">Rank</th>
                    <th className="p-3">Driver Name</th>
                    <th className="p-3 text-right">Total Attempts</th>
                    <th className="p-3 text-right">Successes</th>
                    <th className="p-3 text-right">Failures</th>
                    <th className="p-3 text-right pr-6">Success Rate</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {((rankings || []) as Array<{
                    driver_id: number;
                    driver_name: string;
                    total_attempts: number;
                    successful_attempts: number;
                    failed_attempts: number;
                    success_rate: number;
                    performance_rank: number;
                  }>).map((r) => (
                    <tr key={r.driver_id} className="hover:bg-muted/20">
                      <td className="p-3 text-center font-bold text-foreground">
                        #{r.performance_rank}
                      </td>
                      <td className="p-3 text-foreground font-medium">
                        {r.driver_name}
                      </td>
                      <td className="p-3 text-right text-foreground font-mono">
                        {r.total_attempts}
                      </td>
                      <td className="p-3 text-right text-success font-mono font-medium">
                        {r.successful_attempts}
                      </td>
                      <td className="p-3 text-right text-danger font-mono font-medium">
                        {r.failed_attempts}
                      </td>
                      <td className="p-3 text-right pr-6 text-foreground font-mono font-bold">
                        {r.success_rate}%
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
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
