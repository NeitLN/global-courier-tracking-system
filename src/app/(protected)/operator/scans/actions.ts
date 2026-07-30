'use server'

import { revalidatePath } from "next/cache";
import { getAuthContext } from "@/lib/auth/auth-context";
import { createClient } from "@/lib/supabase/server";
import { courierErrorMessage } from "@/lib/courier/errors";

import { randomUUID } from "crypto";

export interface ScanResult {
  success: boolean;
  error?: string;
  data?: unknown;
  requestId?: string;
}

export async function recordCheckpointScan(formData: FormData): Promise<ScanResult> {
  const auth = await getAuthContext();
  const requestId = randomUUID();

  if (auth.status !== "active" || auth.appRole !== "HUB_OPERATOR") {
    return { success: false, error: "Unauthorized: must be a Hub Operator.", requestId };
  }

  const staffId = auth.staffId;
  if (!staffId) {
    return { success: false, error: "Your account is not linked to any staff member.", requestId };
  }

  const trackingNo = (formData.get("tracking_no") as string)?.trim().toUpperCase();
  const statusCode = formData.get("status_code") as string;
  const eventTimeStr = formData.get("event_time") as string;

  if (!trackingNo) {
    return { success: false, error: "Tracking number is required.", requestId };
  }
  if (!statusCode) {
    return { success: false, error: "Status is required.", requestId };
  }
  if (!eventTimeStr) {
    return { success: false, error: "Event time is required.", requestId };
  }

  const eventTime = new Date(eventTimeStr).toISOString();

  const supabase = await createClient();

  // 1. Fetch the hub_id of the staff member
  const { data: staff, error: staffError } = await supabase
    .from("staff")
    .select("hub_id")
    .eq("staff_id", staffId)
    .single();

  if (staffError || !staff) {
    return { success: false, error: "Failed to resolve your assigned hub.", requestId };
  }

  const hubId = staff.hub_id;

  // 2. Call the fn_record_checkpoint_scan RPC
  const { error } = await supabase.rpc("fn_record_checkpoint_scan", {
    p_tracking_no: trackingNo,
    p_hub_id: hubId,
    p_status_code: statusCode,
    p_event_time: eventTime,
    p_recorded_by: staffId
  });

  if (error) {
    const errMsg = courierErrorMessage(error.message, "RECORD_CHECKPOINT_SCAN", auth.userId);
    return { success: false, error: errMsg, requestId };
  }

  // Log successful operation
  console.log(
    JSON.stringify({
      requestId,
      userId: auth.userId,
      operation: "RECORD_CHECKPOINT_SCAN",
      status: "SUCCESS",
      timestamp: new Date().toISOString(),
    })
  );

  revalidatePath("/operator/inventory");
  revalidatePath("/operator/scans");
  revalidatePath("/track");

  return {
    success: true,
    requestId,
    data: {
      trackingNo,
      statusCode,
      eventTime,
      hubId,
      staffId
    }
  };
}
