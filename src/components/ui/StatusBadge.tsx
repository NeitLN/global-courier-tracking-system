import { Badge, type BadgeTone } from "./Badge";

/**
 * The exact six approved package statuses. Do not add statuses here —
 * this component only maps a status already decided by the database
 * (via R6/the status-flow trigger) to a visual treatment. It performs no
 * transition logic of its own.
 */
export const PACKAGE_STATUSES = [
  "REGISTERED",
  "PICKED_UP",
  "IN_TRANSIT",
  "OUT_FOR_DELIVERY",
  "DELIVERED",
  "RETURNED",
] as const;

export type PackageStatus = (typeof PACKAGE_STATUSES)[number];

const STATUS_LABELS: Record<PackageStatus, string> = {
  REGISTERED: "Registered",
  PICKED_UP: "Picked Up",
  IN_TRANSIT: "In Transit",
  OUT_FOR_DELIVERY: "Out for Delivery",
  DELIVERED: "Delivered",
  RETURNED: "Returned",
};

const STATUS_TONES: Record<PackageStatus, BadgeTone> = {
  REGISTERED: "neutral",
  PICKED_UP: "primary",
  IN_TRANSIT: "info",
  OUT_FOR_DELIVERY: "warning",
  DELIVERED: "success",
  RETURNED: "danger",
};

export function isPackageStatus(value: string): value is PackageStatus {
  return (PACKAGE_STATUSES as readonly string[]).includes(value);
}

export interface StatusBadgeProps {
  status: PackageStatus;
  className?: string;
}

export function StatusBadge({ status, className }: StatusBadgeProps) {
  return (
    <Badge tone={STATUS_TONES[status]} className={className}>
      {STATUS_LABELS[status]}
    </Badge>
  );
}
