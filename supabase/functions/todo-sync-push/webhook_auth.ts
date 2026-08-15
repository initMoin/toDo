export interface WebhookAuthorizationFailure {
  message: string;
  responseMessage: string;
  status: number;
}

export function authorizeWebhookRequest(
  request: Request,
  configuredSecrets: Array<string | null | undefined>,
): WebhookAuthorizationFailure | null {
  const acceptedSecrets = [
    ...new Set(
      configuredSecrets
        .map((secret) => secret?.trim())
        .filter((secret): secret is string => Boolean(secret)),
    ),
  ];

  if (acceptedSecrets.length === 0) {
    return {
      message:
        "Rejected todo-sync-push webhook request: webhook authentication is not configured.",
      responseMessage: "Webhook authentication is unavailable",
      status: 503,
    };
  }

  const headerSecret = request.headers.get("x-todo-webhook-secret")?.trim();
  const authorization = request.headers.get("authorization")?.trim();
  const bearerSecret = authorization?.toLowerCase().startsWith("bearer ")
    ? authorization.slice("bearer ".length).trim()
    : null;

  const isAuthorized = acceptedSecrets.some((expectedSecret) =>
    constantTimeEqual(headerSecret, expectedSecret) ||
    constantTimeEqual(bearerSecret, expectedSecret)
  );

  if (isAuthorized) {
    return null;
  }

  return {
    message:
      "Rejected todo-sync-push webhook request: missing or invalid webhook secret.",
    responseMessage: "Unauthorized",
    status: 401,
  };
}

function constantTimeEqual(
  left: string | null | undefined,
  right: string,
): boolean {
  if (!left || left.length !== right.length) return false;

  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }

  return difference === 0;
}
