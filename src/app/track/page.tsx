import Link from "next/link";
import { Search, Truck } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { courierErrorMessage } from "@/lib/courier/errors";
import { formatDateTime } from "@/lib/courier/format";
import { StatusBadge, isPackageStatus } from "@/components/ui/StatusBadge";
import { Alert } from "@/components/ui/Alert";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Reveal } from "@/components/motion/Reveal";
import { StaggerList, StaggerItem } from "@/components/motion/StaggerList";

export const dynamic = "force-dynamic";

type PublicTracking = {
  tracking_no: string;
  current_status: string;
  service_type: string;
  origin_hub: { code: string; name: string };
  destination_hub: { code: string; name: string };
  latest_update: string | null;
  timeline: Array<{
    event_order: number;
    status: string;
    event_time: string;
    hub: { code: string; name: string };
    is_current: boolean;
  }>;
};

export default async function TrackPage({ searchParams }: { searchParams: Promise<{ tracking?: string }> }) {
  const { tracking = "" } = await searchParams;
  let result: PublicTracking | null = null;
  let error: string | null = null;

  if (tracking.trim()) {
    const supabase = await createClient();
    const response = await supabase.rpc("fn_public_track_package", { p_tracking_no: tracking.trim() });
    if (response.error) error = courierErrorMessage(response.error.message);
    else result = response.data as PublicTracking;
  }

  return (
    <main className="min-h-dvh bg-background px-4 py-10 sm:px-6">
      <div className="mx-auto flex max-w-3xl flex-col gap-6">
        <div className="flex items-center justify-between gap-4">
          <Link href="/" className="flex items-center gap-2 font-semibold text-foreground">
            <span className="flex size-9 items-center justify-center rounded-md bg-primary text-primary-foreground"><Truck className="size-5" /></span>
            Global Courier
          </Link>
          <Link href="/login" className="text-sm font-medium text-primary hover:underline">Staff or customer sign in</Link>
        </div>

        <div>
          <h1 className="text-page-title">Track a package</h1>
          <p className="text-body mt-1 text-muted-foreground">Public tracking shows operational milestones only. Personal and internal staff details remain private.</p>
        </div>

        <form method="get" className="flex flex-col gap-3 rounded-lg border border-border bg-card p-4 sm:flex-row sm:items-end">
          <div className="flex-1">
            <label htmlFor="tracking" className="text-label">Tracking number</label>
            <input id="tracking" name="tracking" defaultValue={tracking} required placeholder="GC-YYYYMMDD-XXXXXXXXXX" className="focus-ring mt-1.5 h-10 w-full rounded-md border border-border bg-card px-3 text-sm uppercase text-foreground" />
          </div>
          <button className="focus-ring inline-flex h-10 items-center justify-center gap-2 rounded-md bg-primary px-5 text-sm font-medium text-primary-foreground hover:bg-primary/90"><Search className="size-4" />Track</button>
        </form>

        {error && <Alert tone="danger" title="Unable to track package">{error}</Alert>}

        {result && (
          <>
            <Reveal>
              <Card>
                <CardHeader><CardTitle>{result.tracking_no}</CardTitle></CardHeader>
                <CardContent className="grid gap-4 sm:grid-cols-2">
                  <div><p className="text-label">Current status</p>{isPackageStatus(result.current_status) ? <StatusBadge status={result.current_status} /> : <p className="text-body">{result.current_status}</p>}</div>
                  <div><p className="text-label">Service type</p><p className="text-body">{result.service_type}</p></div>
                  <div><p className="text-label">Origin</p><p className="text-body">{result.origin_hub.name} ({result.origin_hub.code})</p></div>
                  <div><p className="text-label">Destination</p><p className="text-body">{result.destination_hub.name} ({result.destination_hub.code})</p></div>
                  <div className="sm:col-span-2"><p className="text-label">Latest update</p><p className="text-body">{formatDateTime(result.latest_update)}</p></div>
                </CardContent>
              </Card>
            </Reveal>

            <Reveal delay={0.08}>
              <Card>
                <CardHeader><CardTitle>Tracking timeline</CardTitle></CardHeader>
                <CardContent>
                  <StaggerList as="ol" className="flex flex-col gap-4">
                    {result.timeline.map((event) => (
                      <StaggerItem as="li" key={`${event.event_order}-${event.event_time}`} className="flex gap-3">
                        <span className={`mt-1 flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-semibold ${event.is_current ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"}`}>{event.event_order}</span>
                        <div className="min-w-0"><div className="flex flex-wrap items-center gap-2">{isPackageStatus(event.status) ? <StatusBadge status={event.status} /> : <span>{event.status}</span>}{event.is_current && <span className="text-caption">Current event</span>}</div><p className="text-body mt-1">{event.hub.name} ({event.hub.code})</p><p className="text-caption">{formatDateTime(event.event_time)}</p></div>
                      </StaggerItem>
                    ))}
                  </StaggerList>
                </CardContent>
              </Card>
            </Reveal>
          </>
        )}
      </div>
    </main>
  );
}
