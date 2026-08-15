"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import type { User } from "@supabase/supabase-js";
import {
  supabase,
  supabaseConfigurationIssue,
  type WebProvider,
  type WebSession,
} from "@/lib/supabase";

type AuthContextValue = {
  user: User | null;
  session: WebSession | null;
  profileUsername: string | null;
  profileAvatarURL: string | null;
  accountSetupVersion: number | null;
  resolutionState: AccountResolutionState;
  isResolved: boolean;
  isLoading: boolean;
  isConfigured: boolean;
  error: string | null;
  signIn: (
    provider: WebProvider,
    intent: AccountAuthenticationIntent,
    expectedUsername: string,
  ) => Promise<void>;
  completeAccountSetup: (username: string) => Promise<boolean>;
  continueWithAuthenticatedAccount: () => Promise<boolean>;
  connectProvider: (provider: WebProvider) => Promise<void>;
  signOut: () => Promise<void>;
};

export type AccountAuthenticationIntent = "createAccount" | "signIn" | "restoreSession";
export type AccountResolutionState =
  | "signedOut"
  | "resolving"
  | "needsUsername"
  | "migrationRequired"
  | "accountMismatch"
  | "resolved";

type ProfileResolutionRecord = {
  id: string;
  username: string | null;
  avatar_url: string | null;
  account_setup_version: number | null;
};

const AuthContext = createContext<AuthContextValue | null>(null);
const pendingLinkAccountStorageKey = "todo.pendingLinkAccountID";

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<WebSession | null>(null);
  const [profile, setProfile] = useState<ProfileResolutionRecord | null>(null);
  const [resolutionState, setResolutionState] = useState<AccountResolutionState>("signedOut");
  const [isLoading, setIsLoading] = useState(Boolean(supabase));
  const [error, setError] = useState<string | null>(null);
  const pendingIntent = useRef<AccountAuthenticationIntent>("restoreSession");
  const pendingExpectedUsername = useRef<string | null>(null);
  const pendingLinkAccountID = useRef<string | null>(null);

  const resolveSession = useCallback(
    async (
      nextSession: WebSession | null,
      intent: AccountAuthenticationIntent = "restoreSession",
      expectedUsername: string | null = null,
    ) => {
      if (!nextSession || !supabase) {
        setProfile(null);
        setResolutionState("signedOut");
        setIsLoading(false);
        return;
      }

      const expectedLinkAccountID = pendingLinkAccountID.current;
      if (expectedLinkAccountID && nextSession.user.id !== expectedLinkAccountID) {
        // A provider-link callback must never replace the account that started
        // the link. Sign out the unexpected session instead of exposing its
        // data or allowing it to enter the resolved sync path.
        pendingLinkAccountID.current = null;
        if (typeof window !== "undefined") {
          window.sessionStorage.removeItem(pendingLinkAccountStorageKey);
        }
        //await supabase.auth.signOut();
        await supabase.auth.signOut({ scope: "local" });
        setSession(null);
        setProfile(null);
        setResolutionState("accountMismatch");
        setError("That sign-in method belongs to another toDō account. Nothing was linked.");
        setIsLoading(false);
        return;
      }
      if (expectedLinkAccountID) {
        pendingLinkAccountID.current = null;
        if (typeof window !== "undefined") {
          window.sessionStorage.removeItem(pendingLinkAccountStorageKey);
        }
      }

      setResolutionState("resolving");
      setProfile(null);

      const { data, error: profileError } = await supabase
        .from("profiles")
        .select("id, username, avatar_url, account_setup_version")
        .eq("id", nextSession.user.id)
        .maybeSingle<ProfileResolutionRecord>();

      if (profileError) {
        setResolutionState("needsUsername");
        setError(profileError.message);
        setIsLoading(false);
        return;
      }

      let resolvedProfile = data;
      if ((!resolvedProfile || !resolvedProfile.username) && intent === "createAccount" && expectedUsername) {
        const { error: claimError } = await supabase.rpc("claim_account_username", {
          requested_username: expectedUsername,
        });
        if (!claimError) {
          const refreshed = await supabase
            .from("profiles")
            .select("id, username, avatar_url, account_setup_version")
            .eq("id", nextSession.user.id)
            .maybeSingle<ProfileResolutionRecord>();
          resolvedProfile = refreshed.data;
          if (refreshed.error) setError(refreshed.error.message);
        } else {
          setError(claimError.message);
        }
      }

      if (!resolvedProfile?.username) {
        setResolutionState("needsUsername");
        setIsLoading(false);
        return;
      }

      setProfile(resolvedProfile);
      if ((resolvedProfile.account_setup_version ?? 1) < 2) {
        setResolutionState("migrationRequired");
        setIsLoading(false);
        return;
      }

      const normalizedExpected = normalizeUsername(expectedUsername);
      const normalizedActual = normalizeUsername(resolvedProfile.username);
      if (
        normalizedExpected &&
        normalizedActual &&
        normalizedExpected !== normalizedActual &&
        (intent === "signIn" || intent === "createAccount")
      ) {
        setResolutionState("accountMismatch");
        setIsLoading(false);
        return;
      }

      setResolutionState("resolved");
      setError(null);
      setIsLoading(false);
    },
    [],
  );

  useEffect(() => {
    if (!supabase) {
      return;
    }

    let isMounted = true;
    const authClient = supabase;
    pendingLinkAccountID.current =
      typeof window === "undefined"
        ? null
        : window.sessionStorage.getItem(pendingLinkAccountStorageKey);

    void authClient.auth.getSession().then(({ data, error: sessionError }) => {
      if (!isMounted) return;
      if (sessionError) setError(sessionError.message);
      setSession(data.session);
      void resolveSession(data.session, "restoreSession", null);
    });

    const {
      data: { subscription },
    } = authClient.auth.onAuthStateChange((event, nextSession) => {
      if (!isMounted) return;
      setSession(nextSession);
      if (event === "SIGNED_IN" || event === "SIGNED_OUT") {
        setError(null);
      }
      // Supabase invokes this callback from its auth lock. Resolve outside the
      // callback so the profile query cannot deadlock a later auth operation.
      void Promise.resolve().then(() =>
        resolveSession(
          nextSession,
          pendingIntent.current,
          pendingExpectedUsername.current,
        ),
      );
    });

    return () => {
      isMounted = false;
      subscription.unsubscribe();
    };
  }, [resolveSession]);

  const signIn = useCallback(async (
    provider: WebProvider,
    intent: AccountAuthenticationIntent,
    expectedUsername: string,
  ) => {
    if (!supabase) {
      setError(supabaseConfigurationIssue);
      return;
    }

    pendingIntent.current = intent;
    pendingExpectedUsername.current = normalizeUsername(expectedUsername);
    setError(null);
    setIsLoading(true);
    const { error: signInError } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo:
          typeof window === "undefined"
            ? undefined
            : `${window.location.origin}/`,
      },
    });

    if (signInError) {
      setError(signInError.message);
      setIsLoading(false);
    }
  }, []);

  const completeAccountSetup = useCallback(async (username: string) => {
    if (!supabase || !session) return false;
    const normalized = normalizeUsername(username);
    if (!normalized) {
      setError("Use 3–30 lowercase letters, numbers, periods, or underscores.");
      return false;
    }

    setIsLoading(true);
    const { error: claimError } = await supabase.rpc("claim_account_username", {
      requested_username: normalized,
    });
    if (claimError) {
      setError(claimError.message);
      setIsLoading(false);
      return false;
    }

    pendingIntent.current = "restoreSession";
    pendingExpectedUsername.current = normalized;
    await resolveSession(session, "restoreSession", normalized);
    return true;
  }, [resolveSession, session]);

  const continueWithAuthenticatedAccount = useCallback(async () => {
    if (!session || !profile?.username) return false;
    pendingIntent.current = "restoreSession";
    pendingExpectedUsername.current = profile.username;
    await resolveSession(session, "restoreSession", profile.username);
    return true;
  }, [profile, resolveSession, session]);

  const connectProvider = useCallback(async (provider: WebProvider) => {
    if (!supabase || resolutionState !== "resolved" || !session?.user.id) {
      setError("Resolve your toDō account before connecting another sign-in method.");
      return;
    }

    pendingLinkAccountID.current = session.user.id;
    if (typeof window !== "undefined") {
      window.sessionStorage.setItem(pendingLinkAccountStorageKey, session.user.id);
    }

    const { error: linkError } = await supabase.auth.linkIdentity({
      provider,
      options: {
        redirectTo:
          typeof window === "undefined"
            ? undefined
            : `${window.location.origin}/`,
      },
    });
    if (linkError) {
      pendingLinkAccountID.current = null;
      if (typeof window !== "undefined") {
        window.sessionStorage.removeItem(pendingLinkAccountStorageKey);
      }
      setError(linkError.message);
    }
  }, [resolutionState, session]);

  const signOut = useCallback(async () => {
    if (!supabase) return;
    const { error: signOutError } = await supabase.auth.signOut({
      scope: "local",
    });
    if (signOutError && signOutError.code !== "session_not_found") {
      setError(signOutError.message);
      return;
    }
    setProfile(null);
    setResolutionState("signedOut");
    pendingIntent.current = "restoreSession";
    pendingExpectedUsername.current = null;
    pendingLinkAccountID.current = null;
    if (typeof window !== "undefined") {
      window.sessionStorage.removeItem(pendingLinkAccountStorageKey);
    }
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user: session?.user ?? null,
      session,
      profileUsername: profile?.username ?? null,
      profileAvatarURL:
        profile?.avatar_url ??
        (session?.user.user_metadata?.avatar_url as string | undefined) ??
        (session?.user.user_metadata?.picture as string | undefined) ??
        null,
      accountSetupVersion: profile?.account_setup_version ?? null,
      resolutionState,
      isResolved: resolutionState === "resolved",
      isLoading,
      isConfigured: Boolean(supabase),
      error: error ?? supabaseConfigurationIssue,
      signIn,
      completeAccountSetup,
      continueWithAuthenticatedAccount,
      connectProvider,
      signOut,
    }),
    [
      completeAccountSetup,
      connectProvider,
      continueWithAuthenticatedAccount,
      error,
      isLoading,
      profile?.account_setup_version,
      profile?.avatar_url,
      profile?.username,
      resolutionState,
      session,
      signIn,
      signOut,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

function normalizeUsername(value: string | null | undefined): string | null {
  const normalized = value?.trim().replace(/^@/, "").toLowerCase() ?? "";
  if (!/^[a-z0-9._]{3,30}$/.test(normalized)) return null;
  if (normalized.startsWith(".") || normalized.endsWith(".")) return null;
  return normalized;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return context;
}
