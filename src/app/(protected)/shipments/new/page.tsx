import Link from "next/link";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Alert } from "@/components/ui/Alert";
import { Input } from "@/components/ui/Input";
import { SelectField } from "@/components/ui/SelectField";
import { Button } from "@/components/ui/Button";
import { registerShipment } from "./actions";
import { Reveal } from "@/components/motion/Reveal";

type Service = { service_id: number; service_name: string; max_weight_kg: number };
type Hub = { hub_id: number; hub_code: string; hub_name: string };

export default async function NewShipmentPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  await requireRouteAccess(["CUSTOMER"]);
  const { error } = await searchParams;
  const supabase = await createClient();
  const [{ data: services, error: serviceError }, { data: hubs, error: hubError }] = await Promise.all([
    supabase.from("service_type").select("service_id, service_name, max_weight_kg").order("service_name"),
    supabase.from("transit_hub").select("hub_id, hub_code, hub_name").order("hub_name"),
  ]);

  return (
    <PageContainer className="max-w-3xl">
      <PageHeader title="Register a new shipment" description="PostgreSQL validates the package, calculates the final shipping fee, inserts the package, and creates the REGISTERED event in one transaction." actions={<Link href="/shipments" className="text-sm font-medium text-primary hover:underline">Back to shipments</Link>} />

      {error && <Alert tone="danger" title="Shipment was not registered">{error}</Alert>}
      {(serviceError || hubError || !services || !hubs) ? (
        <Alert tone="danger" title="Reference data unavailable">Service types or hubs could not be loaded, so registration is disabled rather than submitting incomplete values.</Alert>
      ) : (
      <Reveal><form action={registerShipment}>
        <Card>
          <CardHeader><CardTitle>Shipment details</CardTitle></CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            <div className="sm:col-span-2"><Input name="receiver_email" type="email" label="Receiver email" hint="The receiver must already exist as a customer. Lookup is exact and does not expose the customer directory." required /></div>
            <SelectField name="service_id" label="Service type" required defaultValue="">
              <option value="" disabled>Select a service</option>
              {(services as Service[] | null)?.map((service) => <option key={service.service_id} value={service.service_id}>{service.service_name} — max {service.max_weight_kg} kg</option>)}
            </SelectField>
            <Input name="weight_kg" type="number" min="0.01" step="0.01" label="Weight (kg)" required />
            <SelectField name="origin_hub_id" label="Origin hub" required defaultValue="">
              <option value="" disabled>Select origin</option>
              {(hubs as Hub[] | null)?.map((hub) => <option key={hub.hub_id} value={hub.hub_id}>{hub.hub_name} ({hub.hub_code})</option>)}
            </SelectField>
            <SelectField name="dest_hub_id" label="Destination hub" required defaultValue="">
              <option value="" disabled>Select destination</option>
              {(hubs as Hub[] | null)?.map((hub) => <option key={hub.hub_id} value={hub.hub_id}>{hub.hub_name} ({hub.hub_code})</option>)}
            </SelectField>
            <Input name="length_cm" type="number" min="0.01" step="0.01" label="Length (cm)" />
            <Input name="width_cm" type="number" min="0.01" step="0.01" label="Width (cm)" />
            <Input name="height_cm" type="number" min="0.01" step="0.01" label="Height (cm)" />
            <div className="sm:col-span-2 rounded-md bg-muted p-3 text-sm text-muted-foreground">The frontend does not calculate or estimate fees. The final fee shown after submission is returned by <code>fn_register_package</code>.</div>
            <div className="sm:col-span-2 flex justify-end"><Button type="submit">Register shipment</Button></div>
          </CardContent>
        </Card>
      </form></Reveal>
      )}
    </PageContainer>
  );
}
