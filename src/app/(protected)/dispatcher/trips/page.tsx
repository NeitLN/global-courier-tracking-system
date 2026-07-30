import { Truck } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { TripForm } from "./TripForm";
import { courierErrorMessage } from "@/lib/courier/errors";

export default async function TripsPage() {
  const auth = await requireRouteAccess(["DISPATCHER"]);

  const supabase = await createClient();

  // Load dropdown choice lists via our new secure read RPCs
  const { data: routes = [] } = await supabase.rpc("fn_get_dispatcher_routes");
  const { data: vehicles = [] } = await supabase.rpc("fn_get_dispatcher_vehicles");
  const { data: drivers = [] } = await supabase.rpc("fn_get_dispatcher_drivers");

  // Load scheduled trips
  const { data: trips = [], error: tripsError } = await supabase.rpc("fn_get_dispatcher_trips");

  return (
    <PageContainer>
      <PageHeader
        title="Trips Management"
        description="Schedule network-wide transit trips and view dispatch roster."
      />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Creation Form Panel */}
        <div className="lg:col-span-1">
          <TripForm routes={routes || []} vehicles={vehicles || []} drivers={drivers || []} />
        </div>

        {/* Trips Table List Panel */}
        <div className="lg:col-span-2">
          <Card className="h-full">
            <CardHeader>
              <CardTitle>Scheduled Trips</CardTitle>
            </CardHeader>
            <CardContent>
              {tripsError && (
                <div className="rounded-md bg-danger-soft p-3 text-sm text-danger-soft-foreground">
                  Failed to load trips roster: {courierErrorMessage(tripsError.message, "DISPATCHER_TRIPS_LIST", auth.userId)}
                </div>
              )}

              {trips && trips.length > 0 ? (
                <div className="overflow-x-auto">
                  <table className="w-full border-collapse text-left text-sm">
                    <thead>
                      <tr className="border-b border-border bg-muted/50 text-caption font-medium">
                        <th className="p-3">Trip ID</th>
                        <th className="p-3">Route</th>
                        <th className="p-3">Driver</th>
                        <th className="p-3">Vehicle</th>
                        <th className="p-3">Departure</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-border">
                      {((trips || []) as Array<{
                        trip_id: number;
                        route_id: number;
                        origin_hub_code: string;
                        dest_hub_code: string;
                        mode: string;
                        driver_name: string;
                        vehicle_plate: string;
                        depart: string;
                      }>).map((t) => (
                        <tr key={t.trip_id} className="hover:bg-muted/20">
                          <td className="p-3 font-mono font-medium text-foreground">
                            #{t.trip_id}
                          </td>
                          <td className="p-3">
                            <span className="font-medium text-foreground">
                              {t.origin_hub_code} → {t.dest_hub_code}
                            </span>
                            <span className="ml-1.5 text-xs text-muted-foreground uppercase">
                              ({t.mode})
                            </span>
                          </td>
                          <td className="p-3 text-foreground">{t.driver_name}</td>
                          <td className="p-3 text-muted-foreground font-mono">
                            {t.vehicle_plate}
                          </td>
                          <td className="p-3 text-foreground">
                            {new Date(t.depart).toLocaleString()}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <EmptyState
                  icon={Truck}
                  title="No trips scheduled"
                  description="Use the planning form on the left to schedule the first network-wide trip."
                />
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </PageContainer>
  );
}
