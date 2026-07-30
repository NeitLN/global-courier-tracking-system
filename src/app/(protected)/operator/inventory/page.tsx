import Link from "next/link";
import { ClipboardList, Search } from "lucide-react";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardContent } from "@/components/ui/Card";
import { Alert } from "@/components/ui/Alert";
import { Input } from "@/components/ui/Input";
import { SelectField } from "@/components/ui/SelectField";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { formatDateTime } from "@/lib/courier/format";
import { courierErrorMessage } from "@/lib/courier/errors";

export const dynamic = "force-dynamic";

interface InventoryRow {
  package_id: number;
  tracking_no: string;
  current_status: string;
  latest_event_time: string;
}

interface PackageDetail {
  package_id: number;
  weight_kg: number;
  service_type: { service_name: string };
  transit_hub: { hub_code: string; hub_name: string };
}

function getRelativeTimeString(dateStr: string): string {
  const diffMs = Date.now() - new Date(dateStr).getTime();
  const diffMins = Math.floor(diffMs / 60000);
  if (diffMins < 1) return "Just now";
  if (diffMins < 60) return `${diffMins} min${diffMins > 1 ? "s" : ""} ago`;
  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours} hr${diffHours > 1 ? "s" : ""} ago`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays} day${diffDays > 1 ? "s" : ""} ago`;
}

export default async function OperatorInventoryPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; status?: string; service?: string }>;
}) {
  const auth = await requireRouteAccess(["HUB_OPERATOR"]);
  const staffId = auth.staffId;

  if (!staffId) {
    return (
      <PageContainer>
        <PageHeader title="Current Inventory" description="Packages currently held at your hub." />
        <Alert tone="danger" title="Account Mismatch">
          Your active profile is assigned as a Hub Operator, but is not linked to any row in the <code>staff</code> table.
        </Alert>
      </PageContainer>
    );
  }

  const { search, status, service } = await searchParams;
  const searchQuery = search?.trim().toUpperCase() || "";
  const statusFilter = status || "";
  const serviceFilter = service || "";

  const supabase = await createClient();

  // 1. Fetch staff member's hub_id
  const { data: staff, error: staffError } = await supabase
    .from("staff")
    .select(`
      full_name,
      hub_id,
      transit_hub (
        hub_code,
        hub_name
      )
    `)
    .eq("staff_id", staffId)
    .single();

  if (staffError || !staff) {
    return (
      <PageContainer>
        <PageHeader title="Current Inventory" description="Packages currently held at your hub." />
        <Alert tone="danger" title="Staff Data Error">
          Could not retrieve your staff record or assigned hub details from the database.
        </Alert>
      </PageContainer>
    );
  }

  const hubId = staff.hub_id;
  const hubRelation = staff.transit_hub as unknown as { hub_code: string; hub_name: string }[] | { hub_code: string; hub_name: string } | null;
  const hub = Array.isArray(hubRelation) ? hubRelation[0] : hubRelation;

  // 2. Fetch the current hub inventory via RPC
  const { data: inventory, error: rpcError } = await supabase.rpc("fn_current_hub_inventory", {
    p_hub_id: hubId,
  });

  if (rpcError) {
    return (
      <PageContainer>
        <PageHeader title="Current Inventory" description="Packages currently held at your hub." />
        <Alert tone="danger" title="Database Error">
          {courierErrorMessage(rpcError.message, "OPERATOR_HUB_INVENTORY", auth.userId)}
        </Alert>
      </PageContainer>
    );
  }

  const typedInventory = (inventory || []) as InventoryRow[];

  // 3. Fetch services for the filter dropdown
  const { data: services } = await supabase
    .from("service_type")
    .select("service_name")
    .order("service_name");

  // 4. Fetch additional package details for the items currently in the hub
  const packageIds = typedInventory.map((item) => item.package_id);
  const packageDetailsMap = new Map<number, PackageDetail>();

  if (packageIds.length > 0) {
    const { data: details } = await supabase
      .from("package")
      .select(`
        package_id,
        weight_kg,
        service_type ( service_name ),
        transit_hub:dest_hub_id ( hub_code, hub_name )
      `)
      .in("package_id", packageIds);

    if (details) {
      (details as unknown as PackageDetail[]).forEach((p) => {
        packageDetailsMap.set(p.package_id, p);
      });
    }
  }

  // 5. Combine and Filter in Next.js Server Side
  const filteredInventory = typedInventory
    .map((item) => {
      const detail = packageDetailsMap.get(item.package_id);
      return {
        ...item,
        weight: detail?.weight_kg || 0,
        serviceName: detail?.service_type?.service_name || "Unknown",
        destHubCode: detail?.transit_hub?.hub_code || "UNK",
        destHubName: detail?.transit_hub?.hub_name || "Unknown Hub",
      };
    })
    .filter((item) => {
      if (searchQuery && !item.tracking_no.includes(searchQuery)) return false;
      if (statusFilter && item.current_status !== statusFilter) return false;
      if (serviceFilter && item.serviceName !== serviceFilter) return false;
      return true;
    });

  return (
    <PageContainer>
      <PageHeader
        title="Current Inventory"
        description={`Real-time listing of packages currently held at ${hub?.hub_name || "your hub"} (${hub?.hub_code || "UNKNOWN"}).`}
        actions={
          <Link href="/operator/scans" className="focus-ring inline-flex h-9 items-center justify-center rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground hover:bg-primary/90">
            Record checkpoint scan
          </Link>
        }
      />

      <Card className="mb-6">
        <CardContent className="pt-6">
          <form method="GET" className="grid gap-4 sm:grid-cols-4 items-end">
            <div>
              <Input
                name="search"
                label="Search Tracking Number"
                placeholder="e.g. TRK000001"
                defaultValue={searchQuery}
                autoComplete="off"
              />
            </div>
            <div>
              <SelectField name="status" label="Filter by Status" defaultValue={statusFilter}>
                <option value="">All Statuses</option>
                <option value="REGISTERED">Registered</option>
                <option value="PICKED_UP">Picked Up</option>
                <option value="IN_TRANSIT">In Transit</option>
                <option value="OUT_FOR_DELIVERY">Out For Delivery</option>
              </SelectField>
            </div>
            <div>
              <SelectField name="service" label="Filter by Service" defaultValue={serviceFilter}>
                <option value="">All Services</option>
                {services?.map((s) => (
                  <option key={s.service_name} value={s.service_name}>
                    {s.service_name}
                  </option>
                ))}
              </SelectField>
            </div>
            <div>
              <Button type="submit" className="w-full flex justify-center gap-1.5">
                <Search className="size-4" /> Filter
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>

      {filteredInventory.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12 text-center">
            <ClipboardList className="size-12 text-muted-foreground/50 mb-3" />
            <h3 className="text-lg font-semibold">No packages found</h3>
            <p className="text-sm text-muted-foreground mt-1 max-w-sm">
              {typedInventory.length === 0
                ? "Your hub currently has no packages in stock. All packages are either delivered, returned, or held at other hubs."
                : "No packages match your search filters. Try adjusting your search query or dropdown values."}
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="overflow-x-auto rounded-lg border bg-card">
          <table className="w-full border-collapse text-left text-sm">
            <thead>
              <tr className="border-b bg-muted/50 font-medium text-muted-foreground">
                <th className="p-4">Tracking Number</th>
                <th className="p-4">Status</th>
                <th className="p-4">Service</th>
                <th className="p-4">Weight (kg)</th>
                <th className="p-4">Destination</th>
                <th className="p-4">Latest Scan</th>
                <th className="p-4">Held Since</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {filteredInventory.map((item) => (
                <tr key={item.package_id} className="hover:bg-muted/30">
                  <td className="p-4 font-mono font-medium text-foreground">{item.tracking_no}</td>
                  <td className="p-4">
                    <Badge tone={item.current_status === "OUT_FOR_DELIVERY" ? "warning" : "primary"}>
                      {item.current_status}
                    </Badge>
                  </td>
                  <td className="p-4">{item.serviceName}</td>
                  <td className="p-4">{item.weight} kg</td>
                  <td className="p-4">
                    <span className="font-semibold text-foreground">{item.destHubCode}</span> - {item.destHubName}
                  </td>
                  <td className="p-4 text-muted-foreground">{formatDateTime(item.latest_event_time)}</td>
                  <td className="p-4 text-muted-foreground font-medium">{getRelativeTimeString(item.latest_event_time)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </PageContainer>
  );
}
