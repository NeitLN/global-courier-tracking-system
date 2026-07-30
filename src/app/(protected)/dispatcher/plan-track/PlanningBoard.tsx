'use client'

import { useState } from "react";
import { useRouter } from "next/navigation";
import { assignPackageToTripAction } from "./actions";
import { Button } from "@/components/ui/Button";
import { Alert } from "@/components/ui/Alert";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { ArrowRight, Package, Truck, Info, CheckCircle2 } from "lucide-react";

interface PlanningBoardProps {
  hubs: Array<{
    hub_id: number;
    hub_code: string;
    hub_name: string;
  }>;
  initialHubId: string;
  unassignedPackages: Array<{
    package_id: number;
    tracking_no: string;
    origin_hub_code: string;
    dest_hub_code: string;
    weight_kg: number;
    current_status: string;
  }>;
  trips: Array<{
    trip_id: number;
    route_id: number;
    origin_hub_code: string;
    dest_hub_code: string;
    mode: string;
    driver_name: string;
    vehicle_plate: string;
    depart: string;
  }>;
  assignedLegs: Array<{
    trip_id: number;
    package_id: number;
    tracking_no: string;
    loaded_at: string | null;
    unloaded_at: string | null;
  }>;
}

export function PlanningBoard({
  hubs,
  initialHubId,
  unassignedPackages,
  trips,
  assignedLegs,
}: PlanningBoardProps) {
  const router = useRouter();
  const [selectedHubId, setSelectedHubId] = useState(initialHubId);
  const [selectedTripId, setSelectedTripId] = useState<number | null>(null);
  const [isPending, setIsPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const handleHubChange = (hubId: string) => {
    setSelectedHubId(hubId);
    setSelectedTripId(null);
    setError(null);
    setSuccess(null);
    router.push(`/dispatcher/plan-track?hubId=${hubId}`);
  };

  const handleAssign = async (packageId: number) => {
    if (!selectedTripId) {
      setError("Please select a target trip first.");
      return;
    }

    setIsPending(true);
    setError(null);
    setSuccess(null);

    try {
      const res = await assignPackageToTripAction({
        tripId: selectedTripId,
        packageId,
      });

      if (res.success) {
        setSuccess(`Package was successfully assigned to trip #${selectedTripId}!`);
        router.refresh();
      } else {
        setError(res.error || "An error occurred.");
      }
    } catch (err: unknown) {
      const errorMsg = err instanceof Error ? err.message : "An error occurred";
      setError(errorMsg);
    } finally {
      setIsPending(false);
    }
  };

  // Find currently selected hub details
  const currentHub = hubs.find((h) => h.hub_id.toString() === selectedHubId);

  // Filter trips departing from the currently selected hub
  const filteredTrips = trips.filter(
    (t) => t.origin_hub_code === currentHub?.hub_code
  );

  // Find currently selected trip details
  const selectedTrip = trips.find((t) => t.trip_id === selectedTripId);

  // Find packages already assigned to the selected trip
  const selectedTripLegs = assignedLegs.filter((l) => l.trip_id === selectedTripId);

  return (
    <div className="space-y-6">
      {/* Hub Selection Header */}
      <Card>
        <CardContent className="py-4">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="space-y-1">
              <h2 className="text-lg font-bold text-foreground">Current Planning Hub</h2>
              <p className="text-caption">Select the transit hub to view unassigned shipments and scheduled trips.</p>
            </div>
            <div className="w-full sm:w-64">
              <select
                value={selectedHubId}
                onChange={(e) => handleHubChange(e.target.value)}
                className="focus-ring h-9 w-full appearance-none rounded-md border border-border bg-card px-3 pr-8 text-sm text-foreground"
              >
                <option value="">Select Hub</option>
                {hubs.map((h) => (
                  <option key={h.hub_id} value={h.hub_id.toString()}>
                    {h.hub_code} - {h.hub_name}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Notifications */}
      {error && (
        <Alert tone="danger" title="Error assigning package">
          {error}
        </Alert>
      )}

      {success && (
        <Alert tone="success" title="Success">
          {success}
        </Alert>
      )}

      {/* 3-Column Planning Board */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        
        {/* Column 1: Unassigned Packages */}
        <Card className="flex flex-col h-[600px]">
          <CardHeader className="border-b border-border py-4">
            <div className="flex items-center justify-between">
              <CardTitle className="text-sm font-bold flex items-center gap-2">
                <Package className="size-4 text-primary" />
                Unassigned Packages ({unassignedPackages.length})
              </CardTitle>
            </div>
          </CardHeader>
          <CardContent className="flex-1 overflow-y-auto p-4 space-y-3 bg-muted/10">
            {unassignedPackages.length > 0 ? (
              unassignedPackages.map((p) => (
                <div
                  key={p.package_id}
                  className="rounded-lg border border-border bg-card p-3 shadow-sm hover:border-primary-soft transition-colors space-y-2"
                >
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-xs font-semibold text-foreground">
                      {p.tracking_no}
                    </span>
                    <span className="rounded bg-muted px-1.5 py-0.5 text-[10px] text-muted-foreground font-medium uppercase">
                      {p.current_status}
                    </span>
                  </div>
                  <div className="flex justify-between text-xs text-muted-foreground">
                    <span>Destination: <strong className="text-foreground">{p.dest_hub_code}</strong></span>
                    <span>Weight: <strong className="text-foreground">{p.weight_kg} kg</strong></span>
                  </div>
                  <Button
                    size="sm"
                    variant="secondary"
                    onClick={() => handleAssign(p.package_id)}
                    disabled={!selectedTripId || isPending}
                    className="w-full flex items-center justify-center gap-1.5 py-1 text-xs"
                  >
                    Assign to Selected Trip <ArrowRight className="size-3" />
                  </Button>
                </div>
              ))
            ) : (
              <div className="flex flex-col items-center justify-center h-full text-center p-6 text-muted-foreground space-y-2 bg-card rounded-md border border-dashed">
                <Package className="size-8 stroke-1 text-muted-foreground/60" />
                <p className="text-sm font-semibold">No packages unassigned</p>
                <p className="text-xs">All packages currently held at this hub are assigned to trips.</p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Column 2: Scheduled Trips departing from chosen Hub */}
        <Card className="flex flex-col h-[600px]">
          <CardHeader className="border-b border-border py-4">
            <CardTitle className="text-sm font-bold flex items-center gap-2">
              <Truck className="size-4 text-primary" />
              Scheduled Trips ({filteredTrips.length})
            </CardTitle>
          </CardHeader>
          <CardContent className="flex-1 overflow-y-auto p-4 space-y-3 bg-muted/10">
            {filteredTrips.length > 0 ? (
              filteredTrips.map((t) => (
                <div
                  key={t.trip_id}
                  onClick={() => {
                    setSelectedTripId(t.trip_id);
                    setError(null);
                    setSuccess(null);
                  }}
                  className={`rounded-lg border p-3 shadow-sm cursor-pointer transition-all space-y-2 ${
                    selectedTripId === t.trip_id
                      ? "border-primary bg-primary-soft/10 ring-1 ring-primary"
                      : "border-border bg-card hover:border-primary-soft"
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-xs font-semibold text-foreground">
                      Trip #{t.trip_id}
                    </span>
                    <span className="rounded bg-primary-soft/10 text-primary px-1.5 py-0.5 text-[10px] font-medium uppercase">
                      {t.mode}
                    </span>
                  </div>
                  <p className="text-sm font-semibold text-foreground">
                    {t.origin_hub_code} → {t.dest_hub_code}
                  </p>
                  <div className="text-xs text-muted-foreground space-y-1">
                    <p>Driver: <strong className="text-foreground">{t.driver_name}</strong></p>
                    <p>Vehicle: <strong className="text-foreground">{t.vehicle_plate}</strong></p>
                    <p>Depart: <strong className="text-foreground">{new Date(t.depart).toLocaleString()}</strong></p>
                  </div>
                </div>
              ))
            ) : (
              <div className="flex flex-col items-center justify-center h-full text-center p-6 text-muted-foreground space-y-2 bg-card rounded-md border border-dashed">
                <Truck className="size-8 stroke-1 text-muted-foreground/60" />
                <p className="text-sm font-semibold">No scheduled trips</p>
                <p className="text-xs">No scheduled trips depart from {currentHub?.hub_code || "this hub"} today.</p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Column 3: Selected Trip Details & Already Assigned Legs */}
        <Card className="flex flex-col h-[600px]">
          <CardHeader className="border-b border-border py-4">
            <CardTitle className="text-sm font-bold flex items-center gap-2">
              <Info className="size-4 text-primary" />
              Trip Manifest Detail
            </CardTitle>
          </CardHeader>
          <CardContent className="flex-1 overflow-y-auto p-4 space-y-4 bg-muted/10">
            {selectedTrip ? (
              <div className="space-y-4 h-full flex flex-col">
                {/* Trip Header Summary */}
                <div className="bg-card rounded-lg p-3 border border-border space-y-1.5">
                  <div className="flex justify-between items-center">
                    <span className="text-xs font-semibold text-muted-foreground">SELECTED TRIP</span>
                    <span className="font-mono text-xs font-bold text-foreground">#{selectedTrip.trip_id}</span>
                  </div>
                  <h3 className="font-bold text-foreground">{selectedTrip.origin_hub_code} → {selectedTrip.dest_hub_code} ({selectedTrip.mode})</h3>
                  <p className="text-caption">Driver: {selectedTrip.driver_name} | Plate: {selectedTrip.vehicle_plate}</p>
                </div>

                {/* Assigned Leg List */}
                <div className="flex-1 overflow-y-auto space-y-2 min-h-0">
                  <h4 className="text-xs font-bold text-muted-foreground uppercase">Assigned Packages ({selectedTripLegs.length})</h4>
                  
                  {selectedTripLegs.length > 0 ? (
                    selectedTripLegs.map((l) => (
                      <div key={l.package_id} className="bg-card rounded-md border border-border p-2.5 flex items-center justify-between text-xs hover:border-primary-soft transition-colors">
                        <div className="space-y-0.5">
                          <p className="font-mono font-semibold text-foreground">{l.tracking_no}</p>
                          <p className="text-[10px] text-muted-foreground">
                            Status: {l.loaded_at ? (l.unloaded_at ? "Unloaded" : "Loaded") : "Assigned"}
                          </p>
                        </div>
                        <CheckCircle2 className="size-4 text-success" />
                      </div>
                    ))
                  ) : (
                    <div className="text-center py-8 text-muted-foreground text-xs bg-card rounded-md border border-dashed flex flex-col items-center justify-center gap-1.5">
                      <Package className="size-6 text-muted-foreground/50" />
                      <p className="font-semibold">Empty Manifest</p>
                      <p className="text-[10px]">Select unassigned packages on the left to assign them to this trip.</p>
                    </div>
                  )}
                </div>
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center h-full text-center p-6 text-muted-foreground space-y-2 bg-card rounded-md border border-dashed">
                <Info className="size-8 stroke-1 text-muted-foreground/60" />
                <p className="text-sm font-semibold">Select a trip</p>
                <p className="text-xs">Select any scheduled trip from the middle column to manage its shipment manifest.</p>
              </div>
            )}
          </CardContent>
        </Card>

      </div>
    </div>
  );
}
