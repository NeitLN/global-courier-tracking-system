'use client'

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createTripAction } from "./actions";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { SelectField } from "@/components/ui/SelectField";
import { Alert } from "@/components/ui/Alert";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";

interface TripFormProps {
  routes: Array<{
    route_id: number;
    origin_hub_code: string;
    origin_hub_name: string;
    dest_hub_code: string;
    dest_hub_name: string;
    mode: string;
  }>;
  vehicles: Array<{
    vehicle_id: number;
    plate_no: string;
    vehicle_type: string;
    home_hub_code: string;
  }>;
  drivers: Array<{
    driver_id: number;
    full_name: string;
    base_hub_code: string;
  }>;
}

export function TripForm({ routes, vehicles, drivers }: TripFormProps) {
  const router = useRouter();
  const [routeId, setRouteId] = useState("");
  const [vehicleId, setVehicleId] = useState("");
  const [driverId, setDriverId] = useState("");
  const [depart, setDepart] = useState("");
  const [isPending, setIsPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!routeId || !vehicleId || !driverId || !depart) {
      setError("Please fill in all fields.");
      return;
    }

    setIsPending(true);
    setError(null);
    setSuccess(false);

    try {
      const res = await createTripAction({
        routeId: parseInt(routeId, 10),
        vehicleId: parseInt(vehicleId, 10),
        driverId: parseInt(driverId, 10),
        depart,
      });

      if (res.success) {
        setSuccess(true);
        setRouteId("");
        setVehicleId("");
        setDriverId("");
        setDepart("");
        router.refresh();
      } else {
        setError(res.error || "An unexpected error occurred.");
      }
    } catch (err: unknown) {
      const errorMsg = err instanceof Error ? err.message : "An error occurred";
      setError(errorMsg);
    } finally {
      setIsPending(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Schedule New Trip</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          {error && (
            <Alert tone="danger" title="Error scheduling trip">
              {error}
            </Alert>
          )}

          {success && (
            <Alert tone="success" title="Success">
              Trip has been scheduled successfully!
            </Alert>
          )}

          <div className="space-y-4">
            <SelectField
              label="Route"
              value={routeId}
              onChange={(e) => setRouteId(e.target.value)}
              disabled={isPending}
              required
            >
              <option value="">Select Route</option>
              {routes.map((r) => (
                <option key={r.route_id} value={r.route_id}>
                  {r.origin_hub_code} → {r.dest_hub_code} ({r.mode})
                </option>
              ))}
            </SelectField>

            <SelectField
              label="Vehicle"
              value={vehicleId}
              onChange={(e) => setVehicleId(e.target.value)}
              disabled={isPending}
              required
            >
              <option value="">Select Vehicle</option>
              {vehicles.map((v) => (
                <option key={v.vehicle_id} value={v.vehicle_id}>
                  {v.plate_no} - {v.vehicle_type} (Home: {v.home_hub_code})
                </option>
              ))}
            </SelectField>

            <SelectField
              label="Driver"
              value={driverId}
              onChange={(e) => setDriverId(e.target.value)}
              disabled={isPending}
              required
            >
              <option value="">Select Driver</option>
              {drivers.map((d) => (
                <option key={d.driver_id} value={d.driver_id}>
                  {d.full_name} (Base: {d.base_hub_code})
                </option>
              ))}
            </SelectField>

            <Input
              type="datetime-local"
              label="Departure Time"
              value={depart}
              onChange={(e) => setDepart(e.target.value)}
              disabled={isPending}
              required
            />
          </div>

          <Button type="submit" className="w-full" isLoading={isPending}>
            Schedule Trip
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
