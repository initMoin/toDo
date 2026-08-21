import { createClient } from "jsr:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

type WebPushEvent = {
  id: string;
  user_id: string;
  event_type: string;
  attempts?: number;
  payload: {
    todo_id?: string;
    task?: string;
    collab_id?: string | null;
    is_done?: boolean;
    due_at?: string | null;
  };
};

const supabaseURL = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY");
const vapidPrivateKey = Deno.env.get("VAPID_PRIVATE_KEY");
const supabase = supabaseURL && serviceRoleKey
  ? createClient(supabaseURL, serviceRoleKey, { auth: { persistSession: false } })
  : null;

if (vapidPublicKey && vapidPrivateKey) {
  webpush.setVapidDetails(
    Deno.env.get("VAPID_SUBJECT") ?? "mailto:support@yourtodo.today",
    vapidPublicKey,
    vapidPrivateKey,
  );
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const expectedSecret = Deno.env.get("TODO_WEB_PUSH_WEBHOOK_SECRET");
  if (!expectedSecret) return json({ error: "Webhook authentication is unavailable" }, 503);
  if (!constantTimeEqual(request.headers.get("x-todo-webhook-secret"), expectedSecret)) {
    return json({ error: "Unauthorized" }, 401);
  }
  if (!supabase || !vapidPublicKey || !vapidPrivateKey) {
    return json({ error: "Web Push delivery is not configured" }, 503);
  }

  const body = await request.json().catch(() => ({}));
  const event = (body.record ?? body) as WebPushEvent;
  if (body.type && (body.type !== "INSERT" || body.table !== "web_push_events")) {
    return json({ skipped: true, reason: "Not a web push event insert" });
  }
  if (!event.id || !event.user_id) return json({ error: "Missing event record" }, 400);

  const { data: preferences } = await supabase
    .from("notification_preferences")
    .select("web_reminders_enabled")
    .eq("user_id", event.user_id)
    .maybeSingle();
  if (preferences?.web_reminders_enabled === false) {
    await markProcessed(event, null);
    return json({ skipped: true, reason: "Reminders disabled" });
  }

  const { data: subscriptions, error: subscriptionError } = await supabase
    .from("web_push_subscriptions")
    .select("id,endpoint,p256dh,auth")
    .eq("user_id", event.user_id)
    .eq("is_active", true);
  if (subscriptionError) return json({ error: subscriptionError.message }, 500);

  const taskLabel = event.payload.task || "A shared toDō changed";
  const title = event.event_type === "todo_created"
    ? "New toDō"
    : event.event_type === "todo_due"
      ? "toDō reminder"
    : event.event_type === "todo_completed"
      ? "toDō completed"
      : "toDō updated";
  const message = event.payload.is_done ? `${taskLabel} was completed.` : taskLabel;
  const notification = JSON.stringify({
    title,
    body: message,
    tag: `todo-${event.payload.todo_id ?? event.id}`,
    url: event.payload.todo_id ? `/todos/${event.payload.todo_id}` : "/",
  });

  let failed = 0;
  for (const subscription of subscriptions ?? []) {
    try {
      await webpush.sendNotification(
        {
          endpoint: subscription.endpoint,
          keys: { p256dh: subscription.p256dh, auth: subscription.auth },
        },
        notification,
        { TTL: 3600 },
      );
      await supabase
        .from("web_push_subscriptions")
        .update({ last_success_at: new Date().toISOString(), last_error_at: null })
        .eq("id", subscription.id);
    } catch (error) {
      failed += 1;
      const statusCode = error && typeof error === "object" && "statusCode" in error
        ? error.statusCode
        : null;
      const update = statusCode === 404 || statusCode === 410
        ? { is_active: false, last_error_at: new Date().toISOString() }
        : { last_error_at: new Date().toISOString() };
      await supabase.from("web_push_subscriptions").update(update).eq("id", subscription.id);
    }
  }

  await markProcessed(event, failed ? `${failed} deliveries failed` : null);
  return json({ delivered: (subscriptions?.length ?? 0) - failed, failed });
});

async function markProcessed(event: WebPushEvent, lastError: string | null) {
  if (!supabase) return;
  await supabase
    .from("web_push_events")
    .update({
      processed_at: new Date().toISOString(),
      attempts: (event.attempts ?? 0) + 1,
      last_error: lastError,
    })
    .eq("id", event.id);
}

function constantTimeEqual(left: string | null, right: string): boolean {
  if (!left || left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
