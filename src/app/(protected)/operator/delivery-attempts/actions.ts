'use server'

import { revalidatePath } from "next/cache";
import { getAuthContext } from "@/lib/auth/auth-context";
import { createClient } from "@/lib/supabase/server";
import { courierErrorMessage } from "@/lib/courier/errors";

import { randomUUID } from "crypto";

export interface DeliveryAttemptResult {
  success: boolean;
  error?: string;
  data?: unknown;
  requestId?: string;
}

export async function recordDeliveryAttempt(formData: FormData): Promise<DeliveryAttemptResult> {
  const auth = await getAuthContext();
  const requestId = randomUUID();

  if (auth.status !== "active" || auth.appRole !== "HUB_OPERATOR") {
    return { success: false, error: "Unauthorized: must be a Hub Operator.", requestId };
  }

  const trackingNo = (formData.get("tracking_no") as string)?.trim().toUpperCase();
  const driverIdStr = formData.get("driver_id") as string;
  const attemptTimeStr = formData.get("attempt_time") as string;
  const outcome = formData.get("outcome") as string;
  const failureReason = (formData.get("failure_reason") as string)?.trim() || null;
  const notes = (formData.get("notes") as string)?.trim() || null;

  if (!trackingNo) {
    return { success: false, error: "Tracking number is required.", requestId };
  }
  if (!driverIdStr) {
    return { success: false, error: "Driver is required.", requestId };
  }
  if (!attemptTimeStr) {
    return { success: false, error: "Attempt time is required.", requestId };
  }
  if (!outcome) {
    return { success: false, error: "Outcome is required.", requestId };
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
    const errMsg = courierErrorMessage(error.message, "RECORD_DELIVERY_ATTEMPT", auth.userId);
    return { success: false, error: errMsg, requestId };
  }

  // Log successful operation
  console.log(
    JSON.stringify({
      requestId,
      userId: auth.userId,
      operation: "RECORD_DELIVERY_ATTEMPT",
      status: "SUCCESS",
      timestamp: new Date().toISOString(),
    })
  );

  revalidatePath("/operator/delivery-attempts");
  revalidatePath("/operator/inventory");
  revalidatePath("/track");

  return {
    success: true,
    requestId,
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
