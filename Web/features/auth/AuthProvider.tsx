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
  saveProfileImage: (image: Blob) => Promise<boolean>;
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
const pendingAuthenticationStorageKey = "todo.pendingAuthentication";
const AUTH_REQUEST_TIMEOUT_MS = 8000;

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
        clearPendingLinkAccount();
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
        clearPendingLinkAccount();
      }

      setResolutionState("resolving");
      setProfile(null);

      let profileResult: {
        data: ProfileResolutionRecord | null;
        error: { message: string } | null;
      };
      try {
        profileResult = await withTimeout(
          supabase
            .from("profiles")
            .select("id, username, avatar_url, account_setup_version")
            .eq("id", nextSession.user.id)
            .maybeSingle<ProfileResolutionRecord>(),
          "Your toDō profile could not be loaded in time.",
        );
      } catch (profileLoadError) {
        setError(getErrorMessage(profileLoadError, "Your toDō profile could not be loaded."));
        setIsLoading(false);
        return;
      }

      const { data, error: profileError } = profileResult;

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
      clearPendingAuthentication();
      pendingIntent.current = "restoreSession";
      pendingExpectedUsername.current = null;
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
    const pendingAuthentication = readPendingAuthentication();
    pendingIntent.current = pendingAuthentication?.intent ?? "restoreSession";
    pendingExpectedUsername.current = pendingAuthentication?.expectedUsername ?? null;
    const callbackError = readAuthCallbackError();
    if (callbackError) {
      clearPendingAuthentication();
    }

    let hasInitialSession = false;
    const initializationTimeout = setTimeout(() => {
      if (!isMounted || hasInitialSession) return;
      setSession(null);
      setProfile(null);
      setResolutionState("signedOut");
      setError(null);
      setIsLoading(false);
    }, AUTH_REQUEST_TIMEOUT_MS);

    const {
      data: { subscription },
    } = authClient.auth.onAuthStateChange((event, nextSession) => {
      if (!isMounted) return;
      if (event === "INITIAL_SESSION") {
        hasInitialSession = true;
        clearTimeout(initializationTimeout);
      }
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

    // The auth client initializes as soon as it is created. Calling initialize
    // again here is safe and gives us the callback error/session result even
    // when the initial auth event was emitted before this component subscribed.
    void authClient.auth.initialize().then(({ error: initializationError }) => {
      if (!isMounted) return;
      if (callbackError || initializationError) {
        setSession(null);
        setProfile(null);
        setResolutionState("signedOut");
        setError(
          callbackError
            ?? `Sign-in could not be completed: ${initializationError.message}`,
        );
        setIsLoading(false);
        return;
      }

      void authClient.auth.getSession().then(({ data, error: sessionError }) => {
        if (!isMounted) return;
        if (sessionError) {
          setError(`Sign-in session could not be restored: ${sessionError.message}`);
          setIsLoading(false);
          return;
        }
        if (!data.session) return;
        setSession(data.session);
        void resolveSession(
          data.session,
          pendingIntent.current,
          pendingExpectedUsername.current,
        );
      });
    }).catch((initializationError: unknown) => {
      if (!isMounted) return;
      setError(`Sign-in could not be completed: ${getErrorMessage(initializationError, "The callback could not be processed.")}`);
      setIsLoading(false);
    });

    return () => {
      isMounted = false;
      clearTimeout(initializationTimeout);
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

    pendingLinkAccountID.current = null;
    clearPendingLinkAccount();
    pendingIntent.current = intent;
    pendingExpectedUsername.current = normalizeUsername(expectedUsername);
    writePendingAuthentication(intent, pendingExpectedUsername.current);
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
      clearPendingAuthentication();
      pendingIntent.current = "restoreSession";
      pendingExpectedUsername.current = null;
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
    clearPendingAuthentication();
    await resolveSession(session, "restoreSession", normalized);
    return true;
  }, [resolveSession, session]);

  const continueWithAuthenticatedAccount = useCallback(async () => {
    if (!session || !profile?.username) return false;
    pendingIntent.current = "restoreSession";
    pendingExpectedUsername.current = profile.username;
    clearPendingAuthentication();
    await resolveSession(session, "restoreSession", profile.username);
    return true;
  }, [profile, resolveSession, session]);

  const saveProfileImage = useCallback(async (image: Blob) => {
    if (!supabase || !session?.user.id || resolutionState !== "resolved") {
      setError("Sign in to edit your profile.");
      return false;
    }

    const userID = session.user.id;
    const imagePath = `${userID.toLowerCase()}/avatar.jpg`;
    const { error: uploadError } = await supabase.storage
      .from("profile-images")
      .upload(imagePath, image, {
        cacheControl: "3600",
        contentType: "image/jpeg",
        upsert: true,
      });
    if (uploadError) {
      setError(uploadError.message);
      return false;
    }

    const { data: publicURL } = supabase.storage
      .from("profile-images")
      .getPublicUrl(imagePath);
    const avatarURL = `${publicURL.publicUrl}?v=${Date.now()}`;
    const { data: updatedProfile, error: profileError } = await supabase
      .from("profiles")
      .update({ avatar_url: avatarURL })
      .eq("id", userID)
      .select("id, username, avatar_url, account_setup_version")
      .single<ProfileResolutionRecord>();
    if (profileError || !updatedProfile) {
      setError(profileError?.message ?? "Your profile image could not be saved.");
      return false;
    }

    setProfile(updatedProfile);
    setError(null);
    return true;
  }, [resolutionState, session]);

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
      clearPendingLinkAccount();
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
    clearPendingLinkAccount();
    clearPendingAuthentication();
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user: session?.user ?? null,
      session,
      profileUsername: profile?.username ?? null,
      profileAvatarURL: profile?.avatar_url ?? null,
      accountSetupVersion: profile?.account_setup_version ?? null,
      resolutionState,
      isResolved: resolutionState === "resolved",
      isLoading,
      isConfigured: Boolean(supabase),
      error: error ?? supabaseConfigurationIssue,
      signIn,
      completeAccountSetup,
      continueWithAuthenticatedAccount,
      saveProfileImage,
      connectProvider,
      signOut,
    }),
    [
      completeAccountSetup,
      connectProvider,
      continueWithAuthenticatedAccount,
      error,
      isLoading,
      profile,
      resolutionState,
      saveProfileImage,
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

function readPendingAuthentication(): {
  intent: "signIn" | "createAccount";
  expectedUsername: string | null;
} | null {
  if (typeof window === "undefined") return null;
  try {
    const value = window.sessionStorage.getItem(pendingAuthenticationStorageKey);
    if (!value) return null;
    const parsed = JSON.parse(value) as {
      intent?: unknown;
      expectedUsername?: unknown;
    };
    if (parsed.intent !== "signIn" && parsed.intent !== "createAccount") return null;
    return {
      intent: parsed.intent,
      expectedUsername:
        typeof parsed.expectedUsername === "string"
          ? normalizeUsername(parsed.expectedUsername)
          : null,
    };
  } catch {
    return null;
  }
}

function writePendingAuthentication(
  intent: AccountAuthenticationIntent,
  expectedUsername: string | null,
) {
  if (typeof window === "undefined" || intent === "restoreSession") return;
  try {
    window.sessionStorage.setItem(
      pendingAuthenticationStorageKey,
      JSON.stringify({ intent, expectedUsername }),
    );
  } catch {
    // OAuth can still proceed when session storage is unavailable.
  }
}

function clearPendingAuthentication() {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.removeItem(pendingAuthenticationStorageKey);
  } catch {
    // Ignore storage cleanup failures; the authenticated session is primary.
  }
}

function clearPendingLinkAccount() {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.removeItem(pendingLinkAccountStorageKey);
  } catch {
    // Ignore storage cleanup failures; the fresh sign-in can continue.
  }
}

function readAuthCallbackError() {
  if (typeof window === "undefined") return null;
  const search = new URLSearchParams(window.location.search);
  const hash = new URLSearchParams(window.location.hash.replace(/^#/, ""));
  const error = search.get("error") ?? hash.get("error");
  if (!error) return null;
  const description = search.get("error_description") ?? hash.get("error_description");
  return `Sign-in could not be completed: ${description ?? error}`;
}

function withTimeout<T>(promise: PromiseLike<T>, message: string): Promise<T> {
  return Promise.race([
    Promise.resolve(promise),
    new Promise<T>((_, reject) => {
      setTimeout(() => reject(new Error(message)), AUTH_REQUEST_TIMEOUT_MS);
    }),
  ]);
}

function getErrorMessage(error: unknown, fallback: string) {
  if (error instanceof Error) return error.message;
  if (typeof error === "object" && error !== null && "message" in error && typeof error.message === "string") {
    return error.message;
  }
  return fallback;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return context;
}
