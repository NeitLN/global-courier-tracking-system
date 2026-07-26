import { AlertTriangle } from "lucide-react";
import { cn } from "@/lib/utils/cn";
import { Button } from "./Button";

export interface ErrorStateProps {
  title?: string;
  /** Must always be a safe, pre-written message — never a raw error/exception object. */
  message?: string;
  onRetry?: () => void;
  className?: string;
}

export function ErrorState({
  title = "Something went wrong",
  message = "Please try again. If the problem continues, contact support.",
  onRetry,
  className,
}: ErrorStateProps) {
  return (
    <div
      role="alert"
      className={cn(
        "flex flex-col items-center justify-center gap-2 rounded-lg border border-border bg-card px-6 py-12 text-center",
        className,
      )}
    >
      <AlertTriangle className="size-8 text-danger" aria-hidden="true" />
      <p className="text-section-title">{title}</p>
      <p className="max-w-md text-body text-muted-foreground">{message}</p>
      {onRetry && (
        <Button variant="outline" size="sm" className="mt-2" onClick={onRetry}>
          Try again
        </Button>
      )}
    </div>
  );
}
