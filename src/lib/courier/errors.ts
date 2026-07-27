export function courierErrorMessage(message: string | undefined): string {
  const value = message ?? "The operation could not be completed.";
  if (/tracking number not found/i.test(value)) return "Tracking number was not found.";
  if (/receiver email is required/i.test(value)) return "Enter the receiver's email address.";
  if (/receiver customer not found/i.test(value)) return "No registered receiver matches that exact email address.";
  if (/sender and receiver/i.test(value)) return "Sender and receiver must be different customers.";
  if (/weight.*exceeds|exceeds maximum/i.test(value)) return "Package exceeds the selected service weight limit.";
  if (/weight must be greater/i.test(value)) return "Weight must be greater than zero.";
  if (/origin and destination/i.test(value)) return "Origin and destination hubs must be different.";
  if (/duplicate|unique/i.test(value)) return "A shipment with these unique details already exists.";
  if (/not authenticated/i.test(value)) return "Your session has expired. Sign in again.";
  if (/unauthorized|permission|row-level security/i.test(value)) return "You do not have permission to perform this action.";
  
  // Phase 9 status transitions and hub operator mappings
  if (/cannot move backwards|backward/i.test(value)) return "Status cannot move backwards.";
  if (/must repeat or advance|skipped status/i.test(value)) return "Status must repeat or advance exactly one step.";
  if (/terminal|event after delivered|no event can be added after closure/i.test(value)) return "No further events can be recorded after a package has reached a terminal status (Delivered or Returned).";
  if (/package is not at this hub/i.test(value)) return "Unauthorized: package is not at this hub.";
  if (/does not belong to hub/i.test(value)) return "Staff member does not belong to this hub.";
  
  // Phase 9 delivery attempt mappings
  if (/driver not found/i.test(value)) return "Driver was not found.";
  if (/failure reason is required/i.test(value)) return "Failure reason is required for a failed delivery attempt.";
  if (/failure reason must be null/i.test(value)) return "Failure reason must be null for a successful delivery.";
  
  return value.includes(":") ? value.split(":").slice(-1)[0].trim() : "The database rejected the request. Check the form and try again.";
}
