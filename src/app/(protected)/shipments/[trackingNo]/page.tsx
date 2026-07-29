import Link from "next/link";
import { notFound } from "next/navigation";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Alert } from "@/components/ui/Alert";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { StatusBadge, isPackageStatus } from "@/components/ui/StatusBadge";
import { formatDateTime, formatInterval, formatFee } from "@/lib/courier/format";

type Shipment = { package_id: number; tracking_no: string; sender_id: number; receiver_id: number; service_id: number; weight_kg: number; length_cm: number | null; width_cm: number | null; height_cm: number | null; shipping_fee: number | null; origin_hub_id: number; dest_hub_id: number; current_status: string };
type ChainEvent = { event_id: number; event_time: string; hub_id: number; status_code: string; elapsed_interval: string | null };
type Hub = { hub_id: number; hub_code: string; hub_name: string };
type Service = { service_id: number; service_name: string };
type Leg = { trip_id: number; package_id: number; loaded_at: string | null; unloaded_at: string | null };
type Attempt = { attempt_id: number; attempt_time: string; outcome: string; failure_reason: string | null };

export default async function ShipmentDetailPage({ params, searchParams }: { params: Promise<{ trackingNo: string }>; searchParams: Promise<{ created?: string }> }) {
  const auth = await requireRouteAccess(["CUSTOMER", "DISPATCHER"]);
  const { trackingNo } = await params;
  const { created } = await searchParams;
  const supabase = await createClient();

  const shipmentResponse = await supabase.from("package").select("package_id, tracking_no, sender_id, receiver_id, service_id, weight_kg, length_cm, width_cm, height_cm, shipping_fee, origin_hub_id, dest_hub_id, current_status").eq("tracking_no", trackingNo.toUpperCase()).maybeSingle();
  if (shipmentResponse.error) throw new Error("Shipment query failed");
  if (!shipmentResponse.data) notFound();
  const shipment = shipmentResponse.data as Shipment;

  const [{ data: chain, error: chainError }, { data: hubs }, { data: service }, { data: legs }, { data: attempts }] = await Promise.all([
    supabase.rpc("fn_chain_of_custody", { p_tracking_no: shipment.tracking_no }),
    supabase.from("transit_hub").select("hub_id, hub_code, hub_name"),
    supabase.from("service_type").select("service_id, service_name").eq("service_id", shipment.service_id).maybeSingle(),
    supabase.from("package_leg").select("trip_id, package_id, loaded_at, unloaded_at").eq("package_id", shipment.package_id).order("trip_id"),
    supabase.from("delivery_attempt").select("attempt_id, attempt_time, outcome, failure_reason").eq("package_id", shipment.package_id).order("attempt_time", { ascending: false }),
  ]);

  const hubMap = new Map((hubs as Hub[] | null)?.map((hub) => [hub.hub_id, `${hub.hub_name} (${hub.hub_code})`] as const));
  const events = (chain ?? []) as ChainEvent[];
  const serviceName = (service as Service | null)?.service_name ?? `Service ${shipment.service_id}`;

  return (
    <PageContainer>
      <PageHeader title={shipment.tracking_no} description={auth.customerId === shipment.sender_id ? "You are the sender." : auth.customerId === shipment.receiver_id ? "You are the receiver." : "Dispatcher operational view."} actions={<Link href="/shipments" className="text-sm font-medium text-primary hover:underline">Back to shipments</Link>} />
      {created === "1" && <Alert tone="success" title="Shipment registered">The database returned tracking number {shipment.tracking_no}, calculated a fee of {formatFee(shipment.shipping_fee)}, and created the initial REGISTERED event.</Alert>}
      {chainError && <Alert tone="danger" title="Timeline unavailable">Chain-of-custody data could not be loaded.</Alert>}

      <Card>
        <CardHeader><CardTitle>Overview</CardTitle></CardHeader>
        <CardContent className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div><p className="text-label">Status</p>{isPackageStatus(shipment.current_status) ? <StatusBadge status={shipment.current_status} /> : <p>{shipment.current_status}</p>}</div>
          <div><p className="text-label">Service</p><p className="text-body">{serviceName}</p></div>
          <div><p className="text-label">Weight</p><p className="text-body">{shipment.weight_kg} kg</p></div>
          <div><p className="text-label">Database fee</p><p className="text-body">{formatFee(shipment.shipping_fee)}</p></div>
          <div className="sm:col-span-2"><p className="text-label">Origin</p><p className="text-body">{hubMap.get(shipment.origin_hub_id) ?? shipment.origin_hub_id}</p></div>
          <div className="sm:col-span-2"><p className="text-label">Destination</p><p className="text-body">{hubMap.get(shipment.dest_hub_id) ?? shipment.dest_hub_id}</p></div>
          {(shipment.length_cm || shipment.width_cm || shipment.height_cm) && <div className="sm:col-span-2 lg:col-span-4"><p className="text-label">Dimensions</p><p className="text-body">{shipment.length_cm ?? "—"} × {shipment.width_cm ?? "—"} × {shipment.height_cm ?? "—"} cm</p></div>}
        </CardContent>
      </Card>

      {events.length > 0 && <Card>
        <CardHeader><CardTitle>Timeline and chain of custody</CardTitle></CardHeader>
        <CardContent>
          <p className="text-caption mb-4">Inter-scan interval measures elapsed time between consecutive scans; it is not necessarily pure hub dwell time.</p>
          <ol className="flex flex-col gap-4">{events.map((event, index) => <li key={event.event_id} className="flex gap-3"><span className={`mt-1 flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-semibold ${index === events.length - 1 ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"}`}>{index + 1}</span><div><div className="flex flex-wrap items-center gap-2">{isPackageStatus(event.status_code) ? <StatusBadge status={event.status_code} /> : event.status_code}{index === events.length - 1 && <span className="text-caption">Current event</span>}</div><p className="text-body mt-1">{hubMap.get(event.hub_id) ?? `Hub ${event.hub_id}`}</p><p className="text-caption">{formatDateTime(event.event_time)} · Inter-scan interval: {formatInterval(event.elapsed_interval)}</p></div></li>)}</ol>
        </CardContent>
      </Card>}

      {((legs as Leg[] | null)?.length ?? 0) > 0 && <Card><CardHeader><CardTitle>Trip legs</CardTitle></CardHeader><CardContent className="space-y-3">{(legs as Leg[]).map((leg, index) => <div key={`${leg.trip_id}-${leg.package_id}`} className="rounded-md border border-border p-3 text-sm"><p className="font-medium">Leg {index + 1} · Trip {leg.trip_id}</p><p className="text-caption">Loaded: {formatDateTime(leg.loaded_at)} · Unloaded: {formatDateTime(leg.unloaded_at)}</p></div>)}</CardContent></Card>}

      {((attempts as Attempt[] | null)?.length ?? 0) > 0 && <Card><CardHeader><CardTitle>Delivery attempts</CardTitle></CardHeader><CardContent className="space-y-3">{(attempts as Attempt[]).map((attempt) => <div key={attempt.attempt_id} className="rounded-md border border-border p-3 text-sm"><p className="font-medium">{attempt.outcome}</p><p className="text-caption">{formatDateTime(attempt.attempt_time)}{attempt.failure_reason ? ` · ${attempt.failure_reason}` : ""}</p></div>)}</CardContent></Card>}
    </PageContainer>
  );
}
