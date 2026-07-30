import Link from "next/link";
import { Package, Plus } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { EmptyState } from "@/components/ui/EmptyState";
import { DataTableShell } from "@/components/ui/DataTableShell";
import { FilterBar } from "@/components/ui/FilterBar";
import { StatusBadge, isPackageStatus, PACKAGE_STATUSES } from "@/components/ui/StatusBadge";
import { Alert } from "@/components/ui/Alert";
import { formatFee } from "@/lib/courier/format";
import { Reveal } from "@/components/motion/Reveal";

type Shipment = { package_id: number; tracking_no: string; sender_id: number; receiver_id: number; service_id: number; weight_kg: number; shipping_fee: number | null; current_status: string; origin_hub_id: number; dest_hub_id: number };
type Service = { service_id: number; service_name: string };
type Hub = { hub_id: number; hub_code: string; hub_name: string };

export default async function ShipmentsPage({ searchParams }: { searchParams: Promise<{ q?: string; status?: string; service?: string }> }) {
  const auth = await requireRouteAccess(["CUSTOMER", "DISPATCHER"]);
  const filters = await searchParams;
  const supabase = await createClient();

  let query = supabase.from("package").select("package_id, tracking_no, sender_id, receiver_id, service_id, weight_kg, shipping_fee, current_status, origin_hub_id, dest_hub_id").order("package_id", { ascending: false });
  if (filters.q?.trim()) query = query.ilike("tracking_no", `%${filters.q.trim()}%`);
  if (filters.status && PACKAGE_STATUSES.includes(filters.status as (typeof PACKAGE_STATUSES)[number])) query = query.eq("current_status", filters.status);
  if (filters.service && /^\d+$/.test(filters.service)) query = query.eq("service_id", Number(filters.service));

  const [shipmentResponse, serviceResponse, hubResponse] = await Promise.all([
    query,
    supabase.from("service_type").select("service_id, service_name").order("service_name"),
    supabase.from("transit_hub").select("hub_id, hub_code, hub_name"),
  ]);
  const { data, error } = shipmentResponse;
  const services = serviceResponse.data;
  const hubs = hubResponse.data;
  const shipments = (data ?? []) as Shipment[];
  const serviceMap = new Map((services as Service[] | null)?.map((item) => [item.service_id, item.service_name] as const));
  const hubMap = new Map((hubs as Hub[] | null)?.map((item) => [item.hub_id, `${item.hub_name} (${item.hub_code})`] as const));

  return (
    <PageContainer>
      <PageHeader title={auth.appRole === "CUSTOMER" ? "My Shipments" : "Shipments"} description={auth.appRole === "CUSTOMER" ? "Packages where you are the sender or receiver. Row-level security enforces this scope." : "Packages visible to the Dispatcher role."} actions={auth.appRole === "CUSTOMER" ? <Link href="/shipments/new" className="focus-ring inline-flex h-9 items-center gap-2 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground"><Plus className="size-4" />New shipment</Link> : undefined} />

      <form method="get"><FilterBar>
        <input name="q" defaultValue={filters.q} placeholder="Search tracking number" className="focus-ring h-9 min-w-56 flex-1 rounded-md border border-border bg-card px-3 text-sm" />
        <select name="status" defaultValue={filters.status ?? ""} className="focus-ring h-9 rounded-md border border-border bg-card px-3 text-sm"><option value="">All statuses</option>{PACKAGE_STATUSES.map((status) => <option key={status} value={status}>{status.replaceAll("_", " ")}</option>)}</select>
        <select name="service" defaultValue={filters.service ?? ""} className="focus-ring h-9 rounded-md border border-border bg-card px-3 text-sm"><option value="">All services</option>{(services as Service[] | null)?.map((service) => <option key={service.service_id} value={service.service_id}>{service.service_name}</option>)}</select>
        <button className="focus-ring h-9 rounded-md border border-border bg-card px-4 text-sm font-medium hover:bg-muted">Apply</button>
        <Link href="/shipments" className="inline-flex h-9 items-center px-2 text-sm text-primary hover:underline">Clear</Link>
      </FilterBar></form>

      {error && <Alert tone="danger" title="Shipments unavailable">The database request was rejected or could not be completed.</Alert>}
      {(serviceResponse.error || hubResponse.error) && <Alert tone="warning" title="Reference labels unavailable">Some service or hub names could not be loaded. Existing database IDs are shown instead.</Alert>}
      {!error && (shipments.length === 0 ? <EmptyState icon={Package} title="No shipments found" description="No real shipment records match the current scope and filters." /> : (
        <Reveal>
          <DataTableShell columns={["Tracking", "Role", "Status", "Service", "Route", "Weight", "Fee"]} caption="Shipment list">
            {shipments.map((shipment) => (
              <tr key={shipment.package_id} className="transition-colors duration-150 hover:bg-muted/40">
                <td className="px-3 py-3"><Link href={`/shipments/${encodeURIComponent(shipment.tracking_no)}`} className="font-medium text-primary hover:underline">{shipment.tracking_no}</Link></td>
                <td className="px-3 py-3">{auth.customerId === shipment.sender_id ? "Sender" : auth.customerId === shipment.receiver_id ? "Receiver" : "Operational"}</td>
                <td className="px-3 py-3">{isPackageStatus(shipment.current_status) ? <StatusBadge status={shipment.current_status} /> : shipment.current_status}</td>
                <td className="px-3 py-3">{serviceMap.get(shipment.service_id) ?? `Service ${shipment.service_id}`}</td>
                <td className="px-3 py-3">{hubMap.get(shipment.origin_hub_id) ?? shipment.origin_hub_id} → {hubMap.get(shipment.dest_hub_id) ?? shipment.dest_hub_id}</td>
                <td className="px-3 py-3">{shipment.weight_kg} kg</td>
                <td className="px-3 py-3">{formatFee(shipment.shipping_fee)}</td>
              </tr>
            ))}
          </DataTableShell>
        </Reveal>
      ))}
    </PageContainer>
  );
}
