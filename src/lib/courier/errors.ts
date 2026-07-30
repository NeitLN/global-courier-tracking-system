import { randomUUID } from "crypto";

/**
 * Maps database and system level error messages into clean, user-friendly, and secure messages.
 * Logs structured server-side diagnostic information containing a requestId and excluding any raw secrets or PII.
 */
export function courierErrorMessage(
  message: string | undefined,
  operation = "UNKNOWN_OPERATION",
  userId?: string
): string {
  const value = message ?? "";
  const requestId = randomUUID();
  let errorCategory = "UNKNOWN";
  let mappedMessage = "An unexpected error occurred. Please try again.";

  // 1. Precise Error Mapping Logic
  if (/duplicate.*tracking_no|tracking_no.*exists/i.test(value)) {
    errorCategory = "DUPLICATE_TRACKING";
    mappedMessage = "Tracking number already exists";
  } else if (/sender.*receiver/i.test(value)) {
    errorCategory = "SENDER_RECEIVER_MATCH";
    mappedMessage = "Sender and receiver must differ";
  } else if (/exceed.*limit|exceeds maximum|weight.*exceeds/i.test(value)) {
    errorCategory = "TIER_LIMIT_EXCEEDED";
    mappedMessage = "Package exceeds service limit";
  } else if (/cannot move backwards|backward/i.test(value)) {
    errorCategory = "BACKWARD_STATUS";
    mappedMessage = "Status cannot move backwards";
  } else if (/must repeat or advance|skipped status/i.test(value)) {
    errorCategory = "SKIPPED_STATUS";
    mappedMessage = "Status must repeat or advance one step";
  } else if (/terminal|event after delivered|no event can be added after closure/i.test(value)) {
    errorCategory = "TERMINAL_PACKAGE";
    mappedMessage = "No event can be added after closure";
  } else if (/driver.*unavailable|driver is unavailable/i.test(value)) {
    errorCategory = "DRIVER_DOUBLE_BOOKED";
    mappedMessage = "Driver is unavailable at this time";
  } else if (/vehicle.*unavailable|vehicle is unavailable/i.test(value)) {
    errorCategory = "VEHICLE_DOUBLE_BOOKED";
    mappedMessage = "Vehicle is unavailable at this time";
  } else if (/failure reason is required/i.test(value)) {
    errorCategory = "MISSING_FAILURE_REASON";
    mappedMessage = "Failure reason is required";
  } else if (/unauthorized|permission|row-level security|permission denied/i.test(value)) {
    errorCategory = "PERMISSION_DENIED";
    mappedMessage = "You do not have permission";
  } else if (value && value.includes(":")) {
    // Other database check constraints or standard errors
    errorCategory = "DATABASE_CONSTRAINT";
    mappedMessage = value.split(":").slice(-1)[0].trim();
  }

  // 2. Structured Server-Side Logging (No secrets, cookie headers or raw PII)
  console.log(
    JSON.stringify({
      requestId,
      userId: userId || "UNauthenticated",
      operation,
      errorCategory,
      timestamp: new Date().toISOString(),
    })
  );

  return mappedMessage;
}
