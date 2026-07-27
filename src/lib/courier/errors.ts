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
  return "The database rejected the request. Check the form and try again.";
}
