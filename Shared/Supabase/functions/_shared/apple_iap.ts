import {
  Environment,
  type JWSRenewalInfoDecodedPayload,
  type JWSTransactionDecodedPayload,
  type ResponseBodyV2DecodedPayload,
  SignedDataVerifier,
} from "npm:@apple/app-store-server-library@3.1.0";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { Buffer } from "node:buffer";
import { createRequire } from "node:module";
import type { X509Certificate } from "node:crypto";
import { appleRootCertificates } from "./apple_root_certificates.ts";

export type EntitlementKey = "todo_plus" | "founding_supporter";

interface AppleAppConfiguration {
  bundleID: string;
  appAppleID?: number;
}

interface VerifiedApplePayload<T> {
  decoded: T;
  verifier: SignedDataVerifier;
}

const productEntitlements: Record<string, EntitlementKey | undefined> = {
  "dev.iamshift.todo.plus.monthly": "todo_plus",
  "dev.iamshift.todo.plus.yearly": "todo_plus",
  "dev.iamshift.todo.plus.lifetime": "todo_plus",
  "dev.iamshift.todo.appreciation.founding": "founding_supporter",
};

installDenoX509CertificateCompatibility();

// Apple's official JavaScript verifier uses X509Certificate.toString() for
// cache keys and OCSP requests, and X509Certificate.raw for certificate
// extension checks. Supabase Edge's Deno Node-compatibility layer exposes
// both members but some deployed runtimes throw "Not implemented" when they
// are read. Wrap the constructor resolved by Apple's CommonJS library so the
// original DER bytes are retained without changing Apple's verification flow.
function installDenoX509CertificateCompatibility(): void {
  if (typeof Deno === "undefined") return;

  const require = createRequire(import.meta.url);
  const cryptoModule = require("crypto") as {
    X509Certificate: X509CertificateConstructor;
  };
  const NativeX509Certificate = cryptoModule
    .X509Certificate as RuntimeX509CertificateConstructor;
  const nativeRawGetter = Object.getOwnPropertyDescriptor(
    NativeX509Certificate.prototype,
    "raw",
  )?.get as ((this: X509Certificate) => Buffer) | undefined;
  const rawByCertificate = new WeakMap<X509Certificate, Buffer>();

  class CompatibleX509Certificate extends NativeX509Certificate {
    constructor(input: X509CertificateInput) {
      super(input);
      rawByCertificate.set(
        this as unknown as X509Certificate,
        derBytes(input),
      );
    }

    get raw(): Buffer {
      try {
        if (nativeRawGetter) {
          return nativeRawGetter.call(this as unknown as X509Certificate);
        }
      } catch {
        const raw = rawByCertificate.get(
          this as unknown as X509Certificate,
        );
        if (!raw) throw new Error("Missing X.509 certificate bytes");
        return raw;
      }

      const raw = rawByCertificate.get(
        this as unknown as X509Certificate,
      );
      if (!raw) throw new Error("Missing X.509 certificate bytes");
      return raw;
    }

    override toString(): string {
      return pemFromDER(this.raw);
    }

    toJSON(): string {
      return this.toString();
    }
  }

  cryptoModule.X509Certificate =
    CompatibleX509Certificate as unknown as X509CertificateConstructor;
}

type X509CertificateInput = string | ArrayBuffer | ArrayBufferView;
type X509CertificateConstructor = new (
  input: X509CertificateInput,
) => X509Certificate;
type RuntimeX509CertificateConstructor = {
  new (input: X509CertificateInput): object;
  prototype: object;
};

function derBytes(input: X509CertificateInput): Buffer {
  if (typeof input === "string") {
    return Buffer.from(
      input
        .replace("-----BEGIN CERTIFICATE-----", "")
        .replace("-----END CERTIFICATE-----", ""),
      "base64",
    );
  }

  if (input instanceof ArrayBuffer) return Buffer.from(new Uint8Array(input));

  return Buffer.from(
    new Uint8Array(input.buffer, input.byteOffset, input.byteLength),
  );
}

function pemFromDER(raw: Buffer): string {
  const base64 = raw.toString("base64");
  const lines = base64.match(/.{1,64}/g)?.join("\n") ?? "";
  return `-----BEGIN CERTIFICATE-----\n${lines}\n-----END CERTIFICATE-----`;
}

export function createServiceClient(): SupabaseClient {
  const url = requiredEnvironmentValue("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    defaultSupabaseSecretKey();

  if (!serviceKey) {
    throw new Error("Missing Supabase server secret key");
  }

  return createClient(url, serviceKey, { auth: { persistSession: false } });
}

export async function verifyNotification(
  signedPayload: string,
): Promise<VerifiedApplePayload<ResponseBodyV2DecodedPayload>> {
  return await verifyWithConfiguredApps((verifier) =>
    verifier.verifyAndDecodeNotification(signedPayload)
  );
}

export async function verifyTransaction(
  signedTransaction: string,
): Promise<VerifiedApplePayload<JWSTransactionDecodedPayload>> {
  return await verifyWithConfiguredApps((verifier) =>
    verifier.verifyAndDecodeTransaction(signedTransaction)
  );
}

export async function persistVerifiedTransaction(
  supabase: SupabaseClient,
  transaction: JWSTransactionDecodedPayload,
  signedTransaction: string,
  accountID: string | null,
): Promise<void> {
  const transactionID = requiredString(
    transaction.transactionId,
    "transactionId",
  );
  const originalTransactionID = requiredString(
    transaction.originalTransactionId,
    "originalTransactionId",
  );

  const record = {
    transaction_id: transactionID,
    original_transaction_id: originalTransactionID,
    web_order_line_item_id: transaction.webOrderLineItemId ?? null,
    app_account_token: transaction.appAccountToken ?? null,
    account_id: accountID,
    product_id: requiredString(transaction.productId, "productId"),
    product_type: transaction.type ?? null,
    bundle_id: requiredString(transaction.bundleId, "bundleId"),
    app_apple_id: numericEnvironmentValueForBundle(transaction.bundleId),
    environment: normalizeEnvironment(transaction.environment),
    ownership_type: transaction.inAppOwnershipType ?? null,
    offer_identifier: transaction.offerIdentifier ?? null,
    offer_type: transaction.offerType ?? null,
    purchased_at: dateFromMilliseconds(transaction.purchaseDate),
    original_purchased_at: dateFromMilliseconds(
      transaction.originalPurchaseDate,
    ),
    expires_at: dateFromMilliseconds(transaction.expiresDate),
    revoked_at: dateFromMilliseconds(transaction.revocationDate),
    revocation_reason: transaction.revocationReason ?? null,
    signed_transaction: signedTransaction,
    decoded_transaction: transaction,
    updated_at: new Date().toISOString(),
  };

  const { error } = await supabase
    .from("apple_iap_transactions")
    .upsert(record, { onConflict: "transaction_id" });

  if (error) {
    throw new Error(`Could not store Apple transaction: ${error.message}`);
  }
}

export async function resolveLinkedAccount(
  supabase: SupabaseClient,
  transaction: JWSTransactionDecodedPayload,
): Promise<string | null> {
  const originalTransactionID = requiredString(
    transaction.originalTransactionId,
    "originalTransactionId",
  );
  const { data: existing, error: linkError } = await supabase
    .from("apple_purchase_account_links")
    .select("account_id, link_kind")
    .eq("original_transaction_id", originalTransactionID)
    .order("linked_at", { ascending: true });

  if (linkError) {
    throw new Error(`Could not load purchase link: ${linkError.message}`);
  }

  const purchaser = existing?.find((link) => link.link_kind === "purchaser");
  if (purchaser?.account_id) return purchaser.account_id;

  if (
    transaction.inAppOwnershipType === "PURCHASED" &&
    transaction.appAccountToken &&
    await profileExists(supabase, transaction.appAccountToken)
  ) {
    await linkPurchaseToAccount(
      supabase,
      transaction,
      transaction.appAccountToken,
    );
    return transaction.appAccountToken;
  }

  return null;
}

export async function linkPurchaseToAccount(
  supabase: SupabaseClient,
  transaction: JWSTransactionDecodedPayload,
  accountID: string,
): Promise<void> {
  const originalTransactionID = requiredString(
    transaction.originalTransactionId,
    "originalTransactionId",
  );
  const familyShared = transaction.inAppOwnershipType === "FAMILY_SHARED";
  const linkKind = familyShared ? "family_shared" : "purchaser";

  if (!familyShared) {
    const { data: purchaser, error: purchaserError } = await supabase
      .from("apple_purchase_account_links")
      .select("account_id")
      .eq("original_transaction_id", originalTransactionID)
      .eq("link_kind", "purchaser")
      .maybeSingle();

    if (purchaserError) {
      throw new Error(
        `Could not check purchase owner: ${purchaserError.message}`,
      );
    }
    if (purchaser && purchaser.account_id !== accountID) {
      throw new Error(
        "This purchase is already linked to another toDō account",
      );
    }
  }

  const { error } = await supabase.from("apple_purchase_account_links").upsert({
    original_transaction_id: originalTransactionID,
    account_id: accountID,
    link_kind: linkKind,
    ownership_type: transaction.inAppOwnershipType ?? null,
    linked_by: "verified_transaction",
  }, { onConflict: "original_transaction_id,account_id" });

  if (error) throw new Error(`Could not link Apple purchase: ${error.message}`);
}

export async function updateEntitlement(
  supabase: SupabaseClient,
  transaction: JWSTransactionDecodedPayload,
  accountID: string,
  notificationType?: string,
  subtype?: string,
  renewalInfo?: JWSRenewalInfoDecodedPayload,
): Promise<EntitlementKey | null> {
  const productID = requiredString(transaction.productId, "productId");
  const entitlementKey = productEntitlements[productID];
  if (!entitlementKey) return null;

  const originalTransactionID = requiredString(
    transaction.originalTransactionId,
    "originalTransactionId",
  );
  const now = Date.now();
  const expiresAt = transaction.expiresDate;
  const graceExpiresAt = renewalInfo?.gracePeriodExpiresDate;
  const revoked = transaction.revocationDate !== undefined ||
    notificationType === "REVOKE" || notificationType === "REFUND";
  const grace = subtype === "GRACE_PERIOD" &&
    graceExpiresAt !== undefined && graceExpiresAt > now;
  const expired = notificationType === "EXPIRED" ||
    (expiresAt !== undefined && expiresAt <= now && !grace);
  const status = revoked
    ? "revoked"
    : grace
    ? "grace"
    : expired
    ? "expired"
    : "active";
  const effectiveExpiry = grace ? graceExpiresAt : expiresAt;
  const readOnlyAnchor = transaction.revocationDate ?? effectiveExpiry;
  const webReadOnlyUntil = status === "expired" || status === "revoked"
    ? dateFromMilliseconds((readOnlyAnchor ?? now) + 30 * 24 * 60 * 60 * 1000)
    : null;

  const { error } = await supabase.from("account_entitlements").upsert({
    account_id: accountID,
    entitlement_key: entitlementKey,
    source_kind: entitlementKey === "founding_supporter"
      ? "support"
      : "apple_iap",
    source_id: originalTransactionID,
    source_product_id: productID,
    source_transaction_id: transaction.transactionId ?? null,
    status,
    ownership_type: transaction.inAppOwnershipType ?? null,
    expires_at: dateFromMilliseconds(effectiveExpiry),
    web_read_only_until: webReadOnlyUntil,
    revoked_at: revoked
      ? dateFromMilliseconds(transaction.revocationDate ?? now)
      : null,
    updated_at: new Date().toISOString(),
  }, { onConflict: "account_id,entitlement_key,source_kind,source_id" });

  if (error) throw new Error(`Could not update entitlement: ${error.message}`);
  return entitlementKey;
}

async function verifyWithConfiguredApps<T>(
  operation: (verifier: SignedDataVerifier) => Promise<T>,
): Promise<VerifiedApplePayload<T>> {
  const errors: string[] = [];

  for (const app of configuredApps()) {
    for (const environment of [Environment.SANDBOX, Environment.PRODUCTION]) {
      if (
        environment === Environment.PRODUCTION && app.appAppleID === undefined
      ) continue;

      const verifier = new SignedDataVerifier(
        appleRootCertificates,
        true,
        environment,
        app.bundleID,
        environment === Environment.PRODUCTION ? app.appAppleID : undefined,
      );

      try {
        return { decoded: await operation(verifier), verifier };
      } catch (error) {
        errors.push(`${app.bundleID}/${environment}: ${errorMessage(error)}`);
      }
    }
  }

  throw new Error(`Apple signature verification failed (${errors.join("; ")})`);
}

function configuredApps(): AppleAppConfiguration[] {
  const candidates = [
    ["APPLE_BUNDLE_ID_IOS", "APPLE_APP_ID_IOS"],
    ["APPLE_BUNDLE_ID_MACOS", "APPLE_APP_ID_MACOS"],
  ] as const;

  const apps = candidates.flatMap(([bundleKey, appIDKey]) => {
    const bundleID = Deno.env.get(bundleKey)?.trim();
    if (!bundleID) return [];

    const rawAppID = Deno.env.get(appIDKey)?.trim();
    const appAppleID = rawAppID ? Number(rawAppID) : undefined;
    if (rawAppID && (!Number.isSafeInteger(appAppleID) || appAppleID! <= 0)) {
      throw new Error(
        `${appIDKey} must be a positive numeric App Store Apple ID`,
      );
    }
    return [{ bundleID, appAppleID }];
  });

  if (apps.length === 0) {
    throw new Error("No Apple app bundle IDs are configured");
  }

  // iOS and macOS intentionally share the primary universal-purchase
  // identity. Keep one verifier candidate for that identity so diagnostics
  // and verification work are not duplicated.
  const uniqueApps = new Map<string, AppleAppConfiguration>();
  for (const app of apps) {
    uniqueApps.set(`${app.bundleID}:${app.appAppleID ?? ""}`, app);
  }
  return [...uniqueApps.values()];
}

async function profileExists(
  supabase: SupabaseClient,
  accountID: string,
): Promise<boolean> {
  const { data, error } = await supabase
    .from("profiles")
    .select("id")
    .eq("id", accountID)
    .maybeSingle();
  if (error) {
    throw new Error(`Could not validate App Account Token: ${error.message}`);
  }
  return data !== null;
}

function numericEnvironmentValueForBundle(bundleID?: string): number | null {
  const app = configuredApps().find((candidate) =>
    candidate.bundleID === bundleID
  );
  return app?.appAppleID ?? null;
}

function requiredEnvironmentValue(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function defaultSupabaseSecretKey(): string | undefined {
  const rawKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!rawKeys) return undefined;

  try {
    const keys = JSON.parse(rawKeys) as Record<string, string>;
    return keys.default;
  } catch {
    throw new Error("SUPABASE_SECRET_KEYS is not valid JSON");
  }
}

function requiredString(value: string | undefined, name: string): string {
  if (!value) throw new Error(`Verified Apple payload is missing ${name}`);
  return value;
}

function normalizeEnvironment(environment?: string): "Sandbox" | "Production" {
  if (environment === "Sandbox" || environment === "Production") {
    return environment;
  }
  throw new Error(`Unexpected Apple environment: ${environment ?? "missing"}`);
}

function dateFromMilliseconds(value?: number): string | null {
  return value === undefined ? null : new Date(value).toISOString();
}

export function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    const details = [
      error.name !== "Error" ? error.name : undefined,
      error.message || undefined,
      readVerificationStatus(error),
      error.cause ? `cause: ${errorMessage(error.cause)}` : undefined,
    ].filter((value): value is string => Boolean(value));

    if (details.length > 0) return details.join("; ");
  }

  if (typeof error === "object" && error !== null) {
    try {
      const serialized = JSON.stringify(error);
      if (serialized && serialized !== "{}") return serialized;
    } catch {
      // Fall through to the non-sensitive string representation.
    }
  }

  const fallback = String(error);
  return fallback || "Unknown Apple verification error";
}

function readErrorField(error: Error, key: string): string | undefined {
  const value = (error as unknown as Record<string, unknown>)[key];
  if (value === undefined || value === null || value === "") return undefined;
  return `${key}: ${String(value)}`;
}

function readVerificationStatus(error: Error): string | undefined {
  const value = (error as unknown as Record<string, unknown>).status;
  if (typeof value !== "number") return readErrorField(error, "status");

  const names = [
    "OK",
    "VERIFICATION_FAILURE",
    "RETRYABLE_VERIFICATION_FAILURE",
    "INVALID_APP_IDENTIFIER",
    "INVALID_ENVIRONMENT",
    "INVALID_CHAIN_LENGTH",
    "INVALID_CERTIFICATE",
    "FAILURE",
  ];
  return `status: ${names[value] ?? value}`;
}
