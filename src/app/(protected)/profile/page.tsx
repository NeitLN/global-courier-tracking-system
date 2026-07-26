import { APP_ROLES, ROLE_LABELS } from "@/lib/auth/roles";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { PageContainer } from "@/components/layout/PageContainer";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { Alert } from "@/components/ui/Alert";

export default async function ProfilePage() {
  const auth = await requireRouteAccess(APP_ROLES);

  return (
    <PageContainer className="max-w-2xl">
      <PageHeader title="Profile" description="Your account details as recorded by the system." />

      <Card>
        <CardHeader>
          <CardTitle>Account</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          <dl className="grid grid-cols-3 gap-y-3 text-sm">
            <dt className="text-label col-span-1">Display name</dt>
            <dd className="col-span-2 text-foreground">{auth.displayName ?? "Not set"}</dd>

            <dt className="text-label col-span-1">Email</dt>
            <dd className="col-span-2 text-foreground">{auth.email}</dd>

            <dt className="text-label col-span-1">Role</dt>
            <dd className="col-span-2">
              <Badge tone="primary">{ROLE_LABELS[auth.appRole]}</Badge>
            </dd>

            <dt className="text-label col-span-1">Status</dt>
            <dd className="col-span-2">
              <Badge tone="success">Active</Badge>
            </dd>
          </dl>
        </CardContent>
      </Card>

      <Alert tone="info" title="Editing is not yet available here">
        Display-name editing uses the already-approved <code>fn_update_display_name</code> function,
        but the form for it is intentionally deferred until it is fully implemented and tested end to
        end. This page is read-only for Phase 6.
      </Alert>
    </PageContainer>
  );
}
