import type { ReactNode } from "react";
import { cn } from "@/lib/utils/cn";

export interface DataTableShellProps {
  /** Column headers rendered inside a <th scope="col">. */
  columns: string[];
  children?: ReactNode;
  className?: string;
  caption?: string;
}

/**
 * A structural table wrapper: horizontal scroll container, semantic
 * <table>/<thead>, and consistent styling. It renders no rows or data
 * fetching of its own — callers supply <tbody> content via `children`.
 */
export function DataTableShell({ columns, children, className, caption }: DataTableShellProps) {
  return (
    <div className={cn("overflow-x-auto rounded-lg border border-border bg-card", className)}>
      <table className="w-full min-w-max border-collapse text-table">
        {caption && <caption className="sr-only">{caption}</caption>}
        <thead>
          <tr className="border-b border-border bg-muted/60">
            {columns.map((column) => (
              <th
                key={column}
                scope="col"
                className="px-3 py-2 text-left text-label font-medium"
              >
                {column}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-border">{children}</tbody>
      </table>
    </div>
  );
}
