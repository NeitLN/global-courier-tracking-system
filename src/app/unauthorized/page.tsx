import Link from "next/link";
import { ShieldAlert } from "lucide-react";
import { getAuthContext } from "@/lib/auth/auth-context";
import { Reveal } from "@/components/motion/Reveal";

export const dynamic = "force-dynamic";

export default async function UnauthorizedPage() {
  const auth = await getAuthContext();
  const safeHref = auth.status === "active" ? "/dashboard" : "/account";

  return (
    <main className="flex min-h-dvh flex-col items-center justify-center gap-4 bg-background p-8 text-center">
      <Reveal className="flex flex-col items-center gap-4">
        <ShieldAlert className="size-10 text-warning" aria-hidden="true" />
        <h1 className="text-page-title">You don&apos;t have access to this page</h1>
        <p className="text-body max-w-md text-muted-foreground">
          Your account doesn&apos;t have the role required to view this section. If you believe this
          is a mistake, contact your organization&apos;s administrator.
        </p>
        <Link
          href={safeHref}
          className="focus-ring inline-flex h-9 items-center justify-center rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground hover:bg-primary/90"
        >
          Return to your dashboard
        </Link>
      </Reveal>
    </main>
  );
}
