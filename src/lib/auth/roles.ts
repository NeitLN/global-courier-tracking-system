/**
 * The four approved application roles. This is the single source of
 * truth for role strings on the frontend — do not duplicate these
 * literals elsewhere. There is intentionally no ADMIN role.
 */
export const APP_ROLES = [
  "CUSTOMER",
  "HUB_OPERATOR",
  "DISPATCHER",
  "ANALYST",
] as const;

export type AppRole = (typeof APP_ROLES)[number];

export function isAppRole(value: unknown): value is AppRole {
  return typeof value === "string" && (APP_ROLES as readonly string[]).includes(value);
}

export const ROLE_LABELS: Record<AppRole, string> = {
  CUSTOMER: "Customer",
  HUB_OPERATOR: "Hub Operator",
  DISPATCHER: "Dispatcher",
  ANALYST: "Analyst",
};
