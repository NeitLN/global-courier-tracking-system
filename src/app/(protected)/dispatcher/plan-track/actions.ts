'use server'

import { revalidatePath } from "next/cache";
import { getAuthContext } from "@/lib/auth/auth-context";
import { createClient } from "@/lib/supabase/server";
import { courierErrorMessage } from "@/lib/courier/errors";

export async function assignPackageToTripAction(formData: {
  tripId: number;
  packageId: number;
}) {
  const auth = await getAuthContext();
  if (!auth || auth.appRole !== "DISPATCHER" || !auth.isActive) {
    return { success: false, error: "Unauthorized: Active Dispatcher only" };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("fn_assign_package_to_trip", {
    p_trip_id: formData.tripId,
    p_package_id: formData.packageId,
  });

  if (error) {
    return { success: false, error: courierErrorMessage(error.message) };
  }

  revalidatePath("/dispatcher/plan-track");
  revalidatePath("/dispatcher/trips");

  return { success: true };
}
