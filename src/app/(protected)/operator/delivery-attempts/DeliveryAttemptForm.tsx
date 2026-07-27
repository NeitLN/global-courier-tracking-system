'use client'

import { useState, useTransition } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/Card";
import { Input } from "@/components/ui/Input";
import { SelectField } from "@/components/ui/SelectField";
import { Button } from "@/components/ui/Button";
import { Alert } from "@/components/ui/Alert";
import { recordDeliveryAttempt, type DeliveryAttemptResult } from "./actions";

interface DriverOption {
  driver_id: number;
  full_name: string;
  license_no: string;
}

interface DeliveryAttemptFormProps {
  drivers: DriverOption[];
  hubCode: string;
  hubName: string;
}

export function DeliveryAttemptForm({ drivers, hubCode, hubName }: DeliveryAttemptFormProps) {
  const [isPending, startTransition] = useTransition();
  const [result, setResult] = useState<DeliveryAttemptResult | null>(null);
  const [outcome, setOutcome] = useState("FAILED");

  const successData = (result && result.success) ? (result.data as { trackingNo: string; outcome: string; driverId: number; attemptTime: string; failureReason: string | null; notes: string | null }) : null;

  // Format current local time for datetime-local input
  const getLocalDateTime = () => {
    const now = new Date();
    const offset = now.getTimezoneOffset();
    const localNow = new Date(now.getTime() - offset * 60 * 1000);
    return localNow.toISOString().slice(0, 16);
  };

  const [attemptTime, setAttemptTime] = useState(getLocalDateTime());

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setResult(null);
    const formData = new FormData(event.currentTarget);

    startTransition(async () => {
      const res = await recordDeliveryAttempt(formData);
      setResult(res);
      if (res.success) {
        // Reset the tracking number but keep time/notes or reset them appropriately
        const form = event.target as HTMLFormElement;
        const trackingInput = form.querySelector('input[name="tracking_no"]') as HTMLInputElement;
        if (trackingInput) {
          trackingInput.value = "";
          trackingInput.focus();
        }
        setAttemptTime(getLocalDateTime());
      }
    });
  };

  return (
    <div className="space-y-4">
      {result && !result.success && (
        <Alert tone="danger" title="Delivery Attempt Rejected">
          {result.error}
        </Alert>
      )}

      {successData && (
        <Alert tone="success" title="Delivery Attempt Recorded Successfully">
          <div className="mt-1 text-sm space-y-1">
            <p><strong>Tracking Number:</strong> {successData.trackingNo}</p>
            <p><strong>Outcome:</strong> {successData.outcome}</p>
            <p><strong>Driver:</strong> {drivers.find(d => d.driver_id === successData.driverId)?.full_name || "Unknown Driver"}</p>
            <p><strong>Attempt Time:</strong> {new Date(successData.attemptTime).toLocaleString()}</p>
            {successData.failureReason && <p><strong>Failure Reason:</strong> {successData.failureReason}</p>}
            {successData.notes && <p><strong>Notes:</strong> {successData.notes}</p>}
            {successData.outcome === "SUCCESS" && (
              <p className="text-success-foreground font-semibold mt-1">✓ Package status has been atomically updated to DELIVERED.</p>
            )}
          </div>
        </Alert>
      )}

      <form onSubmit={handleSubmit}>
        <Card>
          <CardHeader>
            <CardTitle>Record Delivery Attempt</CardTitle>
            <CardDescription>
              Log a delivery attempt by one of your hub&apos;s drivers. If successful, the package status is atomically set to DELIVERED in a transaction. If failed, a failure reason is strictly required.
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            <div>
              <Input
                name="tracking_no"
                label="Tracking Number"
                placeholder="e.g. TRK000001"
                required
                autoComplete="off"
              />
            </div>

            <SelectField name="driver_id" label="Assigned Driver" required defaultValue="">
              <option value="" disabled>Select driver</option>
              {drivers.map((d) => (
                <option key={d.driver_id} value={d.driver_id}>
                  {d.full_name} ({d.license_no})
                </option>
              ))}
            </SelectField>

            <SelectField
              name="outcome"
              label="Delivery Outcome"
              required
              value={outcome}
              onChange={(e) => setOutcome(e.target.value)}
            >
              <option value="FAILED">Failed Attempt (FAILED)</option>
              <option value="SUCCESS">Successful Delivery (SUCCESS)</option>
            </SelectField>

            <Input
              name="attempt_time"
              type="datetime-local"
              label="Attempt Time"
              required
              value={attemptTime}
              onChange={(e) => setAttemptTime(e.target.value)}
            />

            {outcome === "FAILED" && (
              <div className="sm:col-span-2">
                <Input
                  name="failure_reason"
                  label="Failure Reason"
                  placeholder="e.g. Customer not home, Incorrect address, Refused by recipient..."
                  required
                />
              </div>
            )}

            <div className="sm:col-span-2">
              <Input
                name="notes"
                label="Operational Notes (Optional)"
                placeholder="e.g. Package was left in parcel locker, rain damage on outer box..."
              />
            </div>

            <div className="sm:col-span-2 rounded-md bg-muted p-3 text-sm text-muted-foreground">
              <p><strong>Hub Context:</strong> {hubName} ({hubCode})</p>
              <p className="mt-1 font-caption">Only drivers based at your hub are eligible to be selected for delivery attempts.</p>
            </div>

            <div className="sm:col-span-2 flex justify-end">
              <Button type="submit" disabled={isPending}>
                {isPending ? "Recording Attempt..." : "Record Attempt"}
              </Button>
            </div>
          </CardContent>
        </Card>
      </form>
    </div>
  );
}
