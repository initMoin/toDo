import {
  createServiceClient,
  errorMessage,
  linkPurchaseToAccount,
  persistVerifiedTransaction,
  updateEntitlement,
  verifyTransaction,
} from "../_shared/apple_iap.ts";

interface LinkRequest {
  signedTransactionInfo?: string;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authorization = request.headers.get("authorization");
  const accessToken = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!accessToken) return json({ error: "Authentication required" }, 401);

  const supabase = createServiceClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser(
    accessToken,
  );
  if (authError || !user) return json({ error: "Invalid session" }, 401);

  try {
    const body = await request.json() as LinkRequest;
    if (!body.signedTransactionInfo) {
      return json({ error: "Missing signedTransactionInfo" }, 400);
    }

    const { decoded: transaction } = await verifyTransaction(
      body.signedTransactionInfo,
    );
    await linkPurchaseToAccount(supabase, transaction, user.id);
    await persistVerifiedTransaction(
      supabase,
      transaction,
      body.signedTransactionInfo,
      user.id,
    );
    const entitlement = await updateEntitlement(supabase, transaction, user.id);

    return json({ linked: true, entitlement });
  } catch (error) {
    const message = errorMessage(error);
    console.error("Apple purchase linking failed", message);
    const status = message.includes("already linked") ? 409 : 400;
    return json({ error: message }, status);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
