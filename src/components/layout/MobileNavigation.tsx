"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, Truck } from "lucide-react";
import type { AppRole } from "@/lib/auth/roles";
import { getNavForRole } from "@/lib/navigation/nav-config";
import { Drawer } from "@/components/ui/Drawer";
import { cn } from "@/lib/utils/cn";

export interface MobileNavigationProps {
  role: AppRole;
}

export function MobileNavigation({ role }: MobileNavigationProps) {
  const nav = getNavForRole(role);
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label="Open navigation"
        className="focus-ring rounded-md p-2 text-foreground hover:bg-muted lg:hidden"
      >
        <Menu className="size-5" aria-hidden="true" />
      </button>

      <Drawer open={open} onClose={() => setOpen(false)} title="Global Courier" side="left">
        <div className="flex items-center gap-2 px-4 py-3 text-sidebar-foreground">
          <Truck className="size-5 shrink-0 text-accent" aria-hidden="true" />
          <span className="text-sm font-semibold">Navigation</span>
        </div>
        <nav aria-label="Primary" className="px-2 py-2">
          <ul className="flex flex-col gap-0.5">
            {nav.map((item) => {
              const Icon = item.icon;
              const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
              return (
                <li key={item.label}>
                  <Link
                    href={item.href}
                    onClick={() => setOpen(false)}
                    aria-current={active ? "page" : undefined}
                    className={cn(
                      "focus-ring flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium",
                      active
                        ? "bg-sidebar-active text-sidebar-active-foreground"
                        : "text-sidebar-foreground hover:bg-sidebar-active/60",
                    )}
                  >
                    <Icon className="size-4 shrink-0" aria-hidden="true" />
                    <span>{item.label}</span>
                  </Link>
                  {item.children && (
                    <ul className="ml-6 mt-0.5 flex flex-col gap-0.5 border-l border-sidebar-border pl-3">
                      {item.children.map((child) => {
                        const childActive = pathname === child.href;
                        return (
                          <li key={child.href}>
                            <Link
                              href={child.href}
                              onClick={() => setOpen(false)}
                              aria-current={childActive ? "page" : undefined}
                              className={cn(
                                "focus-ring block rounded-md px-3 py-1.5 text-sm",
                                childActive
                                  ? "bg-sidebar-active text-sidebar-active-foreground font-medium"
                                  : "text-sidebar-muted-foreground hover:bg-sidebar-active/60 hover:text-sidebar-foreground",
                              )}
                            >
                              {child.label}
                            </Link>
                          </li>
                        );
                      })}
                    </ul>
                  )}
                </li>
              );
            })}
          </ul>
        </nav>
      </Drawer>
    </>
  );
}
