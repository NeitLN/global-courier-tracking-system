import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { PlanningBoard } from "./PlanningBoard";
import { Reveal } from "@/components/motion/Reveal";

interface PageProps {
  searchParams: Promise<{
    hubId?: string;
  }>;
}

export default async function PlanTrackPage({ searchParams }: PageProps) {
  await requireRouteAccess(["DISPATCHER"]);

  const params = await searchParams;
  const supabase = await createClient();

  // Load all transit hubs for selector dropdown
  const { data: hubs = [] } = await supabase
    .from("transit_hub")
    .select("hub_id, hub_code, hub_name")
    .order("hub_code", { ascending: true });

  // Default to first hub in database if no parameter in URL
  const activeHubId = params.hubId || (hubs && hubs.length > 0 ? hubs[0].hub_id.toString() : "");

  // Load unassigned packages currently held at the active hub
  let unassignedPackages: Array<{
    package_id: number;
    tracking_no: string;
    origin_hub_code: string;
    dest_hub_code: string;
    weight_kg: number;
    current_status: string;
  }> = [];

  if (activeHubId) {
    const { data } = await supabase.rpc("fn_get_dispatcher_unassigned_packages", {
      p_hub_id: parseInt(activeHubId, 10),
    });
    unassignedPackages = (data as typeof unassignedPackages) || [];
  }

  // Load all scheduled trips
  const { data: trips = [] } = await supabase.rpc("fn_get_dispatcher_trips");

  // Load all package legs currently assigned to trips
  const { data: legs = [] } = await supabase
    .from("package_leg")
    .select(`
      trip_id,
      package_id,
      package (
        tracking_no
      ),
      loaded_at,
      unloaded_at
    `);

  const assignedLegs = ((legs || []) as unknown as Array<{
    trip_id: number;
    package_id: number;
    package: { tracking_no: string } | null;
    loaded_at: string | null;
    unloaded_at: string | null;
  }>).map((l) => ({
    trip_id: l.trip_id,
    package_id: l.package_id,
    tracking_no: l.package?.tracking_no || "",
    loaded_at: l.loaded_at,
    unloaded_at: l.unloaded_at,
  }));

  return (
    <PageContainer>
      <PageHeader
        title="Planning Board"
        description="Assign unassigned shipments to scheduled trips departing from transit hubs."
      />

      <Reveal>
        <PlanningBoard
          hubs={hubs || []}
          initialHubId={activeHubId}
          unassignedPackages={unassignedPackages}
          trips={trips || []}
          assignedLegs={assignedLegs}
        />
      </Reveal>
    </PageContainer>
  );
}
