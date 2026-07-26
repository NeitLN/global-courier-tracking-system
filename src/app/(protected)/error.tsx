"use client";

import { useEffect } from "react";
import { ErrorState } from "@/components/ui/ErrorState";

export default function ProtectedError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Intentionally no console logging of error details here — this
    // boundary must never surface raw error/exception content to the UI.
  }, [error]);

  return (
    <div className="flex min-h-dvh items-center justify-center bg-background p-6">
      <ErrorState
        title="This page couldn't load"
        message="Something went wrong loading this page. You can try again, or navigate elsewhere using the sidebar."
        onRetry={reset}
      />
    </div>
  );
}
