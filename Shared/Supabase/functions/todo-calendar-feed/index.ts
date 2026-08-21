import { createClient } from "jsr:@supabase/supabase-js@2";

type TodoRecord = {
  id: string;
  task: string | null;
  notes: string | null;
  due_at: string | null;
  updated_at: string | null;
  lifecycle_state: string | null;
};

const supabaseURL = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = supabaseURL && serviceRoleKey
  ? createClient(supabaseURL, serviceRoleKey, { auth: { persistSession: false } })
  : null;

Deno.serve(async (request) => {
  if (request.method !== "GET") return new Response("Method not allowed", { status: 405 });
  if (!supabase) return textResponse("Calendar feed is not configured.", 503);

  const token = new URL(request.url).searchParams.get("token")?.trim();
  if (!token) return textResponse("Calendar feed token is required.", 401);

  const tokenHash = await sha256Hex(token);
  const { data: feed, error: feedError } = await supabase
    .from("web_calendar_feeds")
    .select("id,user_id,revoked_at")
    .eq("token_hash", tokenHash)
    .maybeSingle();
  if (feedError) return textResponse("Calendar feed could not be loaded.", 500);
  if (!feed || feed.revoked_at) return textResponse("Calendar feed is no longer available.", 410);

  await supabase
    .from("web_calendar_feeds")
    .update({ last_accessed_at: new Date().toISOString() })
    .eq("id", feed.id);

  const { data: memberships } = await supabase
    .from("collab_users")
    .select("collab_id")
    .eq("user_id", feed.user_id);
  const collabIDs = (memberships ?? []).map((membership) => membership.collab_id).filter(Boolean);

  let query = supabase
    .from("todos")
    .select("id,task,notes,due_at,updated_at,lifecycle_state")
    .eq("is_done", false)
    .not("due_at", "is", null)
    .order("due_at", { ascending: true });
  if (collabIDs.length) {
    query = query.or(`user_id.eq.${feed.user_id},collab_id.in.(${collabIDs.join(",")})`);
  } else {
    query = query.eq("user_id", feed.user_id);
  }

  const { data: todos, error: todosError } = await query;
  if (todosError) return textResponse("Calendar items could not be loaded.", 500);

  const activeTodos = (todos ?? []).filter((todo) => !["archived", "trashed"].includes(todo.lifecycle_state));
  return new Response(buildCalendarFeed(activeTodos as TodoRecord[]), {
    headers: {
      "content-type": "text/calendar; charset=utf-8",
      "cache-control": "no-store",
      "content-disposition": "inline; filename=todo.ics",
    },
  });
});

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function buildCalendarFeed(todos: TodoRecord[]): string {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//toDō//Web Calendar//EN",
    "CALSCALE:GREGORIAN",
    "X-WR-CALNAME:toDō",
  ];

  for (const todo of todos) {
    if (!todo.due_at) continue;
    const start = new Date(todo.due_at);
    if (Number.isNaN(start.getTime())) continue;
    const end = new Date(start.getTime() + 30 * 60 * 1000);
    lines.push(
      "BEGIN:VEVENT",
      `UID:todo-${todo.id}@yourtodo.today`,
      `DTSTAMP:${icalDate(new Date())}`,
      `DTSTART:${icalDate(start)}`,
      `DTEND:${icalDate(end)}`,
      `SUMMARY:${escapeICal(todo.task || "toDō")}`,
      ...(todo.notes ? [`DESCRIPTION:${escapeICal(todo.notes)}`] : []),
      `LAST-MODIFIED:${icalDate(todo.updated_at ? new Date(todo.updated_at) : start)}`,
      "STATUS:CONFIRMED",
      "END:VEVENT",
    );
  }

  lines.push("END:VCALENDAR");
  return `${lines.join("\r\n")}\r\n`;
}

function icalDate(value: Date): string {
  return value.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}

function escapeICal(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/\r?\n/g, "\\n").replace(/;/g, "\\;").replace(/,/g, "\\,");
}

function textResponse(body: string, status: number): Response {
  return new Response(body, { status, headers: { "content-type": "text/plain; charset=utf-8" } });
}
