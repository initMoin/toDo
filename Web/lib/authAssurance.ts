const recentAAL2WindowSeconds = 10 * 60;
const allowedFutureClockSkewSeconds = 60;
const secondFactorMethods = new Set([
  "totp",
  "mfa/totp",
  "mfa/phone",
  "mfa/webauthn",
]);

type AuthenticationMethod =
  | string
  | {
      method?: unknown;
      timestamp?: unknown;
    };

export function latestSecondFactorTimestamp(
  authenticationMethods: AuthenticationMethod[],
): number | null {
  let latestTimestamp: number | null = null;

  for (const entry of authenticationMethods) {
    if (typeof entry === "string") continue;
    if (typeof entry?.method !== "string" || !secondFactorMethods.has(entry.method)) continue;

    const timestamp = Number(entry.timestamp);
    if (!Number.isFinite(timestamp)) continue;
    latestTimestamp = latestTimestamp === null
      ? timestamp
      : Math.max(latestTimestamp, timestamp);
  }

  return latestTimestamp;
}

export function isRecentVerification(
  verifiedAt: number | null,
  accessToken: string,
  nowSeconds = Math.floor(Date.now() / 1000),
): boolean {
  const claims = decodeAccessTokenClaims(accessToken);
  if (claims?.aal !== "aal2") return false;

  const authTime = toFiniteNumber(claims.auth_time);
  const timestamp = verifiedAt ?? authTime;
  if (timestamp === null) return false;

  const age = nowSeconds - timestamp;
  return age >= -allowedFutureClockSkewSeconds && age <= recentAAL2WindowSeconds;
}

function decodeAccessTokenClaims(accessToken: string): Record<string, unknown> | null {
  const payload = accessToken.split(".")[1];
  if (!payload) return null;

  try {
    const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    const bytes = Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
    const parsed = JSON.parse(new TextDecoder().decode(bytes));
    return typeof parsed === "object" && parsed !== null
      ? parsed as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

function toFiniteNumber(value: unknown): number | null {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? number : null;
}
