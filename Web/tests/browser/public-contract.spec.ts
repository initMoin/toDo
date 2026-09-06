import { expect, test } from "@playwright/test";

test.describe("public Web contract", () => {
  test("keeps provider choices behind the username step", async ({ page }) => {
    await page.goto("/");

    const username = page.getByLabel("Username");
    await expect(username).toBeVisible();
    await expect(page.getByRole("button", { name: "Continue with Apple" })).toHaveCount(0);
    await expect(page.getByRole("button", { name: "Continue with Google" })).toHaveCount(0);

    await username.fill("webtest");
    await page.getByRole("button", { name: "Move forward to sign-in options" }).click();

    await expect(page.getByRole("button", { name: "Use passkey" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Use email and password" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Continue with Apple" })).toHaveCount(0);
    await expect(page.getByRole("button", { name: "Continue with Google" })).toHaveCount(0);
    await page.getByRole("button", { name: "Other sign-in methods" }).click();
    await expect(page.getByRole("button", { name: "Continue with Apple" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Continue with Google" })).toBeVisible();
  });

  test("serves the primary route boundaries directly", async ({ page }) => {
    const routes = ["/", "/todos", "/stats", "/account", "/settings", "/legal/privacy", "/legal/terms"];
    const consoleErrors: string[] = [];
    page.on("console", (message) => {
      if (message.type() === "error") consoleErrors.push(message.text());
    });

    for (const route of routes) {
      const response = await page.goto(route);
      expect(response?.ok(), `${route} should return a successful response`).toBeTruthy();
      await expect(page.locator("body")).not.toContainText("Unhandled Script Error");
    }

    expect(consoleErrors, "primary routes should not emit browser runtime errors").toEqual([]);
  });

  test("keeps legal pages browser-native and independent from app navigation", async ({ page }) => {
    await page.goto("/legal/privacy");
    await expect(page).toHaveTitle(/toDō Web/);
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expect(page.getByRole("link", { name: "toDō home" })).toHaveAttribute("href", "/");
  });

  test("keeps nested settings routes reachable by direct URL", async ({ page }) => {
    for (const route of ["/settings/appearance", "/settings/behavior", "/settings/notifications", "/settings/data"]) {
      const response = await page.goto(route);
      expect(response?.ok(), `${route} should return a successful response`).toBeTruthy();
      await expect(page.locator("body")).not.toContainText("Unhandled Script Error");
    }
  });
});
