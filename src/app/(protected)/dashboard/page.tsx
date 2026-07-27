import Link from "next/link";
import { Clock, PackageCheck, PackageOpen, PackageX, Plus } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { APP_ROLES, ROLE_LABELS } from "@/lib/auth/roles";
import { getNavForRole } from "@/lib/navigation/nav-config";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardContent } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { KpiCardShell } from "@/components/ui/KpiCardShell";
import { DataTableShell } from "@/components/ui/DataTableShell";
import { StatusBadge, isPackageStatus } from "@/components/ui/StatusBadge";
import { Alert } from "@/components/ui/Alert";
import { formatDateTime } from "@/lib/courier/format";

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

  if (auth.appRole === "CUSTOMER") {
    const supabase = await createClient();
    const [summaryResponse, shipmentResponse] = await Promise.all([
      supabase.rpc("fn_customer_dashboard_summary"),
      supabase.from("package").select("package_id, tracking_no, current_status, sender_id, receiver_id").order("package_id", { ascending: false }).limit(5),
    ]);
    const summary = summaryResponse.data as Summary | null;
    const shipments = (shipmentResponse.data ?? []) as Shipment[];

    return <PageContainer>
      <PageHeader title={`Welcome back${auth.displayName ? `, ${auth.displayName}` : ""}`} description={ROLE_DESCRIPTIONS.CUSTOMER} actions={<Link href="/shipments/new" className="focus-ring inline-flex h-9 items-center gap-2 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground"><Plus className="size-4" />New shipment</Link>} />
      {summaryResponse.error || !summary ? (
        <Alert tone="danger" title="Dashboard summary unavailable">The customer-scoped summary RPC did not return data. No KPI values are being substituted.</Alert>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <KpiCardShell label="Active shipments" value={summary.active_shipments} supportingText="Not delivered or returned" icon={<PackageOpen className="size-4" />} />
          <KpiCardShell label="Delivered" value={summary.delivered_shipments} icon={<PackageCheck className="size-4" />} />
          <KpiCardShell label="Returned" value={summary.returned_shipments} icon={<PackageX className="size-4" />} />
          <KpiCardShell label="Latest shipment update" value={summary.latest_update ? formatDateTime(summary.latest_update) : "—"} supportingText={summary.latest_update ? "Across your shipments" : "No tracking events yet"} icon={<Clock className="size-4" />} />
        </div>
      )}
      {shipmentResponse.error ? (
        <Alert tone="danger" title="Recent shipments unavailable">The database could not load the recent shipment list.</Alert>
      ) : shipments.length === 0 ? (
        <EmptyState title="No shipments yet" description="Register a shipment or wait until another customer sends one to you." />
      ) : (
        <DataTableShell columns={["Tracking", "Relationship", "Status"]} caption="Recent customer shipments">{shipments.map((shipment) => <tr key={shipment.package_id}><td className="px-3 py-3"><Link className="font-medium text-primary hover:underline" href={`/shipments/${shipment.tracking_no}`}>{shipment.tracking_no}</Link></td><td className="px-3 py-3">{shipment.sender_id === auth.customerId ? "Sender" : "Receiver"}</td><td className="px-3 py-3">{isPackageStatus(shipment.current_status) ? <StatusBadge status={shipment.current_status} /> : shipment.current_status}</td></tr>)}</DataTableShell>
      )}
      <p className="text-caption">When available, all figures are returned by a customer-scoped database RPC. Signed in as {ROLE_LABELS[auth.appRole]}.</p>
    </PageContainer>;
  }

  return (
    <PageContainer>
      <PageHeader title={`Welcome back${auth.displayName ? `, ${auth.displayName}` : ""}`} description={ROLE_DESCRIPTIONS[auth.appRole]} />
      {shortcuts.length > 0 && <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">{shortcuts.map((item) => { const Icon = item.icon; return <Link key={item.label} href={item.href}><Card className="h-full transition-colors hover:border-primary/40 hover:bg-muted/40"><CardContent className="flex items-center gap-3"><span className="flex size-9 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary"><Icon className="size-5" /></span><div><p className="text-sm font-medium text-foreground">{item.label}</p><p className="text-caption">{item.children ? `${item.children.length} sections` : "Open module"}</p></div></CardContent></Card></Link>; })}</div>}
      <EmptyState icon={Clock} title="Role dashboard data arrives in Phase 12" description="This role's live KPI cards remain intentionally empty until the approved operational or analytical RPC integrations are implemented." />
      <p className="text-caption">Signed in as {ROLE_LABELS[auth.appRole]}.</p>
    </PageContainer>
  );
}
