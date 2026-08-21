import { authorizeWebhookRequest } from "./webhook_auth.ts";

function assertEquals<T>(actual: T, expected: T): void {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${String(expected)}, received ${String(actual)}`);
  }
}

Deno.test("webhook authorization fails closed when no secret is configured", () => {
  const failure = authorizeWebhookRequest(new Request("https://example.test"), [
    undefined,
    " ",
  ]);

  assertEquals(failure?.status, 503);
});

Deno.test("webhook authorization accepts the primary custom-header secret", () => {
  const request = new Request("https://example.test", {
    headers: { "X-ToDo-Webhook-Secret": "primary-secret" },
  });

  assertEquals(authorizeWebhookRequest(request, ["primary-secret"]), null);
});

Deno.test("webhook authorization accepts a rotation secret", () => {
  const request = new Request("https://example.test", {
    headers: { "X-ToDo-Webhook-Secret": "next-secret" },
  });

  assertEquals(
    authorizeWebhookRequest(request, ["primary-secret", "next-secret"]),
    null,
  );
});

Deno.test("webhook authorization accepts the legacy bearer transport during rotation", () => {
  const request = new Request("https://example.test", {
    headers: { Authorization: "Bearer primary-secret" },
  });

  assertEquals(authorizeWebhookRequest(request, ["primary-secret"]), null);
});

Deno.test("webhook authorization rejects invalid credentials", () => {
  const request = new Request("https://example.test", {
    headers: { "X-ToDo-Webhook-Secret": "wrong-secret" },
  });

  const failure = authorizeWebhookRequest(request, ["primary-secret"]);
  assertEquals(failure?.status, 401);
});
