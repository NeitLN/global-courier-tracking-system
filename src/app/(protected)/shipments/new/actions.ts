"use server";

import { redirect } from "next/navigation";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { courierErrorMessage } from "@/lib/courier/errors";

function numeric(formData: FormData, name: string, required = true): number | null {
  const raw = String(formData.get(name) ?? "").trim();
  if (!raw) {
    if (!required) return null;
    throw new Error(`${name} is required`);
  }
  const value = Number(raw);
  if (!Number.isFinite(value)) throw new Error(`${name} must be a number`);
  return value;
}

export async function registerShipment(formData: FormData) {
  const auth = await requireRouteAccess(["CUSTOMER"]);
  if (!auth.customerId) redirect("/account");

  const receiverEmail = String(formData.get("receiver_email") ?? "").trim();
  const supabase = await createClient();

  let args: Record<string, number | string | null>;
  try {
    args = {
      p_receiver_email: receiverEmail,
      p_service_id: numeric(formData, "service_id")!,
      p_weight_kg: numeric(formData, "weight_kg")!,
      p_length_cm: numeric(formData, "length_cm", false),
      p_width_cm: numeric(formData, "width_cm", false),
      p_height_cm: numeric(formData, "height_cm", false),
      p_origin_hub_id: numeric(formData, "origin_hub_id")!,
      p_dest_hub_id: numeric(formData, "dest_hub_id")!,
    };
  } catch {
    redirect(`/shipments/new?error=${encodeURIComponent("Enter valid numeric package measurements.")}`);
  }

  const response = await supabase.rpc("fn_register_package_by_receiver_email", args);
  if (response.error) {
    redirect(`/shipments/new?error=${encodeURIComponent(courierErrorMessage(response.error.message))}`);
  }

  const shipment = response.data as { tracking_no?: string } | null;
  if (!shipment?.tracking_no) {
    redirect(`/shipments/new?error=${encodeURIComponent("The database did not return a tracking number.")}`);
  }

  redirect(`/shipments/${encodeURIComponent(shipment.tracking_no)}?created=1`);
}
