/* eslint-disable */
/**
 * Test Suite for Centralized Error Mapper (Phase 13)
 * Execute with: node src/lib/courier/errors.test.js
 */

const assert = require("assert");
const { courierErrorMessage } = require("./errors.ts");

// Mock crypto.randomUUID since it is used in the mapper
if (!global.crypto) {
  global.crypto = {
    randomUUID: () => "mocked-uuid-1234-5678-9101"
  };
}

console.log("Starting Centralized Error Mapper Unit Tests...");

// Mock console.log only for verification
let loggedOutput = null;
const originalLog = console.log;

function runTest(testName, fn) {
  loggedOutput = null;
  console.log = (msg) => {
    try {
      loggedOutput = JSON.parse(msg);
    } catch (e) {
      originalLog("[LOG]", msg);
    }
  };
  
  try {
    fn();
    console.log = originalLog;
    console.log(`  ✔ ${testName} - PASSED`);
  } catch (err) {
    console.log = originalLog;
    console.error(`  ✘ ${testName} - FAILED`);
    throw err;
  }
}

try {
  // Test Case 1: Duplicate tracking mapping
  runTest("Duplicate tracking constraint", () => {
    const err = courierErrorMessage("duplicate key value violates unique constraint \"package_tracking_no_key\"", "TEST_OP", "user-123");
    assert.strictEqual(err, "Tracking number already exists");
    assert.strictEqual(loggedOutput.operation, "TEST_OP");
    assert.strictEqual(loggedOutput.userId, "user-123");
    assert.strictEqual(loggedOutput.errorCategory, "DUPLICATE_TRACKING");
    assert.ok(loggedOutput.requestId);
  });

  // Test Case 2: Sender equals receiver mapping
  runTest("Sender equals receiver restriction", () => {
    const err = courierErrorMessage("sender and receiver must differ", "TEST_OP", "user-123");
    assert.strictEqual(err, "Sender and receiver must differ");
    assert.strictEqual(loggedOutput.errorCategory, "SENDER_RECEIVER_MATCH");
  });

  // Test Case 3: Tier limit exceeded mapping
  runTest("Package tier service limits", () => {
    const err = courierErrorMessage("weight exceeds service limit", "TEST_OP", "user-123");
    assert.strictEqual(err, "Package exceeds service limit");
    assert.strictEqual(loggedOutput.errorCategory, "TIER_LIMIT_EXCEEDED");
  });

  // Test Case 4: Backward status mapping
  runTest("Status transition backwards block", () => {
    const err = courierErrorMessage("status cannot move backwards", "TEST_OP", "user-123");
    assert.strictEqual(err, "Status cannot move backwards");
    assert.strictEqual(loggedOutput.errorCategory, "BACKWARD_STATUS");
  });

  // Test Case 5: Skipped status mapping
  runTest("Status transition step sequencing", () => {
    const err = courierErrorMessage("skipped status, must repeat or advance", "TEST_OP", "user-123");
    assert.strictEqual(err, "Status must repeat or advance one step");
    assert.strictEqual(loggedOutput.errorCategory, "SKIPPED_STATUS");
  });

  // Test Case 6: Terminal package mapping
  runTest("Post-terminal closure blocks", () => {
    const err = courierErrorMessage("no event can be added after closure", "TEST_OP", "user-123");
    assert.strictEqual(err, "No event can be added after closure");
    assert.strictEqual(loggedOutput.errorCategory, "TERMINAL_PACKAGE");
  });

  // Test Case 7: Driver unavailable mapping
  runTest("Driver double-booking block", () => {
    const err = courierErrorMessage("driver is unavailable", "TEST_OP", "user-123");
    assert.strictEqual(err, "Driver is unavailable at this time");
    assert.strictEqual(loggedOutput.errorCategory, "DRIVER_DOUBLE_BOOKED");
  });

  // Test Case 8: Vehicle unavailable mapping
  runTest("Vehicle double-booking block", () => {
    const err = courierErrorMessage("vehicle is unavailable", "TEST_OP", "user-123");
    assert.strictEqual(err, "Vehicle is unavailable at this time");
    assert.strictEqual(loggedOutput.errorCategory, "VEHICLE_DOUBLE_BOOKED");
  });

  // Test Case 9: Missing failure reason mapping
  runTest("Missing failure reason mapping", () => {
    const err = courierErrorMessage("failure reason is required", "TEST_OP", "user-123");
    assert.strictEqual(err, "Failure reason is required");
    assert.strictEqual(loggedOutput.errorCategory, "MISSING_FAILURE_REASON");
  });

  // Test Case 10: RLS / permission mapping
  runTest("RLS security access denied", () => {
    const err = courierErrorMessage("row-level security policy violation", "TEST_OP", "user-123");
    assert.strictEqual(err, "You do not have permission");
    assert.strictEqual(loggedOutput.errorCategory, "PERMISSION_DENIED");
  });

  // Test Case 11: Unknown error mapping
  runTest("General unknown constraints", () => {
    const err = courierErrorMessage("Some completely unexpected constraint failed", "TEST_OP", "user-123");
    assert.strictEqual(err, "An unexpected error occurred. Please try again.");
    assert.strictEqual(loggedOutput.errorCategory, "UNKNOWN");
  });

  console.log("\nAll Centralized Error Mapper Unit Tests Passed Successfully! [11/11]");

} catch (err) {
  console.log = originalLog;
  console.error("\nTest execution failed!", err);
  process.exit(1);
}
