import type { HTMLAttributes } from "react";
import { AlertTriangle, CheckCircle2, Info, XCircle } from "lucide-react";
import { cn } from "@/lib/utils/cn";

export type AlertTone = "info" | "success" | "warning" | "danger";

export interface AlertProps extends HTMLAttributes<HTMLDivElement> {
  tone?: AlertTone;
  title?: string;
}

const TONE_CLASSES: Record<AlertTone, string> = {
  info: "border-info-soft bg-info-soft text-info-soft-foreground",
  success: "border-success-soft bg-success-soft text-success-soft-foreground",
  warning: "border-warning-soft bg-warning-soft text-warning-soft-foreground",
  danger: "border-danger-soft bg-danger-soft text-danger-soft-foreground",
};

const TONE_ICONS: Record<AlertTone, typeof Info> = {
  info: Info,
  success: CheckCircle2,
  warning: AlertTriangle,
  danger: XCircle,
};

export function Alert({ className, tone = "info", title, children, ...props }: AlertProps) {
  const Icon = TONE_ICONS[tone];
  return (
    <div
      role="alert"
      className={cn("flex gap-3 rounded-md border p-3 text-sm", TONE_CLASSES[tone], className)}
      {...props}
    >
      <Icon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
      <div className="flex flex-col gap-0.5">
        {title && <p className="font-medium">{title}</p>}
        {children && <div>{children}</div>}
      </div>
    </div>
  );
}
