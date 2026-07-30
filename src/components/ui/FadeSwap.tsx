import type { ReactNode } from "react";
import { cn } from "@/lib/utils/cn";

export interface FadeSwapProps {
  loading: boolean;
  skeleton: ReactNode;
  children: ReactNode;
  className?: string;
}

/**
 * Crossfades between a loading skeleton and real content based on a
 * boolean prop. Pure CSS (opacity transition on the token duration
 * scale) — no client hooks, so it stays usable from Server Components
 * whose `loading` value is already resolved at render time.
 */
export function FadeSwap({ loading, skeleton, children, className }: FadeSwapProps) {
  return (
    <div className={cn("relative", className)}>
      <div
        className={cn(
          "transition-opacity duration-200 ease-out",
          loading ? "opacity-100" : "pointer-events-none absolute inset-0 opacity-0",
        )}
        aria-hidden={!loading}
      >
        {skeleton}
      </div>
      <div
        className={cn(
          "transition-opacity duration-200 ease-out",
          loading ? "pointer-events-none absolute inset-0 opacity-0" : "opacity-100",
        )}
        aria-hidden={loading}
      >
        {children}
      </div>
    </div>
  );
}
