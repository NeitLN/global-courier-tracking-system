'use server'

import { revalidatePath } from "next/cache";
import { getAuthContext } from "@/lib/auth/auth-context";
import { createClient } from "@/lib/supabase/server";
import { courierErrorMessage } from "@/lib/courier/errors";

import { randomUUID } from "crypto";

export async function assignPackageToTripAction(formData: {
  tripId: number;
  packageId: number;
}) {
  const auth = await getAuthContext();
  const requestId = randomUUID();

  if (!auth || auth.appRole !== "DISPATCHER" || !auth.isActive) {
    return { success: false, error: "Unauthorized: Active Dispatcher only", requestId };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("fn_assign_package_to_trip", {
    p_trip_id: formData.tripId,
    p_package_id: formData.packageId,
  });

  if (error) {
    const errMsg = courierErrorMessage(error.message, "ASSIGN_PACKAGE_TO_TRIP", auth.userId);
    return { success: false, error: errMsg, requestId };
  }

  // Log successful operation
  console.log(
    JSON.stringify({
      requestId,
      userId: auth.userId,
      operation: "ASSIGN_PACKAGE_TO_TRIP",
      status: "SUCCESS",
      timestamp: new Date().toISOString(),
    })
  );

  revalidatePath("/dispatcher/plan-track");
  revalidatePath("/dispatcher/trips");

  return { success: true, requestId };
}
