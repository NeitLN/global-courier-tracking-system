"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { ChevronDown, LogOut, User as UserIcon } from "lucide-react";
import type { AppRole } from "@/lib/auth/roles";
import { signOut } from "@/app/auth/actions";
import { RoleBadge } from "./RoleBadge";
import { cn } from "@/lib/utils/cn";

export interface UserMenuProps {
  displayName: string | null;
  email: string | null;
  role: AppRole;
}

export function UserMenu({ displayName, email, role }: UserMenuProps) {
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;

    function handlePointerDown(event: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setOpen(false);
      }
    }
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }

    document.addEventListener("mousedown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("mousedown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [open]);

  const label = displayName || email || "Account";

  return (
    <div ref={containerRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((prev) => !prev)}
        aria-haspopup="menu"
        aria-expanded={open}
        className="focus-ring flex items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-muted"
      >
        <span className="flex size-7 items-center justify-center rounded-full bg-primary text-primary-foreground">
          <UserIcon className="size-4" aria-hidden="true" />
        </span>
        <span className="hidden max-w-32 truncate font-medium sm:inline">{label}</span>
        <ChevronDown className={cn("size-4 text-muted-foreground transition-transform", open && "rotate-180")} aria-hidden="true" />
      </button>

      {open && (
        <div
          role="menu"
          aria-label="Account menu"
          className="absolute right-0 z-20 mt-2 w-56 rounded-md border border-border bg-card p-1 shadow-lg"
        >
          <div className="px-3 py-2">
            <p className="truncate text-sm font-medium text-foreground">{label}</p>
            {email && <p className="truncate text-caption">{email}</p>}
            <RoleBadge role={role} className="mt-2" />
          </div>
          <div className="my-1 h-px bg-border" />
          <Link
            href="/profile"
            role="menuitem"
            onClick={() => setOpen(false)}
            className="focus-ring block rounded-md px-3 py-2 text-sm hover:bg-muted"
          >
            Profile
          </Link>
          <Link
            href="/account"
            role="menuitem"
            onClick={() => setOpen(false)}
            className="focus-ring block rounded-md px-3 py-2 text-sm hover:bg-muted"
          >
            Account
          </Link>
          <div className="my-1 h-px bg-border" />
          <form action={signOut}>
            <button
              type="submit"
              role="menuitem"
              className="focus-ring flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm text-danger hover:bg-danger-soft"
            >
              <LogOut className="size-4" aria-hidden="true" />
              Sign out
            </button>
          </form>
        </div>
      )}
    </div>
  );
}
