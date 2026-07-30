import type { ReactNode } from "react";
import { TrendingDown, TrendingUp } from "lucide-react";
import { cn } from "@/lib/utils/cn";
import { Skeleton } from "./Skeleton";
import { FadeSwap } from "./FadeSwap";
import { CountUp } from "@/components/motion/CountUp";

export interface KpiTrend {
  direction: "up" | "down";
  label: string;
  tone?: "success" | "danger" | "neutral";
}

export interface KpiCardShellProps {
  label: string;
  /**
   * No default value is provided on purpose — callers must supply a real
   * number (later phases, once wired to an approved RPC) or omit it
   * entirely, in which case an explicit placeholder is shown instead of a
   * fabricated figure.
   */
  value?: string | number;
  supportingText?: string;
  isLoading?: boolean;
  trend?: KpiTrend;
  icon?: ReactNode;
  className?: string;
}

export function KpiCardShell({
  label,
  value,
  supportingText,
  isLoading = false,
  trend,
  icon,
  className,
}: KpiCardShellProps) {
  const TrendIcon = trend?.direction === "down" ? TrendingDown : TrendingUp;

  return (
    <div className={cn("card-interactive rounded-lg border border-border bg-card p-4", className)}>
      <div className="flex items-start justify-between gap-2">
        <p className="text-label">{label}</p>
        {icon && <span className="text-muted-foreground">{icon}</span>}
      </div>

      <FadeSwap loading={isLoading} skeleton={<Skeleton className="mt-2 h-8 w-24" />} className="mt-1">
        <p className="text-kpi-value">{typeof value === "number" ? <CountUp value={value} /> : (value ?? "—")}</p>
      </FadeSwap>

      {supportingText && !isLoading && <p className="text-caption mt-1">{supportingText}</p>}

      {trend && !isLoading && (
        <p
          className={cn(
            "mt-2 flex items-center gap-1 text-xs font-medium",
            trend.tone === "danger" && "text-danger",
            trend.tone === "success" && "text-success",
            (!trend.tone || trend.tone === "neutral") && "text-muted-foreground",
          )}
        >
          <TrendIcon className="size-3.5" aria-hidden="true" />
          {trend.label}
        </p>
      )}
    </div>
  );
}
