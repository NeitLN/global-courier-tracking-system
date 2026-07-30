import Link from "next/link";
import { Clock, PackageCheck, PackageOpen, PackageX, Plus, BarChart3, Truck, UserRound, Car, Gauge, ShieldAlert } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { APP_ROLES, ROLE_LABELS } from "@/lib/auth/roles";
import { getNavForRole } from "@/lib/navigation/nav-config";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { KpiCardShell } from "@/components/ui/KpiCardShell";
import { DataTableShell } from "@/components/ui/DataTableShell";
import { StatusBadge, isPackageStatus } from "@/components/ui/StatusBadge";
import { Alert } from "@/components/ui/Alert";
import { formatDateTime } from "@/lib/courier/format";
import { StaggerList, StaggerItem } from "@/components/motion/StaggerList";
import { Reveal } from "@/components/motion/Reveal";

const ROLE_DESCRIPTIONS: Record<(typeof APP_ROLES)[number], string> = {
  CUSTOMER: "Track and manage packages you send or receive.",
  HUB_OPERATOR: "Record checkpoint scans and manage inventory at your assigned hub.",
  DISPATCHER: "Plan trips, assign packages to routes, and oversee network operations.",
  ANALYST: "Review SLA compliance, hub throughput, and driver performance analytics.",
};

type Summary = { active_shipments: number; delivered_shipments: number; returned_shipments: number; latest_update: string | null };
type Shipment = { package_id: number; tracking_no: string; current_status: string; sender_id: number; receiver_id: number };

export default async function DashboardPage() {
  const auth = await requireRouteAccess(APP_ROLES);
  const shortcuts = getNavForRole(auth.appRole).filter((item) => item.label !== "Dashboard" && item.label !== "Profile");
  const supabase = await createClient();

  // ==========================================================================
  // 1. CUSTOMER DASHBOARD
  // ==========================================================================
  if (auth.appRole === "CUSTOMER") {
    const [summaryResponse, shipmentResponse] = await Promise.all([
      supabase.rpc("fn_customer_dashboard_summary"),
      supabase.from("package").select("package_id, tracking_no, current_status, sender_id, receiver_id").order("package_id", { ascending: false }).limit(5),
    ]);
    const summary = summaryResponse.data as Summary | null;
    const shipments = (shipmentResponse.data ?? []) as Shipment[];

    return (
      <PageContainer>
        <PageHeader title={`Welcome back${auth.displayName ? `, ${auth.displayName}` : ""}`} description={ROLE_DESCRIPTIONS.CUSTOMER} actions={<Link href="/shipments/new" className="focus-ring inline-flex h-9 items-center gap-2 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground"><Plus className="size-4" />New shipment</Link>} />
        {summaryResponse.error || !summary ? (
          <Alert tone="danger" title="Dashboard summary unavailable">The customer-scoped summary RPC did not return data. No KPI values are being substituted.</Alert>
        ) : (
          <StaggerList className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <StaggerItem><KpiCardShell label="Active shipments" value={summary.active_shipments} supportingText="Not delivered or returned" icon={<PackageOpen className="size-4" />} /></StaggerItem>
            <StaggerItem><KpiCardShell label="Delivered" value={summary.delivered_shipments} icon={<PackageCheck className="size-4" />} /></StaggerItem>
            <StaggerItem><KpiCardShell label="Returned" value={summary.returned_shipments} icon={<PackageX className="size-4" />} /></StaggerItem>
            <StaggerItem><KpiCardShell label="Latest shipment update" value={summary.latest_update ? formatDateTime(summary.latest_update) : "—"} supportingText={summary.latest_update ? "Across your shipments" : "No tracking events yet"} icon={<Clock className="size-4" />} /></StaggerItem>
          </StaggerList>
        )}
        {shipmentResponse.error ? (
          <Alert tone="danger" title="Recent shipments unavailable">The database could not load the recent shipment list.</Alert>
        ) : shipments.length === 0 ? (
          <EmptyState title="No shipments yet" description="Register a shipment or wait until another customer sends one to you." />
        ) : (
          <Reveal>
            <DataTableShell columns={["Tracking", "Relationship", "Status"]} caption="Recent customer shipments">{shipments.map((shipment) => <tr key={shipment.package_id} className="transition-colors duration-150 hover:bg-muted/40"><td className="px-3 py-3"><Link className="font-medium text-primary hover:underline" href={`/shipments/${shipment.tracking_no}`}>{shipment.tracking_no}</Link></td><td className="px-3 py-3">{shipment.sender_id === auth.customerId ? "Sender" : "Receiver"}</td><td className="px-3 py-3">{isPackageStatus(shipment.current_status) ? <StatusBadge status={shipment.current_status} /> : shipment.current_status}</td></tr>)}</DataTableShell>
          </Reveal>
        )}
        <p className="text-caption">When available, all figures are returned by a customer-scoped database RPC. Signed in as {ROLE_LABELS[auth.appRole]}.</p>
      </PageContainer>
    );
  }

  // ==========================================================================
  // 2. HUB OPERATOR DASHBOARD
  // ==========================================================================
  if (auth.appRole === "HUB_OPERATOR") {
    // Determine the operator's active hub
    const { data: staffRow } = await supabase
      .from("staff")
      .select("hub_id, transit_hub(hub_code, hub_name)")
      .eq("staff_id", auth.staffId || 0)
      .single();

    const hubId = staffRow?.hub_id;
    const hubInfo = staffRow?.transit_hub as unknown as { hub_code: string; hub_name: string; } | null;

    let inventoryCount = 0;
    let scanCount = 0;
    let deliveryAttempts: Array<{
      attempt_id: number;
      tracking_no: string;
      driver_name: string;
      outcome: string;
      attempt_time: string;
    }> = [];
    let loadError = false;

    if (hubId) {
      const [inventoryRes, scanRes, attemptsRes] = await Promise.all([
        supabase.rpc("fn_current_hub_inventory", { p_hub_id: hubId }),
        supabase.from("tracking_event").select("event_id", { count: "exact", head: true }).eq("hub_id", hubId),
        supabase.rpc("fn_get_hub_delivery_attempts", { p_hub_id: hubId }),
      ]);

      inventoryCount = inventoryRes.data ? inventoryRes.data.length : 0;
      scanCount = scanRes.count || 0;
      deliveryAttempts = (attemptsRes.data || []).slice(0, 5); // display latest 5 attempts
      loadError = !!(inventoryRes.error || scanRes.error || attemptsRes.error);
    }

    return (
      <PageContainer>
        <PageHeader
          title={`Hub Operator Dashboard${hubInfo ? ` - ${hubInfo.hub_code}` : ""}`}
          description={`${ROLE_DESCRIPTIONS.HUB_OPERATOR} Managed Hub: ${hubInfo ? hubInfo.hub_name : "Not assigned"}`}
        />

        {loadError && (
          <Alert tone="danger" title="Telemetry data unavailable">
            Some operational parameters could not be fetched. Displayed KPIs may be out of date.
          </Alert>
        )}

        <StaggerList className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 mb-6">
          <StaggerItem><KpiCardShell label="Current Hub Inventory" value={inventoryCount} supportingText="Packages held at your hub" icon={<PackageOpen className="size-4" />} /></StaggerItem>
          <StaggerItem><KpiCardShell label="Historical Scans" value={scanCount} supportingText="Total checkpoint events recorded" icon={<BarChart3 className="size-4" />} /></StaggerItem>
          <StaggerItem><KpiCardShell label="Recent Hub Delivery Runs" value={deliveryAttempts.length} supportingText="Last local delivery attempts" icon={<Clock className="size-4" />} /></StaggerItem>
        </StaggerList>

        {/* Shortcuts cards */}
        {shortcuts.length > 0 && (
          <StaggerList className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 mb-6">
            {shortcuts.map((item) => {
              const Icon = item.icon;
              return (
                <StaggerItem key={item.label}>
                  <Link href={item.href}>
                    <Card className="card-interactive h-full transition-colors hover:border-primary/40 hover:bg-muted/40">
                      <CardContent className="flex items-center gap-3 py-4">
                        <span className="flex size-9 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary">
                          <Icon className="size-5" />
                        </span>
                        <div>
                          <p className="text-sm font-medium text-foreground">{item.label}</p>
                          <p className="text-caption">Open operational view</p>
                        </div>
                      </CardContent>
                    </Card>
                  </Link>
                </StaggerItem>
              );
            })}
          </StaggerList>
        )}

        {/* Recent Attempts Table */}
        <Reveal>
          <Card>
            <CardHeader>
              <CardTitle>Recent Delivery Attempts</CardTitle>
            </CardHeader>
            <CardContent>
              {deliveryAttempts.length > 0 ? (
                <DataTableShell columns={["Tracking No", "Driver", "Outcome", "Time"]} caption="Recent delivery attempts">
                  {((deliveryAttempts || []) as Array<{
                    attempt_id: number;
                    tracking_no: string;
                    driver_name: string;
                    outcome: string;
                    attempt_time: string;
                  }>).map((da) => (
                    <tr key={da.attempt_id} className="transition-colors duration-150 hover:bg-muted/40">
                      <td className="px-3 py-3 font-mono font-medium text-foreground">{da.tracking_no}</td>
                      <td className="px-3 py-3 text-foreground">{da.driver_name}</td>
                      <td className="px-3 py-3">
                        <span className={`rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase ${
                          da.outcome === "SUCCESS"
                            ? "bg-success-soft text-success-soft-foreground"
                            : "bg-danger-soft text-danger-soft-foreground"
                        }`}>
                          {da.outcome}
                        </span>
                      </td>
                      <td className="px-3 py-3 text-muted-foreground">{new Date(da.attempt_time).toLocaleString()}</td>
                    </tr>
                  ))}
                </DataTableShell>
              ) : (
                <EmptyState icon={Clock} title="No local attempts logged" description="No local delivery attempt scans have been recorded at your hub." />
              )}
            </CardContent>
          </Card>
        </Reveal>
        <p className="text-caption">Signed in as {ROLE_LABELS[auth.appRole]}.</p>
      </PageContainer>
    );
  }

  // ==========================================================================
  // 3. DISPATCHER DASHBOARD
  // ==========================================================================
  if (auth.appRole === "DISPATCHER") {
    // Load counts using secure Dispatcher Read RPCs
    const [tripsRes, driversRes, vehiclesRes, routesRes] = await Promise.all([
      supabase.rpc("fn_get_dispatcher_trips"),
      supabase.rpc("fn_get_dispatcher_drivers"),
      supabase.rpc("fn_get_dispatcher_vehicles"),
      supabase.rpc("fn_get_dispatcher_routes"),
    ]);

    const tripsCount = tripsRes.data ? tripsRes.data.length : 0;
    const driversCount = driversRes.data ? driversRes.data.length : 0;
    const vehiclesCount = vehiclesRes.data ? vehiclesRes.data.length : 0;
    const routesCount = routesRes.data ? routesRes.data.length : 0;
    const recentTrips = (tripsRes.data || []).slice(0, 5);

    const loadError = !!(tripsRes.error || driversRes.error || vehiclesRes.error || routesRes.error);

    return (
      <PageContainer>
        <PageHeader title={`Welcome back, ${auth.displayName || "Dispatcher"}`} description={ROLE_DESCRIPTIONS.DISPATCHER} />

        {loadError && (
          <Alert tone="danger" title=" Roster data unavailable">
            Some logistical parameters could not be fetched. Live KPI cards may be empty.
          </Alert>
        )}

        <StaggerList className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 mb-6">
          <StaggerItem><KpiCardShell label="Scheduled Trips" value={tripsCount} supportingText="Network-wide runs" icon={<Truck className="size-4" />} /></StaggerItem>
          <StaggerItem><KpiCardShell label="Active Drivers" value={driversCount} supportingText="Deployed road crew" icon={<UserRound className="size-4" />} /></StaggerItem>
          <StaggerItem><KpiCardShell label="Fleet Vehicles" value={vehiclesCount} supportingText="Transit assets" icon={<Car className="size-4" />} /></StaggerItem>
          <StaggerItem><KpiCardShell label="Service Routes" value={routesCount} supportingText="Directed lines" icon={<Clock className="size-4" />} /></StaggerItem>
        </StaggerList>

        {/* Shortcuts cards */}
        {shortcuts.length > 0 && (
          <StaggerList className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 mb-6">
            {shortcuts.map((item) => {
              const Icon = item.icon;
              return (
                <StaggerItem key={item.label}>
                  <Link href={item.href}>
                    <Card className="card-interactive h-full transition-colors hover:border-primary/40 hover:bg-muted/40">
                      <CardContent className="flex items-center gap-3 py-4">
                        <span className="flex size-9 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary">
                          <Icon className="size-5" />
                        </span>
                        <div>
                          <p className="text-sm font-medium text-foreground">{item.label}</p>
                          <p className="text-caption">Schedule & assign manifest</p>
                        </div>
                      </CardContent>
                    </Card>
                  </Link>
                </StaggerItem>
              );
            })}
          </StaggerList>
        )}

        {/* Trips table */}
        <Reveal>
          <Card>
            <CardHeader>
              <CardTitle>Recent Trips Manifest</CardTitle>
            </CardHeader>
            <CardContent>
              {recentTrips.length > 0 ? (
                <DataTableShell columns={["Trip ID", "Route", "Driver", "Vehicle", "Departure"]} caption="Recent trips manifest">
                  {((recentTrips || []) as Array<{
                    trip_id: number;
                    origin_hub_code: string;
                    dest_hub_code: string;
                    mode: string;
                    driver_name: string;
                    vehicle_plate: string;
                    depart: string;
                  }>).map((t) => (
                    <tr key={t.trip_id} className="transition-colors duration-150 hover:bg-muted/40">
                      <td className="px-3 py-3 font-mono font-medium text-foreground">#{t.trip_id}</td>
                      <td className="px-3 py-3 font-medium text-foreground">{t.origin_hub_code} → {t.dest_hub_code}</td>
                      <td className="px-3 py-3 text-foreground">{t.driver_name}</td>
                      <td className="px-3 py-3 font-mono text-muted-foreground">{t.vehicle_plate}</td>
                      <td className="px-3 py-3 text-foreground">{new Date(t.depart).toLocaleString()}</td>
                    </tr>
                  ))}
                </DataTableShell>
              ) : (
                <EmptyState icon={Truck} title="No trips scheduled" description="Use the trips manager module to schedule the first network run." />
              )}
            </CardContent>
          </Card>
        </Reveal>
        <p className="text-caption">Signed in as {ROLE_LABELS[auth.appRole]}.</p>
      </PageContainer>
    );
  }

  // ==========================================================================
  // 4. ANALYST DASHBOARD
  // ==========================================================================
  if (auth.appRole === "ANALYST") {
    const [slaRes, latencyRes, rankRes] = await Promise.all([
      supabase.rpc("fn_sla_compliance"),
      supabase.rpc("fn_inter_scan_hub_analysis"),
      supabase.rpc("fn_get_analyst_driver_performance"),
    ]);

    const slaRecords = (slaRes.data || []) as Array<{
      package_id: number;
      tracking_no: string;
      service_name: string;
      elapsed_hours: number;
      sla_hours: number;
      compliance_status: string;
    }>;
    const latencyRecords = (latencyRes.data || []) as Array<{
      hub_id: number;
      hub_code: string;
      segment_count: number;
      avg_hours: number;
      min_hours: number;
      max_hours: number;
    }>;
    const rankingRecords = (rankRes.data || []) as Array<{
      driver_id: number;
      driver_name: string;
      total_attempts: number;
      successful_attempts: number;
      failed_attempts: number;
      success_rate: number;
      performance_rank: number;
    }>;

    // Safe division-by-zero aggregation
    const totalSla = slaRecords.length;
    const metSla = slaRecords.filter((r) => r.compliance_status === "MET").length;
    const pctMet = totalSla === 0 ? "0.0" : ((metSla / totalSla) * 100).toFixed(1);

    // Compute average latency across hubs safely
    const avgLatency = latencyRecords.length === 0 
      ? 0 
      : (latencyRecords.reduce((sum: number, h) => sum + h.avg_hours, 0) / latencyRecords.length);

    // Get the top performer driver name
    const topPerformer = rankingRecords.length > 0 
      ? rankingRecords.find((r) => r.performance_rank === 1)?.driver_name || "—"
      : "—";

    const loadError = !!(slaRes.error || latencyRes.error || rankRes.error);

    return (
      <PageContainer>
        <PageHeader title={`Welcome back, ${auth.displayName || "Analyst"}`} description={ROLE_DESCRIPTIONS.ANALYST} />

        {loadError && (
          <Alert tone="danger" title="Analytical data unavailable">
            Some analytical metrics could not be fully aggregated. Displayed charts may be partial.
          </Alert>
        )}

        <StaggerList className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 mb-6">
          <StaggerItem><KpiCardShell label="SLA Compliance Rate" value={`${pctMet}%`} supportingText={`${metSla} of ${totalSla} shipments met`} icon={<Gauge className="size-4 text-success" />} /></StaggerItem>
          <StaggerItem><KpiCardShell label="Avg Hub Latency" value={`${avgLatency.toFixed(1)}h`} supportingText="Across all transit hubs" icon={<Clock className="size-4" />} /></StaggerItem>
          <StaggerItem><KpiCardShell label="Top Deployed Driver" value={topPerformer} supportingText="Highest successful outcome rate" icon={<UserRound className="size-4 text-primary" />} /></StaggerItem>
          <StaggerItem><KpiCardShell label="Hub Count Audited" value={latencyRecords.length} supportingText="Active checkpoints" icon={<BarChart3 className="size-4" />} /></StaggerItem>
        </StaggerList>

        {/* Shortcuts cards */}
        {shortcuts.length > 0 && (
          <StaggerList className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 mb-6">
            {shortcuts.map((item) => {
              const Icon = item.icon;
              return (
                <StaggerItem key={item.label}>
                  <Link href={item.href}>
                    <Card className="card-interactive h-full transition-colors hover:border-primary/40 hover:bg-muted/40">
                      <CardContent className="flex items-center gap-3 py-4">
                        <span className="flex size-9 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary">
                          <Icon className="size-5" />
                        </span>
                        <div>
                          <p className="text-sm font-medium text-foreground">{item.label}</p>
                          <p className="text-caption">Analyze network benchmarks</p>
                        </div>
                      </CardContent>
                    </Card>
                  </Link>
                </StaggerItem>
              );
            })}
          </StaggerList>
        )}

        {/* SLA Breach Warning Table */}
        <Reveal>
          <Card>
            <CardHeader>
              <CardTitle>Recent SLA Breaches</CardTitle>
            </CardHeader>
            <CardContent>
              {slaRecords.filter((r) => r.compliance_status === "BREACHED").length > 0 ? (
                <DataTableShell columns={["Tracking No", "Service Type", "Elapsed Time", "SLA Limit"]} caption="Recent SLA breaches">
                  {slaRecords.filter((r) => r.compliance_status === "BREACHED").slice(0, 5).map((r) => (
                    <tr key={r.package_id} className="transition-colors duration-150 hover:bg-muted/40">
                      <td className="px-3 py-3 font-mono font-medium text-danger">{r.tracking_no}</td>
                      <td className="px-3 py-3 text-foreground">{r.service_name}</td>
                      <td className="px-3 py-3 text-right font-mono text-danger font-semibold">{r.elapsed_hours}h</td>
                      <td className="px-3 py-3 text-right font-mono text-muted-foreground">{r.sla_hours}h</td>
                    </tr>
                  ))}
                </DataTableShell>
              ) : (
                <EmptyState icon={ShieldAlert} title="Perfect SLA records!" description="Excellent! No SLA compliance breaches are currently logged in the system." />
              )}
            </CardContent>
          </Card>
        </Reveal>
        <p className="text-caption">Signed in as {ROLE_LABELS[auth.appRole]}.</p>
      </PageContainer>
    );
  }

  return (
    <PageContainer>
      <PageHeader title={`Welcome back${auth.displayName ? `, ${auth.displayName}` : ""}`} description={ROLE_DESCRIPTIONS[auth.appRole]} />
      {shortcuts.length > 0 && (
        <StaggerList className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {shortcuts.map((item) => {
            const Icon = item.icon;
            return (
              <StaggerItem key={item.label}>
                <Link href={item.href}>
                  <Card className="card-interactive h-full transition-colors hover:border-primary/40 hover:bg-muted/40">
                    <CardContent className="flex items-center gap-3">
                      <span className="flex size-9 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary">
                        <Icon className="size-5" />
                      </span>
                      <div>
                        <p className="text-sm font-medium text-foreground">{item.label}</p>
                        <p className="text-caption">{item.children ? `${item.children.length} sections` : "Open module"}</p>
                      </div>
                    </CardContent>
                  </Card>
                </Link>
              </StaggerItem>
            );
          })}
        </StaggerList>
      )}
      <p className="text-caption">Signed in as {ROLE_LABELS[auth.appRole]}.</p>
    </PageContainer>
  );
}
