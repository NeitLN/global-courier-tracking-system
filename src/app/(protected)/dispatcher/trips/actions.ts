'use server'

import { revalidatePath } from "next/cache";
import { getAuthContext } from "@/lib/auth/auth-context";
import { createClient } from "@/lib/supabase/server";
import { courierErrorMessage } from "@/lib/courier/errors";

import { randomUUID } from "crypto";

export async function createTripAction(formData: {
  routeId: number;
  vehicleId: number;
  driverId: number;
  depart: string;
}) {
  const auth = await getAuthContext();
  const requestId = randomUUID();

  if (!auth || auth.appRole !== "DISPATCHER" || !auth.isActive) {
    return { success: false, error: "Unauthorized: Active Dispatcher only", requestId };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("fn_create_trip", {
    p_route_id: formData.routeId,
    p_vehicle_id: formData.vehicleId,
    p_driver_id: formData.driverId,
    p_depart: new Date(formData.depart).toISOString(),
  });

  if (error) {
    const errMsg = courierErrorMessage(error.message, "CREATE_TRIP", auth.userId);
    return { success: false, error: errMsg, requestId };
  }

  // Log successful operation
  console.log(
    JSON.stringify({
      requestId,
      userId: auth.userId,
      operation: "CREATE_TRIP",
      status: "SUCCESS",
      timestamp: new Date().toISOString(),
    })
  );

  revalidatePath("/dispatcher/trips");
  revalidatePath("/dispatcher/plan-track");

  return { success: true, requestId };
}
