import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const profileImageBucket = "profile-images";

interface StorageObject {
  name: string;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const accessToken = request.headers
    .get("authorization")
    ?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!accessToken) {
    return json({ error: "Authentication required" }, 401);
  }

  const serviceClient = createServiceClient();
  const { data: { user }, error: authError } = await serviceClient.auth.getUser(
    accessToken,
  );
  if (authError || !user) {
    return json({ error: "Invalid session" }, 401);
  }

  try {
    await removeProfileImages(serviceClient, user.id);

    const { error: dataError } = await serviceClient.rpc(
      "delete_account_data",
      { target_user_id: user.id },
    );
    if (dataError) throw dataError;

    const { error: authDeletionError } = await serviceClient.auth.admin.deleteUser(
      user.id,
    );
    if (authDeletionError) throw authDeletionError;

    return json({ deleted: true });
  } catch (error) {
    // Do not include account identifiers, tokens, or provider payloads in logs.
    console.error("Account deletion failed", errorMessage(error));
    return json({ error: "Account deletion could not be completed." }, 500);
  }
});

function createServiceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) {
    throw new Error("Supabase service configuration is missing");
  }

  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function removeProfileImages(
  client: SupabaseClient,
  userID: string,
): Promise<void> {
  const { data: objects, error: listError } = await client.storage
    .from(profileImageBucket)
    .list(userID, { limit: 1000 });
  if (listError) throw listError;

  const paths = (objects as StorageObject[] | null | undefined ?? [])
    .map((object) => `${userID}/${object.name}`)
    .filter((path) => path.length > userID.length + 1);
  if (paths.length === 0) return;

  const { error: removeError } = await client.storage
    .from(profileImageBucket)
    .remove(paths);
  if (removeError) throw removeError;
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Unknown deletion error";
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
