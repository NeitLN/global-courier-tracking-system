import Link from "next/link";
import { redirect } from "next/navigation";
import { Clock } from "lucide-react";
import { getAuthContext } from "@/lib/auth/auth-context";
import { ROLE_LABELS } from "@/lib/auth/roles";
import { signOut } from "@/app/auth/actions";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { Alert } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { Reveal } from "@/components/motion/Reveal";

export const dynamic = "force-dynamic";

export default async function AccountPage() {
  const auth = await getAuthContext();

  if (auth.status === "unauthenticated") {
    redirect("/login");
  }

  return (
    <main className="flex min-h-dvh items-center justify-center bg-background p-6">
      <Reveal className="w-full max-w-md space-y-4">
        <Card>
          <CardHeader>
            <CardTitle>Account</CardTitle>
            <CardDescription>{auth.email}</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-4">
            {auth.status === "no_profile" && (
              <Alert tone="warning" title="Setting up your account">
                Your account was created, but a profile record hasn&apos;t finished provisioning yet.
                Try refreshing this page in a moment, or contact support if this persists.
              </Alert>
            )}

            {auth.status === "unassigned" && (
              <Alert tone="info" title="Waiting for role assignment">
                Your account is active, but no operational role has been assigned yet. An administrator
                needs to assign a role before you can access the courier system&apos;s modules.
              </Alert>
            )}

            {auth.status === "inactive" && (
              <Alert tone="danger" title="Account suspended">
                Your account has been marked inactive. You can still sign in, but operational access is
                disabled. Contact an administrator if you believe this is an error.
              </Alert>
            )}

            {auth.status === "active" && (
              <div className="flex flex-col gap-3">
                <div className="flex items-center gap-2">
                  <span className="text-sm text-muted-foreground">Display name:</span>
                  <span className="text-sm font-medium">{auth.displayName ?? "Not set"}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-sm text-muted-foreground">Role:</span>
                  <Badge tone="primary">{ROLE_LABELS[auth.appRole]}</Badge>
                </div>
                <Link
                  href="/dashboard"
                  className="focus-ring inline-flex h-9 w-fit items-center justify-center rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground hover:bg-primary/90"
                >
                  Go to dashboard
                </Link>
              </div>
            )}

            <form action={signOut}>
              <Button type="submit" variant="outline" size="sm">
                Sign out
              </Button>
            </form>
          </CardContent>
        </Card>

        {auth.status !== "active" && (
          <p className="flex items-center gap-1.5 text-caption justify-center">
            <Clock className="size-3.5" aria-hidden="true" />
            This page updates automatically once your account status changes.
          </p>
        )}
      </Reveal>
    </main>
  );
}
