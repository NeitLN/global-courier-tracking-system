"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { AnimatePresence, motion } from "motion/react";
import { ChevronDown, PanelLeftClose, PanelLeftOpen, Truck } from "lucide-react";
import type { AppRole } from "@/lib/auth/roles";
import { getNavForRole } from "@/lib/navigation/nav-config";
import { cn } from "@/lib/utils/cn";

export interface AppSidebarProps {
  role: AppRole;
  className?: string;
}

function isActivePath(pathname: string, href: string): boolean {
  return pathname === href || pathname.startsWith(`${href}/`);
}

export function AppSidebar({ role, className }: AppSidebarProps) {
  const nav = getNavForRole(role);
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const [expandedGroups, setExpandedGroups] = useState<Record<string, boolean>>(() => {
    const initial: Record<string, boolean> = {};
    for (const item of nav) {
      if (item.children) {
        initial[item.label] = item.children.some((child) => isActivePath(pathname, child.href));
      }
    }
    return initial;
  });

  function toggleGroup(label: string) {
    setExpandedGroups((prev) => ({ ...prev, [label]: !prev[label] }));
  }

  return (
    <aside
      className={cn(
        "hidden shrink-0 flex-col border-r border-sidebar-border bg-sidebar text-sidebar-foreground transition-[width] duration-200 ease-[cubic-bezier(0.2,0,0,1)] lg:flex",
        collapsed ? "w-16" : "w-64",
        className,
      )}
    >
      <div className="flex h-14 items-center gap-2 border-b border-sidebar-border px-4">
        <Truck className="size-5 shrink-0 text-accent" aria-hidden="true" />
        {!collapsed && <span className="truncate text-sm font-semibold">Global Courier</span>}
      </div>

      <nav aria-label="Primary" className="flex-1 overflow-y-auto px-2 py-3">
        <ul className="flex flex-col gap-0.5">
          {nav.map((item) => {
            const Icon = item.icon;
            const active = isActivePath(pathname, item.href);
            const hasChildren = Boolean(item.children?.length);
            const isExpanded = expandedGroups[item.label] ?? false;

            return (
              <li key={item.label}>
                <div className="flex items-center">
                  <Link
                    href={item.href}
                    aria-current={active ? "page" : undefined}
                    className={cn(
                      "focus-ring flex flex-1 items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors duration-150",
                      active
                        ? "bg-sidebar-active text-sidebar-active-foreground"
                        : "text-sidebar-foreground hover:bg-sidebar-active/60",
                    )}
                  >
                    <Icon className="size-4 shrink-0" aria-hidden="true" />
                    {!collapsed && <span className="truncate">{item.label}</span>}
                  </Link>
                  {hasChildren && !collapsed && (
                    <button
                      type="button"
                      onClick={() => toggleGroup(item.label)}
                      aria-expanded={isExpanded}
                      aria-label={`${isExpanded ? "Collapse" : "Expand"} ${item.label}`}
                      className="focus-ring rounded-md p-1.5 text-sidebar-muted-foreground hover:bg-sidebar-active/60"
                    >
                      <ChevronDown
                        className={cn("size-4 transition-transform", isExpanded && "rotate-180")}
                        aria-hidden="true"
                      />
                    </button>
                  )}
                </div>

                <AnimatePresence initial={false}>
                  {hasChildren && !collapsed && isExpanded && (
                    <motion.ul
                      className="ml-6 mt-0.5 flex flex-col gap-0.5 overflow-hidden border-l border-sidebar-border pl-3"
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: "auto", opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.2, ease: [0.2, 0, 0, 1] }}
                    >
                      {item.children!.map((child) => {
                        const childActive = pathname === child.href;
                        return (
                          <li key={child.href}>
                            <Link
                              href={child.href}
                              aria-current={childActive ? "page" : undefined}
                              className={cn(
                                "focus-ring block rounded-md px-3 py-1.5 text-sm transition-colors duration-150",
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
                    </motion.ul>
                  )}
                </AnimatePresence>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="border-t border-sidebar-border p-2">
        <button
          type="button"
          onClick={() => setCollapsed((prev) => !prev)}
          aria-pressed={collapsed}
          className="focus-ring flex w-full items-center gap-3 rounded-md px-3 py-2 text-sm text-sidebar-muted-foreground hover:bg-sidebar-active/60"
        >
          {collapsed ? (
            <PanelLeftOpen className="size-4 shrink-0" aria-hidden="true" />
          ) : (
            <PanelLeftClose className="size-4 shrink-0" aria-hidden="true" />
          )}
          {!collapsed && <span>Collapse</span>}
        </button>
      </div>
    </aside>
  );
}
