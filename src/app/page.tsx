import Link from "next/link";
import { Truck } from "lucide-react";
import { getAuthContext } from "@/lib/auth/auth-context";

// This page's content genuinely depends on request-time auth state (signed
// in vs. not), so it must not be statically prerendered at build time —
// which also matters because build must succeed with no env vars configured
// (Phase 1 requirement), and the Supabase client throws if it tries to
// initialize during static generation without them.
export const dynamic = "force-dynamic";

export default async function Home() {
  const auth = await getAuthContext();
  const isAuthenticated = auth.status !== "unauthenticated";
  const secondaryHref = auth.status === "active" ? "/dashboard" : "/account";

  return (
    <main className="flex min-h-dvh flex-col items-center justify-center gap-8 bg-background p-8">
      <div className="flex flex-col items-center gap-3 text-center">
        <span className="flex size-12 items-center justify-center rounded-lg bg-primary text-primary-foreground">
          <Truck className="size-6" aria-hidden="true" />
        </span>
        <h1 className="text-page-title text-2xl">Global Courier &amp; Tracking System</h1>
        <p className="text-body max-w-md text-muted-foreground">
          A role-based courier operations platform for registering, scanning, dispatching, and
          reporting on shipments across a hub network.
        </p>
      </div>

      <div className="flex flex-wrap items-center justify-center gap-3">
        {isAuthenticated ? (
          <Link
            href={secondaryHref}
            className="focus-ring inline-flex h-10 items-center justify-center rounded-md bg-primary px-5 text-sm font-medium text-primary-foreground hover:bg-primary/90"
          >
            {auth.status === "active" ? "Go to dashboard" : "Go to account"}
          </Link>
        ) : (
          <>
            <Link
              href="/login"
              className="focus-ring inline-flex h-10 items-center justify-center rounded-md bg-primary px-5 text-sm font-medium text-primary-foreground hover:bg-primary/90"
            >
              Sign in
            </Link>
            <Link
              href="/signup"
              className="focus-ring inline-flex h-10 items-center justify-center rounded-md border border-border bg-card px-5 text-sm font-medium text-foreground hover:bg-muted"
            >
              Create account
            </Link>
          </>
        )}
      </div>

      <p className="text-caption">Phase 6 — Design system and application shell (in progress)</p>
    </main>
  );
}
