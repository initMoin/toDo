import assert from "node:assert/strict";
import test from "node:test";
import {
  isRecentVerification,
  latestSecondFactorTimestamp,
} from "../lib/authAssurance.ts";

test("finds the latest timestamp from a second-factor authentication method", () => {
  assert.equal(latestSecondFactorTimestamp([
    { method: "password", timestamp: 100 },
    { method: "totp", timestamp: 200 },
    { method: "mfa/totp", timestamp: 300 },
  ]), 300);
});

test("does not treat first-factor or timestamp-free methods as recent MFA", () => {
  assert.equal(latestSecondFactorTimestamp([
    "totp",
    { method: "password", timestamp: 200 },
    { method: "otp", timestamp: 300 },
  ]), null);
});

test("accepts a recent AAL2 verification and rejects stale or lower-assurance sessions", () => {
  const now = 2_000;
  assert.equal(isRecentVerification(1_500, accessToken({ aal: "aal2", auth_time: 1_000 }), now), true);
  assert.equal(isRecentVerification(1_399, accessToken({ aal: "aal2", auth_time: 1_000 }), now), false);
  assert.equal(isRecentVerification(1_999, accessToken({ aal: "aal1", auth_time: 1_999 }), now), false);
});

test("uses AAL2 auth_time only when detailed MFA timestamps are unavailable", () => {
  const now = 2_000;
  assert.equal(isRecentVerification(null, accessToken({ aal: "aal2", auth_time: 1_800 }), now), true);
  assert.equal(isRecentVerification(null, accessToken({ aal: "aal2", auth_time: 1_000 }), now), false);
  assert.equal(isRecentVerification(null, "not-a-token", now), false);
});

function accessToken(payload: Record<string, unknown>) {
  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString("base64url");
  return `header.${encodedPayload}.signature`;
}
