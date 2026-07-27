'use server'

import { revalidatePath } from "next/cache";
import { getAuthContext } from "@/lib/auth/auth-context";
import { createClient } from "@/lib/supabase/server";
import { courierErrorMessage } from "@/lib/courier/errors";

export interface DeliveryAttemptResult {
  success: boolean;
  error?: string;
  data?: unknown;
}

export async function recordDeliveryAttempt(formData: FormData): Promise<DeliveryAttemptResult> {
  const auth = await getAuthContext();
  if (auth.status !== "active" || auth.appRole !== "HUB_OPERATOR") {
    return { success: false, error: "Unauthorized: must be a Hub Operator." };
  }

  const trackingNo = (formData.get("tracking_no") as string)?.trim().toUpperCase();
  const driverIdStr = formData.get("driver_id") as string;
  const attemptTimeStr = formData.get("attempt_time") as string;
  const outcome = formData.get("outcome") as string;
  const failureReason = (formData.get("failure_reason") as string)?.trim() || null;
  const notes = (formData.get("notes") as string)?.trim() || null;

  if (!trackingNo) {
    return { success: false, error: "Tracking number is required." };
  }
  if (!driverIdStr) {
    return { success: false, error: "Driver is required." };
  }
  if (!attemptTimeStr) {
    return { success: false, error: "Attempt time is required." };
  }
  if (!outcome) {
    return { success: false, error: "Outcome is required." };
  }

  const driverId = parseInt(driverIdStr, 10);
  const attemptTime = new Date(attemptTimeStr).toISOString();

  const supabase = await createClient();

  // Call our custom fn_record_delivery_attempt RPC
  const { error } = await supabase.rpc("fn_record_delivery_attempt", {
    p_tracking_number: trackingNo,
    p_driver_id: driverId,
    p_attempt_time: attemptTime,
    p_outcome: outcome,
    p_failure_reason: failureReason,
    p_notes: notes
  });

  if (error) {
    return { success: false, error: courierErrorMessage(error.message) };
  }

  revalidatePath("/operator/delivery-attempts");
  revalidatePath("/operator/inventory");
  revalidatePath("/track");

  return {
    success: true,
    data: {
      trackingNo,
      driverId,
      attemptTime,
      outcome,
      failureReason,
      notes
    }
  };
}
