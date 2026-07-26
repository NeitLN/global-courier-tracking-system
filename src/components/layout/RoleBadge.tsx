import type { AppRole } from "@/lib/auth/roles";
import { ROLE_LABELS } from "@/lib/auth/roles";
import { Badge, type BadgeTone } from "@/components/ui/Badge";

const ROLE_TONES: Record<AppRole, BadgeTone> = {
  CUSTOMER: "primary",
  HUB_OPERATOR: "info",
  DISPATCHER: "accent",
  ANALYST: "neutral",
};

export function RoleBadge({ role, className }: { role: AppRole; className?: string }) {
  return (
    <Badge tone={ROLE_TONES[role]} className={className}>
      {ROLE_LABELS[role]}
    </Badge>
  );
}
