'use client'

import { useState, useTransition } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/Card";
import { Input } from "@/components/ui/Input";
import { SelectField } from "@/components/ui/SelectField";
import { Button } from "@/components/ui/Button";
import { Alert } from "@/components/ui/Alert";
import { recordCheckpointScan, type ScanResult } from "./actions";

interface ScanFormProps {
  staffName: string;
  hubCode: string;
  hubName: string;
}

export function ScanForm({ staffName, hubCode, hubName }: ScanFormProps) {
  const [isPending, startTransition] = useTransition();
  const [result, setResult] = useState<ScanResult | null>(null);
  
  const successData = (result && result.success) ? (result.data as { trackingNo: string; statusCode: string; eventTime: string }) : null;
  
  // Format current local time for datetime-local input
  const getLocalDateTime = () => {
    const now = new Date();
    const offset = now.getTimezoneOffset();
    const localNow = new Date(now.getTime() - offset * 60 * 1000);
    return localNow.toISOString().slice(0, 16);
  };

  const [eventTime, setEventTime] = useState(getLocalDateTime());

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setResult(null);
    const formData = new FormData(event.currentTarget);

    startTransition(async () => {
      const res = await recordCheckpointScan(formData);
      setResult(res);
      if (res.success) {
        // Reset the tracking number but keep time/remarks or reset them appropriately
        const form = event.target as HTMLFormElement;
        const trackingInput = form.querySelector('input[name="tracking_no"]') as HTMLInputElement;
        if (trackingInput) {
          trackingInput.value = "";
          trackingInput.focus();
        }
        setEventTime(getLocalDateTime());
      }
    });
  };

  return (
    <div className="space-y-4">
      {result && !result.success && (
        <Alert tone="danger" title="Scan Rejected by Database">
          {result.error}
        </Alert>
      )}

      {successData && (
        <Alert tone="success" title="Checkpoint Scan Recorded Successfully">
          <div className="mt-1 text-sm space-y-1">
            <p><strong>Tracking Number:</strong> {successData.trackingNo}</p>
            <p><strong>New Status:</strong> {successData.statusCode}</p>
            <p><strong>Hub:</strong> {hubName} ({hubCode})</p>
            <p><strong>Event Time:</strong> {new Date(successData.eventTime).toLocaleString()}</p>
            <p><strong>Recorded By:</strong> {staffName}</p>
          </div>
        </Alert>
      )}

      <form onSubmit={handleSubmit}>
        <Card>
          <CardHeader>
            <CardTitle>Scan Details</CardTitle>
            <CardDescription>
              Any attempt to scan for a different hub, forge an operator identity, skip steps, or record backward statuses will be strictly blocked by database triggers and RLS.
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            <div className="sm:col-span-2">
              <Input
                name="tracking_no"
                label="Tracking Number"
                placeholder="e.g. TRK000001"
                required
                autoComplete="off"
              />
            </div>
            
            <SelectField name="status_code" label="New Status" required defaultValue="IN_TRANSIT">
              <option value="PICKED_UP">Picked Up (PICKED_UP)</option>
              <option value="IN_TRANSIT">In Transit (IN_TRANSIT)</option>
              <option value="OUT_FOR_DELIVERY">Out For Delivery (OUT_FOR_DELIVERY)</option>
              <option value="DELIVERED">Delivered (DELIVERED)</option>
              <option value="RETURNED">Returned (RETURNED)</option>
            </SelectField>

            <Input
              name="event_time"
              type="datetime-local"
              label="Event Time"
              required
              value={eventTime}
              onChange={(e) => setEventTime(e.target.value)}
            />

            <div className="sm:col-span-2">
              <Input
                name="remarks"
                label="Remarks / Notes (Optional)"
                placeholder="e.g. Received in good condition, loading into delivery van..."
              />
            </div>

            <div className="sm:col-span-2 rounded-md bg-muted p-3 text-sm text-muted-foreground space-y-1">
              <p><strong>Operator Context (Server-Scoped):</strong></p>
              <p>• Staff Member: <span className="font-medium">{staffName}</span></p>
              <p>• Assigned Hub: <span className="font-medium">{hubName} ({hubCode})</span></p>
            </div>

            <div className="sm:col-span-2 flex justify-end">
              <Button type="submit" disabled={isPending}>
                {isPending ? "Recording Scan..." : "Submit Scan"}
              </Button>
            </div>
          </CardContent>
        </Card>
      </form>
    </div>
  );
}
