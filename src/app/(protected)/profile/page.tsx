import { APP_ROLES, ROLE_LABELS } from "@/lib/auth/roles";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { Alert } from "@/components/ui/Alert";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { updateCustomerDetails, updateDisplayName } from "./actions";

type Customer = { full_name: string; phone: string; email: string };

export default async function ProfilePage({ searchParams }: { searchParams: Promise<{ updated?: string; error?: string }> }) {
  const auth = await requireRouteAccess(APP_ROLES);
  const params = await searchParams;
  const supabase = await createClient();
  let customer: Customer | null = null;
  let customerLoadError = false;
  if (auth.appRole === "CUSTOMER" && auth.customerId) {
    const response = await supabase.from("customer").select("full_name, phone, email").eq("customer_id", auth.customerId).maybeSingle();
    customer = response.data as Customer | null;
    customerLoadError = Boolean(response.error) || !customer;
  }

  return (
    <PageContainer className="max-w-3xl">
      <PageHeader title="Profile" description="Application identity and customer domain details are updated through separate authorized RPCs." />
      {(params.updated === "display" || params.updated === "customer") && <Alert tone="success" title="Profile updated">Your {params.updated === "display" ? "display name" : "customer details"} were saved.</Alert>}
      {params.error && <Alert tone="danger" title="Update failed">{params.error}</Alert>}

      <Card><CardHeader><CardTitle>Application profile</CardTitle></CardHeader><CardContent className="flex flex-col gap-4">
        <div className="grid grid-cols-3 gap-y-3 text-sm"><span className="text-label">Account email</span><span className="col-span-2">{auth.email}</span><span className="text-label">Role</span><span className="col-span-2"><Badge tone="primary">{ROLE_LABELS[auth.appRole]}</Badge></span><span className="text-label">Status</span><span className="col-span-2"><Badge tone="success">Active</Badge></span></div>
        <form action={updateDisplayName} className="flex flex-col gap-3 sm:flex-row sm:items-end"><div className="flex-1"><Input name="display_name" label="Display name" defaultValue={auth.displayName ?? ""} maxLength={100} /></div><Button type="submit">Save display name</Button></form>
      </CardContent></Card>

      {auth.appRole === "CUSTOMER" && customerLoadError && <Alert tone="danger" title="Customer details unavailable">Your RLS-scoped customer row could not be loaded. No editable placeholder values are shown.</Alert>}

      {auth.appRole === "CUSTOMER" && customer && <Card><CardHeader><CardTitle>Customer information</CardTitle></CardHeader><CardContent><form action={updateCustomerDetails} className="grid gap-4 sm:grid-cols-2"><div className="sm:col-span-2"><Input name="full_name" label="Full name" defaultValue={customer.full_name} required /></div><Input name="email" type="email" label="Email" defaultValue={customer.email} required /><Input name="phone" label="Phone" defaultValue={customer.phone} required /><div className="sm:col-span-2 flex justify-end"><Button type="submit">Save customer details</Button></div></form></CardContent></Card>}
    </PageContainer>
  );
}
