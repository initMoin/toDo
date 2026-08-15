import { supabase, supabaseConfiguration } from "@/lib/supabase";

export type WebNotificationPreferencePatch = {
  web_reminders_enabled?: boolean;
  web_reminder_sound?: string;
  web_custom_sound_name?: string | null;
  web_completion_sound?: string;
  web_badge_policy?: string;
  web_snooze_options?: { minutes: number[]; hours: number[]; days: number[] };
};

export type WebNotificationPreferences = WebNotificationPreferencePatch & {
  web_reminders_enabled: boolean;
  web_reminder_sound: string;
  web_custom_sound_name: string | null;
  web_completion_sound: string;
  web_badge_policy: string;
  web_snooze_options: { minutes: number[]; hours: number[]; days: number[] };
};

export async function loadWebNotificationPreferences(userID: string): Promise<WebNotificationPreferences | null> {
  if (!supabase) throw new Error("Supabase is not configured for this local Web build.");
  const { data, error } = await supabase
    .from("notification_preferences")
    .select("web_reminders_enabled,web_reminder_sound,web_custom_sound_name,web_completion_sound,web_badge_policy,web_snooze_options")
    .eq("user_id", userID)
    .maybeSingle();
  if (error) throw error;
  return data as WebNotificationPreferences | null;
}

export async function saveWebNotificationPreferences(
  userID: string,
  patch: WebNotificationPreferencePatch,
): Promise<void> {
  if (!supabase) throw new Error("Supabase is not configured for this local Web build.");
  const { error } = await supabase
    .from("notification_preferences")
    .upsert({ user_id: userID, ...patch }, { onConflict: "user_id" });
  if (error) throw error;
}

export async function registerWebPushSubscription(userID: string): Promise<void> {
  if (!supabase) throw new Error("Supabase is not configured for this local Web build.");
  if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
    throw new Error("This browser does not support background Web Push.");
  }

  const vapidPublicKey = import.meta.env.VITE_WEB_PUSH_VAPID_PUBLIC_KEY as string | undefined;
  if (!vapidPublicKey) {
    throw new Error("Web Push is not configured for this Web build yet.");
  }

  const registration = await navigator.serviceWorker.register("/sw.js", { scope: "/" });
  const readyRegistration = await navigator.serviceWorker.ready;
  let subscription = await readyRegistration.pushManager.getSubscription();
  if (!subscription) {
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: decodeBase64URL(vapidPublicKey),
    });
  }

  const { error } = await supabase
    .from("web_push_subscriptions")
    .upsert({
      user_id: userID,
      endpoint: subscription.endpoint,
      p256dh: encodeBase64URL(subscription.getKey("p256dh")),
      auth: encodeBase64URL(subscription.getKey("auth")),
      expiration_time: subscription.expirationTime,
      user_agent: navigator.userAgent,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC",
      is_active: true,
      last_seen_at: new Date().toISOString(),
    }, { onConflict: "user_id,endpoint" });
  if (error) throw error;
}

export async function createCalendarFeedURL(): Promise<string> {
  if (!supabase) throw new Error("Supabase is not configured for this local Web build.");
  const { data, error } = await supabase.rpc("create_web_calendar_feed_token");
  if (error) throw error;
  if (typeof data !== "string" || !data) throw new Error("The calendar feed could not be created.");
  return `${supabaseConfiguration.url}/functions/v1/todo-calendar-feed?token=${encodeURIComponent(data)}`;
}

export async function revokeCalendarFeed(): Promise<void> {
  if (!supabase) throw new Error("Supabase is not configured for this local Web build.");
  const { error } = await supabase.rpc("revoke_web_calendar_feed");
  if (error) throw error;
}

function decodeBase64URL(value: string): Uint8Array {
  const padding = "=".repeat((4 - (value.length % 4)) % 4);
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/") + padding;
  const raw = window.atob(base64);
  return Uint8Array.from(raw, (character) => character.charCodeAt(0));
}

function encodeBase64URL(value: ArrayBuffer | null): string {
  if (!value) throw new Error("The browser did not return a Web Push encryption key.");
  const bytes = new Uint8Array(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return window.btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
