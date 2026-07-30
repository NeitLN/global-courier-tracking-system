import { Route as RouteIcon, ArrowRight } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { SelectField } from "@/components/ui/SelectField";
import { Button } from "@/components/ui/Button";
import { courierErrorMessage } from "@/lib/courier/errors";
import { StaggerList, StaggerItem } from "@/components/motion/StaggerList";

interface PageProps {
  searchParams: Promise<{
    originHubId?: string;
    destHubId?: string;
    maxHops?: string;
  }>;
}

export default async function AnalyticsRoutesPage({ searchParams }: PageProps) {
  const auth = await requireRouteAccess(["ANALYST", "DISPATCHER"]);

  const params = await searchParams;
  const supabase = await createClient();

  // Load transit hubs for the selection drop-downs
  const { data: hubs = [] } = await supabase
    .from("transit_hub")
    .select("hub_id, hub_code, hub_name")
    .order("hub_code", { ascending: true });

  const originHubId = params.originHubId || "";
  const destHubId = params.destHubId || "";
  const maxHops = params.maxHops || "3";

  // Build a fast map from hub_id to hub_code for rendering path_array nicely
  const hubMap = new Map<number, string>();
  if (hubs) {
    (hubs as Array<{ hub_id: number; hub_code: string; hub_name: string; }>).forEach((h) => {
      hubMap.set(h.hub_id, h.hub_code);
    });
  }

  // If both origin and destination are selected, query the recursive route finder RPC
  let routes: Array<{
    path_array: number[];
    total_distance_km: number;
    total_planned_hours: number;
    hop_count: number;
  }> = [];
  let error: { message: string } | null = null;
  if (originHubId && destHubId) {
    const { data, error: rpcError } = await supabase.rpc("fn_find_routes", {
      p_origin_hub_id: parseInt(originHubId, 10),
      p_dest_hub_id: parseInt(destHubId, 10),
      p_max_hops: parseInt(maxHops, 10),
    });
    routes = data || [];
    error = rpcError;
  }

  return (
    <PageContainer>
      <PageHeader
        title="Route Explorer"
        description="Traverse multi-hop routes and determine optimal hubs using recursive network pathfinding."
      />

      <div className="grid gap-6 lg:grid-cols-3">
        {/* Left Column: Filter Panel Form */}
        <div className="lg:col-span-1">
          <Card>
            <CardHeader>
              <CardTitle>Pathfinding Inputs</CardTitle>
            </CardHeader>
            <CardContent>
              <form method="GET" className="space-y-4">
                <SelectField
                  name="originHubId"
                  label="Starting Hub (Origin)"
                  defaultValue={originHubId}
                  required
                >
                  <option value="">Select Origin Hub</option>
                  {((hubs || []) as Array<{ hub_id: number; hub_code: string; hub_name: string; }>).map((h) => (
                    <option key={h.hub_id} value={h.hub_id}>
                      {h.hub_code} - {h.hub_name}
                    </option>
                  ))}
                </SelectField>

                <SelectField
                  name="destHubId"
                  label="Target Hub (Destination)"
                  defaultValue={destHubId}
                  required
                >
                  <option value="">Select Destination Hub</option>
                  {((hubs || []) as Array<{ hub_id: number; hub_code: string; hub_name: string; }>).map((h) => (
                    <option key={h.hub_id} value={h.hub_id}>
                      {h.hub_code} - {h.hub_name}
                    </option>
                  ))}
                </SelectField>

                <SelectField
                  name="maxHops"
                  label="Maximum Allowed Hops"
                  defaultValue={maxHops}
                  required
                >
                  <option value="1">1 Hop (Direct only)</option>
                  <option value="2">2 Hops (1 transfer)</option>
                  <option value="3">3 Hops (2 transfers)</option>
                  <option value="4">4 Hops (3 transfers)</option>
                  <option value="5">5 Hops (4 transfers)</option>
                </SelectField>

                <Button type="submit" className="w-full">
                  Find Routes
                </Button>
              </form>
            </CardContent>
          </Card>
        </div>

        {/* Right Column: Results Manifest List */}
        <div className="lg:col-span-2">
          <Card className="h-full">
            <CardHeader>
              <CardTitle>Discovered Network Paths</CardTitle>
            </CardHeader>
            <CardContent>
              {error && (
                <div className="rounded-md bg-danger-soft p-3 text-sm text-danger-soft-foreground mb-4">
                  Failed to discover routes: {courierErrorMessage(error.message, "ANALYTICS_ROUTE_EXPLORER", auth.userId)}
                </div>
              )}

              {routes && routes.length > 0 ? (
                <StaggerList className="space-y-4">
                  {routes.map((r, idx) => {
                    // Map path_array of hub IDs to beautiful, human-readable codes
                    const pathCodes = r.path_array
                      ? r.path_array.map((id) => hubMap.get(id) || `#${id}`)
                      : [];

                    return (
                      <StaggerItem
                        key={idx}
                        className="card-interactive rounded-lg border border-border bg-card p-4 hover:border-primary-soft"
                      >
                        <div className="flex items-center justify-between">
                          <span className="rounded bg-primary-soft/10 text-primary px-2 py-0.5 text-xs font-bold font-mono">
                            PATH CHOICE #{idx + 1}
                          </span>
                          <span className="text-caption font-medium">
                            {r.hop_count} hop{r.hop_count > 1 ? "s" : ""}
                          </span>
                        </div>

                        {/* Interactive Breadcrumb Path Rendering */}
                        <div className="flex flex-wrap items-center gap-2 py-1.5">
                          {pathCodes.map((code: string, cIdx: number) => (
                            <div key={cIdx} className="flex items-center gap-2">
                              <span className="rounded bg-muted px-2.5 py-1 text-sm font-semibold text-foreground font-mono shadow-sm">
                                {code}
                              </span>
                              {cIdx < pathCodes.length - 1 && (
                                <ArrowRight className="size-4 text-muted-foreground/60" />
                              )}
                            </div>
                          ))}
                        </div>

                        {/* Distance & Hours Summary Footer */}
                        <div className="flex justify-between text-xs text-muted-foreground pt-1 border-t border-dashed border-border">
                          <span>Total Distance: <strong className="text-foreground">{r.total_distance_km} km</strong></span>
                          <span>Planned Transport: <strong className="text-foreground">{r.total_planned_hours} hours</strong></span>
                        </div>
                      </StaggerItem>
                    );
                  })}
                </StaggerList>
              ) : (
                <EmptyState
                  icon={RouteIcon}
                  title="No network paths selected"
                  description={
                    originHubId && destHubId
                      ? "There are no direct or multi-hop routes connecting the chosen hubs within the allowed hop range."
                      : "Fill in the starting and ending hub planning parameters on the left to run recursive route pathfinding."
                  }
                />
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </PageContainer>
  );
}
