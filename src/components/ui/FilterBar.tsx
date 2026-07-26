import type { HTMLAttributes } from "react";
import { cn } from "@/lib/utils/cn";

/**
 * A layout shell for future filter controls (search box, status filter,
 * date range, etc.). It contains no filtering logic — later phases supply
 * the actual controls as children.
 */
export function FilterBar({ className, children, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "flex flex-wrap items-center gap-2 rounded-lg border border-border bg-card p-3",
        className,
      )}
      {...props}
    >
      {children}
    </div>
  );
}
