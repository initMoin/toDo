import { createHmac } from "node:crypto";
import { expect, test, type Page } from "@playwright/test";

const username = process.env.TODO_E2E_USERNAME?.trim() ?? "";
const email = process.env.TODO_E2E_EMAIL?.trim() ?? "";
const password = process.env.TODO_E2E_PASSWORD ?? "";
const totpSecret = process.env.TODO_E2E_TOTP_SECRET?.trim() ?? "";
const hasAuthenticatedFixture = Boolean(username && email && password && totpSecret);

test.use({ trace: "off", screenshot: "off", video: "off" });

test.describe("authenticated Web contract", () => {
  test.skip(
    !hasAuthenticatedFixture,
    "Set the disposable TODO_E2E_USERNAME, TODO_E2E_EMAIL, TODO_E2E_PASSWORD, and TODO_E2E_TOTP_SECRET values to run authenticated checks.",
  );
  test("resolves password and TOTP sign-in into the entitled account", async ({ page }) => {
    const consoleErrors = collectConsoleErrors(page);
    await signInDisposableAccount(page);

    await expect(page.getByRole("heading", { name: "What matters now?" })).toBeVisible();
    await expect(page.getByText("Home is part of toDō+", { exact: true })).toHaveCount(0);

    await page.goto("/todos");
    await expect(page.getByRole("heading", { name: "Active toDōs" })).toBeVisible();

    await page.goto("/account");
    await expect(page.getByRole("heading", { name: "Security" })).toBeVisible();
    await expect(page.getByText("Verified email", { exact: true })).toBeVisible();
    await expect(page.getByText("Authenticator app", { exact: true })).toBeVisible();
    await expect(page.getByText("Connected · Verified now", { exact: true })).toBeVisible();

    expect(consoleErrors, "authenticated routes should not emit browser runtime errors").toEqual([]);
  });

  test("downloads a protected account export after recent MFA", async ({ page }) => {
    await signInDisposableAccount(page);
    await page.goto("/settings/data");

    const downloadPromise = page.waitForEvent("download");
    await page.getByRole("button", { name: "Export account data" }).click();
    const download = await downloadPromise;

    expect(download.suggestedFilename()).toMatch(/^todo-export-\d{4}-\d{2}-\d{2}\.json$/);
    const stream = await download.createReadStream();
    expect(stream, "the export should produce a readable JSON file").not.toBeNull();

    let contents = "";
    for await (const chunk of stream!) contents += chunk.toString();
    const exported = JSON.parse(contents) as Record<string, unknown>;
    expect(Array.isArray(exported.todos)).toBeTruthy();
    expect(Array.isArray(exported.nanoDos)).toBeTruthy();
    expect(Array.isArray(exported.tags)).toBeTruthy();
    expect(Array.isArray(exported.collabs)).toBeTruthy();
  });
});

async function signInDisposableAccount(page: Page) {
  await page.goto("/");
  await page.getByLabel("Username").fill(username);
  await page.getByRole("button", { name: "Move forward to sign-in options" }).click();
  await page.getByRole("button", { name: "Use email and password" }).click();
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();

  const verificationHeading = page.getByRole("heading", { name: "Verify your account." });
  await expect(verificationHeading).toBeVisible({ timeout: 20_000 });
  await page.getByLabel("Authenticator code").fill(currentTOTP(totpSecret));
  await page.getByRole("button", { name: "Verify", exact: true }).click();
  await expect(page.getByRole("heading", { name: "What matters now?" })).toBeVisible({ timeout: 20_000 });
}

function collectConsoleErrors(page: Page) {
  const messages: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") messages.push(message.text());
  });
  return messages;
}

function currentTOTP(secret: string, now = Date.now()) {
  const key = decodeBase32(secret);
  const counter = BigInt(Math.floor(now / 30_000));
  const counterBytes = Buffer.alloc(8);
  counterBytes.writeBigUInt64BE(counter);
  const digest = createHmac("sha1", key).update(counterBytes).digest();
  const offset = digest[digest.length - 1] & 0x0f;
  const binary = (
    ((digest[offset] & 0x7f) << 24)
    | (digest[offset + 1] << 16)
    | (digest[offset + 2] << 8)
    | digest[offset + 3]
  );
  return String(binary % 1_000_000).padStart(6, "0");
}

function decodeBase32(value: string) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  const normalized = value.toUpperCase().replace(/[^A-Z2-7]/g, "");
  let bits = "";
  for (const character of normalized) {
    const index = alphabet.indexOf(character);
    if (index < 0) throw new Error("The disposable-account TOTP secret is not valid Base32.");
    bits += index.toString(2).padStart(5, "0");
  }

  const bytes: number[] = [];
  for (let index = 0; index + 8 <= bits.length; index += 8) {
    bytes.push(Number.parseInt(bits.slice(index, index + 8), 2));
  }
  return Buffer.from(bytes);
}
