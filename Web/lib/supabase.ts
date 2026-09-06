import {
  createClient,
  type Provider,
  type Session,
  type SupabaseClient,
} from "@supabase/supabase-js";

const supabaseURL = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const supabasePublishableKey = import.meta.env
  .VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;

export const supabaseConfiguration = {
  url: supabaseURL ?? "",
  publishableKey: supabasePublishableKey ?? "",
};

export const supabaseConfigured = Boolean(supabaseURL && supabasePublishableKey);

export const supabaseConfigurationIssue = !supabaseConfigured
  ? "Add VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY to Web/.env.local to connect local testing to Supabase."
  : null;

export const supabase: SupabaseClient | null = supabaseConfigured
  ? createClient(supabaseURL!, supabasePublishableKey!, {
      auth: {
        autoRefreshToken: true,
        detectSessionInUrl: true,
        persistSession: true,
        experimental: {
          passkey: true,
        },
      },
    })
  : null;

export type WebProvider = Extract<Provider, "apple" | "google">;
export type WebSession = Session;
