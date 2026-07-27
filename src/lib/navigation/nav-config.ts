import type { LucideIcon } from "lucide-react";
import {
  LayoutDashboard,
  Package,
  UserCircle,
  Warehouse,
  Map,
  Truck,
  Route as RouteIcon,
  UserRound,
  Car,
  BarChart3,
} from "lucide-react";
import type { AppRole } from "@/lib/auth/roles";

export interface NavChild {
  label: string;
  href: string;
}

export interface NavItem {
  label: string;
  href: string;
  icon: LucideIcon;
  children?: NavChild[];
}

/**
 * Navigation visibility is a usability feature only — every route listed
 * here is (or must be) independently enforced server-side via
 * `requireRouteAccess`. Do not treat this file as an authorization
 * mechanism.
 */
const NAV_BY_ROLE: Record<AppRole, NavItem[]> = {
  CUSTOMER: [
    { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
    { label: "My Shipments", href: "/shipments", icon: Package },
    { label: "Profile", href: "/profile", icon: UserCircle },
  ],
  HUB_OPERATOR: [
    { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
    {
      label: "Hub Operations",
      href: "/operator",
      icon: Warehouse,
      children: [
        { label: "Record Scan", href: "/operator/scans" },
        { label: "Current Inventory", href: "/operator/inventory" },
        { label: "Delivery Attempts", href: "/operator/delivery-attempts" },
      ],
    },
    { label: "Profile", href: "/profile", icon: UserCircle },
  ],
  DISPATCHER: [
    { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
    { label: "Shipments", href: "/shipments", icon: Package },
    { label: "Plan & Track", href: "/dispatcher/plan-track", icon: Map },
    { label: "Trips", href: "/dispatcher/trips", icon: Truck },
    { label: "Routes", href: "/dispatcher/routes", icon: RouteIcon },
    { label: "Drivers", href: "/dispatcher/drivers", icon: UserRound },
    { label: "Vehicles", href: "/dispatcher/vehicles", icon: Car },
    { label: "Profile", href: "/profile", icon: UserCircle },
  ],
  ANALYST: [
    { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
    {
      label: "Analytics",
      href: "/analytics",
      icon: BarChart3,
      children: [
        { label: "Hub Analysis", href: "/analytics/hubs" },
        { label: "SLA Compliance", href: "/analytics/sla" },
        { label: "Driver Performance", href: "/analytics/drivers" },
        { label: "Route Explorer", href: "/analytics/routes" },
      ],
    },
    { label: "Profile", href: "/profile", icon: UserCircle },
  ],
};

export function getNavForRole(role: AppRole): NavItem[] {
  return NAV_BY_ROLE[role];
}

export interface BreadcrumbItem {
  label: string;
  href: string;
}

const SEGMENT_LABELS: Record<string, string> = {
  dashboard: "Dashboard",
  shipments: "Shipments",
  operator: "Hub Operations",
  scans: "Record Scan",
  inventory: "Current Inventory",
  "delivery-attempts": "Delivery Attempts",
  dispatcher: "Dispatcher",
  "plan-track": "Plan & Track",
  trips: "Trips",
  routes: "Routes",
  drivers: "Drivers",
  vehicles: "Vehicles",
  analytics: "Analytics",
  hubs: "Hub Analysis",
  sla: "SLA Compliance",
  profile: "Profile",
  account: "Account",
  unauthorized: "Unauthorized",
};

/**
 * A handful of route segments (`routes`, `drivers`) are reused by more than
 * one role's section with a different meaning in each — e.g. the Dispatcher
 * "Routes" list vs. the Analyst "Route Explorer". `SEGMENT_LABELS` can only
 * hold one label per segment, so those specific full paths are overridden
 * here to match the label actually shown for them in the sidebar
 * (`NAV_BY_ROLE` above). Checked before the generic per-segment fallback.
 */
const PATH_LABEL_OVERRIDES: Record<string, string> = {
  "/analytics/routes": "Route Explorer",
  "/analytics/drivers": "Driver Performance",
};

function labelForSegment(segment: string): string {
  return SEGMENT_LABELS[segment] ?? segment.replace(/-/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

/** Derives simple breadcrumb items from a pathname, e.g. `/dispatcher/trips`. */
export function buildBreadcrumbs(pathname: string): BreadcrumbItem[] {
  const segments = pathname.split("/").filter(Boolean);
  let href = "";
  return segments.map((segment) => {
    href += `/${segment}`;
    return { label: PATH_LABEL_OVERRIDES[href] ?? labelForSegment(segment), href };
  });
}
