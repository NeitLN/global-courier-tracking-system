"use server";

import { redirect } from "next/navigation";
import { APP_ROLES } from "@/lib/auth/roles";
import { requireRouteAccess } from "@/lib/auth/route-access";
import { createClient } from "@/lib/supabase/server";
import { courierErrorMessage } from "@/lib/courier/errors";

export async function updateDisplayName(formData: FormData) {
  await requireRouteAccess(APP_ROLES);
  const supabase = await createClient();
  const displayName = String(formData.get("display_name") ?? "").trim();
  const response = await supabase.rpc("fn_update_display_name", { p_display_name: displayName || null });
  if (response.error) redirect(`/profile?error=${encodeURIComponent(courierErrorMessage(response.error.message))}`);
  redirect("/profile?updated=display");
}

export async function updateCustomerDetails(formData: FormData) {
  const auth = await requireRouteAccess(["CUSTOMER"]);
  if (!auth.customerId) redirect("/account");
  const supabase = await createClient();
  const response = await supabase.rpc("fn_update_customer", {
    p_customer_id: auth.customerId,
    p_name: String(formData.get("full_name") ?? "").trim() || null,
    p_email: String(formData.get("email") ?? "").trim() || null,
    p_phone: String(formData.get("phone") ?? "").trim() || null,
  });
  if (response.error) redirect(`/profile?error=${encodeURIComponent(courierErrorMessage(response.error.message))}`);
  redirect("/profile?updated=customer");
}
