'use server'

import { revalidatePath } from "next/cache";
import { getAuthContext } from "@/lib/auth/auth-context";
import { createClient } from "@/lib/supabase/server";
import { courierErrorMessage } from "@/lib/courier/errors";

export interface ScanResult {
  success: boolean;
  error?: string;
  data?: unknown;
}

export async function recordCheckpointScan(formData: FormData): Promise<ScanResult> {
  const auth = await getAuthContext();
  if (auth.status !== "active" || auth.appRole !== "HUB_OPERATOR") {
    return { success: false, error: "Unauthorized: must be a Hub Operator." };
  }

  const staffId = auth.staffId;
  if (!staffId) {
    return { success: false, error: "Your account is not linked to any staff member." };
  }

  const trackingNo = (formData.get("tracking_no") as string)?.trim().toUpperCase();
  const statusCode = formData.get("status_code") as string;
  const eventTimeStr = formData.get("event_time") as string;

  if (!trackingNo) {
    return { success: false, error: "Tracking number is required." };
  }
  if (!statusCode) {
    return { success: false, error: "Status is required." };
  }
  if (!eventTimeStr) {
    return { success: false, error: "Event time is required." };
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
    return { success: false, error: "Failed to resolve your assigned hub." };
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
    return { success: false, error: courierErrorMessage(error.message) };
  }

  revalidatePath("/operator/inventory");
  revalidatePath("/operator/scans");
  revalidatePath("/track");

  return {
    success: true,
    data: {
      trackingNo,
      statusCode,
      eventTime,
      hubId,
      staffId
    }
  };
}
