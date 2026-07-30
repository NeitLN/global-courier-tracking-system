"use client";

import { useEffect, useId, useRef } from "react";
import type { ReactNode, MouseEvent } from "react";
import { X } from "lucide-react";
import { cn } from "@/lib/utils/cn";

export interface DrawerProps {
  open: boolean;
  onClose: () => void;
  title: string;
  side?: "left" | "right";
  children?: ReactNode;
  className?: string;
}

/**
 * A native <dialog>-based slide-in panel — used for the mobile navigation
 * drawer. Keeps the browser's built-in focus trap and Escape-to-close
 * instead of hand-rolling one.
 */
export function Drawer({ open, onClose, title, side = "left", children, className }: DrawerProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const titleId = useId();

  useEffect(() => {
    const el = dialogRef.current;
    if (!el) return;
    if (open && !el.open) {
      el.showModal();
    } else if (!open && el.open) {
      el.close();
    }
  }, [open]);

  function handleBackdropClick(event: MouseEvent<HTMLDialogElement>) {
    if (event.target === dialogRef.current) {
      onClose();
    }
  }

  return (
    <dialog
      ref={dialogRef}
      onClose={onClose}
      onClick={handleBackdropClick}
      aria-labelledby={titleId}
      className={cn(
        "fixed inset-y-0 m-0 h-dvh w-72 max-w-[85vw] border-sidebar-border bg-sidebar p-0 text-sidebar-foreground backdrop:bg-slate-950/50",
        side === "left" ? "left-0 border-r drawer-left" : "right-0 left-auto border-l drawer-right",
        className,
      )}
    >
      <div className="flex h-full flex-col">
        <div className="flex items-center justify-between border-b border-sidebar-border px-4 py-3">
          <span id={titleId} className="text-sm font-semibold text-sidebar-foreground">
            {title}
          </span>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close navigation"
            className="focus-ring rounded-md p-1 text-sidebar-muted-foreground hover:bg-sidebar-active"
          >
            <X className="size-4" aria-hidden="true" />
          </button>
        </div>
        <div className="flex-1 overflow-y-auto">{children}</div>
      </div>
    </dialog>
  );
}
