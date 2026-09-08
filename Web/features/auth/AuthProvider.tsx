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
import {
  isRecentVerification,
  latestSecondFactorTimestamp,
} from "@/lib/authAssurance";
import { hasWebPlusAccess, loadEntitlements } from "@/features/todos/data";

type AuthContextValue = {
  user: User | null;
  session: WebSession | null;
  profileUsername: string | null;
  profileAvatarURL: string | null;
  accountSetupVersion: number | null;
  mfaFactors: WebMFAFactor[];
  mfaAssuranceLevel: "aal1" | "aal2" | null;
  resolutionState: AccountResolutionState;
  isResolved: boolean;
  webAccessState: WebAccessState;
  isLoading: boolean;
  isConfigured: boolean;
  error: string | null;
  signIn: (
    provider: WebProvider,
    intent: AccountAuthenticationIntent,
    expectedUsername: string,
  ) => Promise<void>;
  requestEmailCode: (
    intent: "createAccount" | "signIn",
    expectedUsername: string,
    email: string,
  ) => Promise<boolean>;
  verifyEmailCode: (
    intent: "createAccount" | "signIn",
    expectedUsername: string,
    email: string,
    code: string,
  ) => Promise<boolean>;
  signInWithPassword: (
    expectedUsername: string,
    email: string,
    password: string,
  ) => Promise<boolean>;
  setPassword: (password: string, nonce?: string) => Promise<PasswordUpdateResult>;
  signInWithPasskey: (expectedUsername: string) => Promise<boolean>;
  registerPasskey: () => Promise<boolean>;
  enrollTOTP: () => Promise<WebTOTPEnrollment | null>;
  verifyMFA: (factorID: string, code: string) => Promise<boolean>;
  unenrollMFA: (factorID: string) => Promise<boolean>;
  requireAAL2: (action: string, requireEnrollment?: boolean) => Promise<boolean>;
  completeAccountSetup: (username: string) => Promise<boolean>;
  continueWithAuthenticatedAccount: () => Promise<boolean>;
  saveProfileImage: (image: Blob) => Promise<boolean>;
  connectProvider: (provider: WebProvider) => Promise<void>;
  signOut: () => Promise<void>;
};

export type AccountAuthenticationIntent = "createAccount" | "signIn" | "restoreSession";
export type WebAccessState = "unknown" | "checking" | "granted" | "denied" | "error";
export type AccountResolutionState =
  | "signedOut"
  | "resolving"
  | "needsUsername"
  | "migrationRequired"
  | "mfaRequired"
  | "accountMismatch"
  | "resolved";

export type WebMFAFactor = {
  id: string;
  friendlyName: string | null;
  status: "verified";
};

export type WebTOTPEnrollment = {
  factorID: string;
  secret: string;
  qrCode: string;
  uri: string;
};

export type PasswordUpdateResult = "saved" | "verificationRequired" | "failed";

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
  const [mfaFactors, setMfaFactors] = useState<WebMFAFactor[]>([]);
  const [mfaAssuranceLevel, setMfaAssuranceLevel] = useState<"aal1" | "aal2" | null>(null);
  const [webAccessState, setWebAccessState] = useState<WebAccessState>("unknown");
  const [isLoading, setIsLoading] = useState(Boolean(supabase));
  const [error, setError] = useState<string | null>(null);
  const pendingIntent = useRef<AccountAuthenticationIntent>("restoreSession");
  const pendingExpectedUsername = useRef<string | null>(null);
  const pendingLinkAccountID = useRef<string | null>(null);
  const resolutionRequestID = useRef(0);

  const refreshMFAState = useCallback(async () => {
    if (!supabase) {
      return { factors: [] as WebMFAFactor[], currentLevel: null, nextLevel: null, verifiedAt: null };
    }

    const [factorResult, assuranceResult] = await Promise.all([
      withTimeout(
        supabase.auth.mfa.listFactors(),
        "Your authentication factors could not be loaded in time.",
      ),
      withTimeout(
        supabase.auth.mfa.getAuthenticatorAssuranceLevel(),
        "Your authentication level could not be checked in time.",
      ),
    ]);
    if (factorResult.error) throw factorResult.error;
    if (assuranceResult.error) throw assuranceResult.error;

    const factors = factorResult.data.totp.map((factor) => ({
      id: factor.id,
      friendlyName: factor.friendly_name ?? null,
      status: "verified" as const,
    }));
    const currentLevel = assuranceResult.data.currentLevel === "aal2" ? "aal2" : "aal1";
    const nextLevel = assuranceResult.data.nextLevel === "aal2" ? "aal2" : "aal1";
    const verifiedAt = latestSecondFactorTimestamp(
      assuranceResult.data.currentAuthenticationMethods,
    );
    setMfaFactors(factors);
    setMfaAssuranceLevel(currentLevel);
    return { factors, currentLevel, nextLevel, verifiedAt };
  }, []);

  const refreshWebAccess = useCallback(async (): Promise<WebAccessState> => {
    if (!supabase) {
      setWebAccessState("error");
      return "error";
    }

    setWebAccessState("checking");
    try {
      const entitlements = await loadEntitlements();
      const nextState: WebAccessState = hasWebPlusAccess(entitlements) ? "granted" : "denied";
      setWebAccessState(nextState);
      return nextState;
    } catch {
      setWebAccessState("error");
      return "error";
    }
  }, []);

  const resolveSession = useCallback(
    async (
      nextSession: WebSession | null,
      intent: AccountAuthenticationIntent = "restoreSession",
      expectedUsername: string | null = null,
    ) => {
      const requestID = ++resolutionRequestID.current;
      if (!nextSession || !supabase) {
        setProfile(null);
        setMfaFactors([]);
        setMfaAssuranceLevel(null);
        setWebAccessState("unknown");
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

      try {
        const mfaState = await refreshMFAState();
        if (requestID !== resolutionRequestID.current) return;
        if (
          mfaState.factors.length > 0 &&
          mfaState.currentLevel !== "aal2" &&
          mfaState.nextLevel === "aal2"
        ) {
          setResolutionState("mfaRequired");
          setError(null);
          setIsLoading(false);
          return;
        }
      } catch (mfaError) {
        if (requestID !== resolutionRequestID.current) return;
        setResolutionState("mfaRequired");
        setError(getErrorMessage(mfaError, "Your account security could not be checked."));
        setIsLoading(false);
        return;
      }

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

      if (requestID !== resolutionRequestID.current) return;

      if (profileError) {
        setWebAccessState("unknown");
        setResolutionState("needsUsername");
        setError(profileError.message);
        setIsLoading(false);
        return;
      }

      let resolvedProfile = data;
      if ((!resolvedProfile || !resolvedProfile.username) && intent === "createAccount" && expectedUsername) {
        try {
          const { error: claimError } = await withTimeout(
            supabase.rpc("claim_account_username", {
              requested_username: expectedUsername,
            }),
            "Your username could not be claimed in time.",
          );
          if (!claimError) {
            const refreshed = await withTimeout(
              supabase
                .from("profiles")
                .select("id, username, avatar_url, account_setup_version")
                .eq("id", nextSession.user.id)
                .maybeSingle<ProfileResolutionRecord>(),
              "Your toDō profile could not be refreshed in time.",
            );
            if (requestID !== resolutionRequestID.current) return;
            resolvedProfile = refreshed.data;
            if (refreshed.error) setError(refreshed.error.message);
          } else {
            setError(claimError.message);
          }
        } catch (claimError) {
          if (requestID !== resolutionRequestID.current) return;
          setError(getErrorMessage(claimError, "Your username could not be claimed."));
        }
      }

      if (requestID !== resolutionRequestID.current) return;

      if (!resolvedProfile?.username) {
        setWebAccessState("unknown");
        setResolutionState("needsUsername");
        setIsLoading(false);
        return;
      }

      setProfile(resolvedProfile);
      if ((resolvedProfile.account_setup_version ?? 1) < 2) {
        setWebAccessState("unknown");
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
        clearPendingAuthentication();
        pendingIntent.current = "restoreSession";
        pendingExpectedUsername.current = null;
        setWebAccessState("unknown");
        setResolutionState("accountMismatch");
        setError("This provider is connected to a different toDō username. Nothing was linked or moved.");
        setIsLoading(false);
        return;
      }

      await refreshWebAccess();
      if (requestID !== resolutionRequestID.current) return;

      setResolutionState("resolved");
      setError(null);
      clearPendingAuthentication();
      pendingIntent.current = "restoreSession";
      pendingExpectedUsername.current = null;
      setIsLoading(false);
    },
    [refreshMFAState, refreshWebAccess],
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

    let initialSessionSettled = false;
    const initializationTimeout = setTimeout(() => {
      if (!isMounted || initialSessionSettled) return;
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
        // The initial read below is the single source of truth for the first
        // render. Supabase can emit INITIAL_SESSION before or after this
        // subscriber is attached, so resolving it here would race getSession.
        return;
      }
      setSession(nextSession);
      if (event === "SIGNED_IN" || event === "SIGNED_OUT") {
        setError(null);
      }
      if (event === "SIGNED_OUT") {
        void resolveSession(null);
        return;
      }
      if (event === "SIGNED_IN" || event === "USER_UPDATED" || event === "MFA_CHALLENGE_VERIFIED") {
        // Supabase invokes this callback from its auth lock. Resolve outside
        // the callback so the profile query cannot deadlock a later operation.
        void Promise.resolve().then(() =>
          resolveSession(
            nextSession,
            pendingIntent.current,
            pendingExpectedUsername.current,
          ),
        );
      }
    });

    void authClient.auth.getSession().then(({ data, error: sessionError }) => {
      if (!isMounted) return;
      initialSessionSettled = true;
      clearTimeout(initializationTimeout);
      if (callbackError) {
        setSession(null);
        setProfile(null);
        setResolutionState("signedOut");
        setError(callbackError);
        setIsLoading(false);
        return;
      }
      if (sessionError) {
        setSession(null);
        setProfile(null);
        setResolutionState("signedOut");
        setError(`Sign-in session could not be restored: ${sessionError.message}`);
        setIsLoading(false);
        return;
      }
      setSession(data.session);
      void resolveSession(
        data.session,
        pendingIntent.current,
        pendingExpectedUsername.current,
      );
    }).catch((sessionError: unknown) => {
      if (!isMounted) return;
      initialSessionSettled = true;
      clearTimeout(initializationTimeout);
      setError(`Sign-in session could not be restored: ${getErrorMessage(sessionError, "The session could not be read.")}`);
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

  const requestEmailCode = useCallback(async (
    intent: "createAccount" | "signIn",
    expectedUsername: string,
    email: string,
  ) => {
    if (!supabase) {
      setError(supabaseConfigurationIssue);
      return false;
    }

    const normalizedEmail = normalizeEmail(email);
    const normalizedUsername = normalizeUsername(expectedUsername);
    if (!normalizedUsername) {
      setError("Enter a valid username first.");
      return false;
    }
    if (!normalizedEmail) {
      setError("Enter a valid email address.");
      return false;
    }

    pendingIntent.current = intent;
    pendingExpectedUsername.current = normalizedUsername;
    writePendingAuthentication(intent, normalizedUsername, normalizedEmail);
    setError(null);
    setIsLoading(true);

    const { error: otpError } = await supabase.auth.signInWithOtp({
      email: normalizedEmail,
      options: {
        shouldCreateUser: intent === "createAccount",
        emailRedirectTo:
          typeof window === "undefined"
            ? undefined
            : `${window.location.origin}/`,
      },
    });

    if (otpError) {
      setError(otpError.message);
      setIsLoading(false);
      return false;
    }

    setIsLoading(false);
    return true;
  }, []);

  const verifyEmailCode = useCallback(async (
    intent: "createAccount" | "signIn",
    expectedUsername: string,
    email: string,
    code: string,
  ) => {
    if (!supabase) {
      setError(supabaseConfigurationIssue);
      return false;
    }

    const normalizedEmail = normalizeEmail(email);
    const normalizedUsername = normalizeUsername(expectedUsername);
    const normalizedCode = code.trim();
    if (!normalizedUsername || !normalizedEmail || !/^\d{6}$/.test(normalizedCode)) {
      setError("Enter the six-digit code from your email.");
      return false;
    }

    setError(null);
    setIsLoading(true);
    const { data, error: verifyError } = await supabase.auth.verifyOtp({
      email: normalizedEmail,
      token: normalizedCode,
      type: "email",
    });
    if (verifyError || !data.session) {
      setError(verifyError?.message ?? "That verification code could not be accepted.");
      setIsLoading(false);
      return false;
    }

    pendingIntent.current = intent;
    pendingExpectedUsername.current = normalizedUsername;
    setSession(data.session);
    await resolveSession(data.session, intent, normalizedUsername);
    return resolutionRequestID.current > 0 && resolutionState !== "accountMismatch";
  }, [resolutionState, resolveSession]);

  const signInWithPassword = useCallback(async (
    expectedUsername: string,
    email: string,
    password: string,
  ) => {
    if (!supabase) {
      setError(supabaseConfigurationIssue);
      return false;
    }

    const normalizedEmail = normalizeEmail(email);
    const normalizedUsername = normalizeUsername(expectedUsername);
    if (!normalizedUsername || !normalizedEmail || !password) {
      setError("Enter your username, email, and password.");
      return false;
    }

    pendingIntent.current = "signIn";
    pendingExpectedUsername.current = normalizedUsername;
    writePendingAuthentication("signIn", normalizedUsername, normalizedEmail);
    setError(null);
    setIsLoading(true);
    const { data, error: passwordError } = await supabase.auth.signInWithPassword({
      email: normalizedEmail,
      password,
    });
    if (passwordError || !data.session) {
      setError(passwordError?.message ?? "That email or password could not be accepted.");
      setIsLoading(false);
      return false;
    }

    setSession(data.session);
    await resolveSession(data.session, "signIn", normalizedUsername);
    return true;
  }, [resolveSession]);

  const requireAAL2 = useCallback(async (
    action: string,
    requireEnrollment = false,
  ) => {
    if (!supabase || !session) {
      setError("Sign in before continuing.");
      return false;
    }

    setError(null);
    setIsLoading(true);
    try {
      const mfaState = await refreshMFAState();
      const hasRecentVerification =
        mfaState.currentLevel === "aal2" &&
        isRecentVerification(mfaState.verifiedAt, session.access_token);
      if (hasRecentVerification) return true;
      if (mfaState.factors.length === 0) {
        if (requireEnrollment) {
          setError(`Set up an authenticator app in Account before you ${action}.`);
          return false;
        }
        return true;
      }

      setResolutionState("mfaRequired");
      setError(`Verify your authenticator before you ${action}.`);
      return false;
    } catch (assuranceError) {
      setError(getErrorMessage(assuranceError, "Your account security could not be checked."));
      return false;
    } finally {
      setIsLoading(false);
    }
  }, [refreshMFAState, session]);

  const setPassword = useCallback(async (
    password: string,
    nonce?: string,
  ): Promise<PasswordUpdateResult> => {
    if (!supabase || !session || resolutionState !== "resolved") {
      setError("Finish account setup before adding a password.");
      return "failed";
    }
    if (password.length < 8) {
      setError("Use a password with at least 8 characters.");
      return "failed";
    }
    const normalizedNonce = nonce?.trim() ?? "";
    if (normalizedNonce && !/^\d{6}$/.test(normalizedNonce)) {
      setError("Enter the six-digit verification code.");
      return "failed";
    }
    if (!await requireAAL2("change your password")) return "failed";

    setError(null);
    setIsLoading(true);
    try {
      const { error: passwordError } = await supabase.auth.updateUser({
        password,
        ...(normalizedNonce ? { nonce: normalizedNonce } : {}),
      });
      if (!passwordError) return "saved";

      if (!normalizedNonce && requiresPasswordReauthentication(passwordError)) {
        const { error: reauthenticationError } = await supabase.auth.reauthenticate();
        if (reauthenticationError) {
          setError(reauthenticationError.message);
          return "failed";
        }
        setError(null);
        return "verificationRequired";
      }

      setError(passwordError.message);
      return "failed";
    } finally {
      setIsLoading(false);
    }
  }, [requireAAL2, resolutionState, session]);

  const signInWithPasskey = useCallback(async (expectedUsername: string) => {
    if (!supabase) {
      setError(supabaseConfigurationIssue);
      return false;
    }
    const normalizedUsername = normalizeUsername(expectedUsername);
    if (!normalizedUsername) {
      setError("Enter a valid username first.");
      return false;
    }

    setError(null);
    setIsLoading(true);
    const { data, error: passkeyError } = await supabase.auth.signInWithPasskey();
    if (passkeyError || !data.session) {
      setError(passkeyError?.message ?? "This passkey could not sign you in.");
      setIsLoading(false);
      return false;
    }

    pendingIntent.current = "signIn";
    pendingExpectedUsername.current = normalizedUsername;
    setSession(data.session);
    await resolveSession(data.session, "signIn", normalizedUsername);
    return true;
  }, [resolveSession]);

  const registerPasskey = useCallback(async () => {
    if (!supabase || !session || resolutionState !== "resolved") {
      setError("Finish account setup before adding a passkey.");
      return false;
    }
    if (!await requireAAL2("change your passkeys")) return false;

    setError(null);
    setIsLoading(true);
    const { error: passkeyError } = await supabase.auth.registerPasskey();
    if (passkeyError) {
      setError(passkeyError.message);
      setIsLoading(false);
      return false;
    }
    setIsLoading(false);
    return true;
  }, [requireAAL2, resolutionState, session]);

  const enrollTOTP = useCallback(async (): Promise<WebTOTPEnrollment | null> => {
    if (!supabase || !session || resolutionState !== "resolved") {
      setError("Finish account setup before adding an authenticator app.");
      return null;
    }
    if (!await requireAAL2("change multi-factor authentication")) return null;

    setError(null);
    setIsLoading(true);
    try {
      const { data, error: enrollmentError } = await supabase.auth.mfa.enroll({
        factorType: "totp",
        friendlyName: "toDō Web",
        issuer: "toDō",
      });
      if (enrollmentError) throw enrollmentError;
      return {
        factorID: data.id,
        secret: data.totp.secret,
        qrCode: data.totp.qr_code,
        uri: data.totp.uri,
      };
    } catch (enrollmentError) {
      setError(getErrorMessage(enrollmentError, "Your authenticator app could not be set up."));
      return null;
    } finally {
      setIsLoading(false);
    }
  }, [requireAAL2, resolutionState, session]);

  const verifyMFA = useCallback(async (factorID: string, code: string) => {
    if (!supabase || !session || !factorID || !/^\d{6}$/.test(code.trim())) {
      setError("Enter the six-digit code from your authenticator app.");
      return false;
    }

    setError(null);
    setIsLoading(true);
    try {
      const { error: verificationError } = await supabase.auth.mfa.challengeAndVerify({
        factorId: factorID,
        code: code.trim(),
      });
      if (verificationError) throw verificationError;
      const { data, error: sessionError } = await supabase.auth.getSession();
      if (sessionError || !data.session) {
        throw sessionError ?? new Error("The verified session could not be restored.");
      }
      setSession(data.session);
      await resolveSession(
        data.session,
        pendingIntent.current,
        pendingExpectedUsername.current,
      );
      return true;
    } catch (verificationError) {
      setError(getErrorMessage(verificationError, "That authenticator code could not be verified."));
      setIsLoading(false);
      return false;
    }
  }, [resolveSession, session]);

  const unenrollMFA = useCallback(async (factorID: string) => {
    if (!supabase || !session || resolutionState !== "resolved") return false;
    if (!await requireAAL2("change multi-factor authentication")) return false;

    setIsLoading(true);
    try {
      const { error: unenrollError } = await supabase.auth.mfa.unenroll({ factorId: factorID });
      if (unenrollError) throw unenrollError;
      await refreshMFAState();
      setError(null);
      return true;
    } catch (unenrollError) {
      setError(getErrorMessage(unenrollError, "The authenticator could not be removed."));
      return false;
    } finally {
      setIsLoading(false);
    }
  }, [refreshMFAState, requireAAL2, resolutionState, session]);

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
    if (!await requireAAL2("connect another sign-in method")) return;

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
  }, [requireAAL2, resolutionState, session]);

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
      setMfaFactors([]);
      setMfaAssuranceLevel(null);
      setWebAccessState("unknown");
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
      mfaFactors,
      mfaAssuranceLevel,
      resolutionState,
      isResolved: resolutionState === "resolved",
      webAccessState,
      isLoading,
      isConfigured: Boolean(supabase),
      error: error ?? supabaseConfigurationIssue,
      signIn,
      requestEmailCode,
      verifyEmailCode,
      signInWithPassword,
      setPassword,
      signInWithPasskey,
      registerPasskey,
      enrollTOTP,
      verifyMFA,
      unenrollMFA,
      requireAAL2,
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
      enrollTOTP,
      isLoading,
      mfaAssuranceLevel,
      mfaFactors,
      profile,
      resolutionState,
      saveProfileImage,
      session,
      webAccessState,
      signIn,
      requestEmailCode,
      verifyEmailCode,
      signInWithPassword,
      setPassword,
      signInWithPasskey,
      registerPasskey,
      requireAAL2,
      signOut,
      unenrollMFA,
      verifyMFA,
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

function normalizeEmail(value: string | null | undefined): string | null {
  const normalized = value?.trim().toLowerCase() ?? "";
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized) ? normalized : null;
}

function readPendingAuthentication(): {
  intent: "signIn" | "createAccount";
  expectedUsername: string | null;
  email: string | null;
} | null {
  if (typeof window === "undefined") return null;
  try {
    const value = window.sessionStorage.getItem(pendingAuthenticationStorageKey);
    if (!value) return null;
    const parsed = JSON.parse(value) as {
      intent?: unknown;
      expectedUsername?: unknown;
      email?: unknown;
    };
    if (parsed.intent !== "signIn" && parsed.intent !== "createAccount") return null;
    return {
      intent: parsed.intent,
      expectedUsername:
        typeof parsed.expectedUsername === "string"
          ? normalizeUsername(parsed.expectedUsername)
          : null,
      email:
        typeof parsed.email === "string"
          ? normalizeEmail(parsed.email)
          : null,
    };
  } catch {
    return null;
  }
}

function writePendingAuthentication(
  intent: AccountAuthenticationIntent,
  expectedUsername: string | null,
  email: string | null = null,
) {
  if (typeof window === "undefined" || intent === "restoreSession") return;
  try {
    window.sessionStorage.setItem(
      pendingAuthenticationStorageKey,
      JSON.stringify({ intent, expectedUsername, email }),
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
  return new Promise<T>((resolve, reject) => {
    const timeoutID = setTimeout(() => reject(new Error(message)), AUTH_REQUEST_TIMEOUT_MS);
    Promise.resolve(promise).then(
      (value) => {
        clearTimeout(timeoutID);
        resolve(value);
      },
      (error: unknown) => {
        clearTimeout(timeoutID);
        reject(error);
      },
    );
  });
}

function getErrorMessage(error: unknown, fallback: string) {
  if (error instanceof Error) return error.message;
  if (typeof error === "object" && error !== null && "message" in error && typeof error.message === "string") {
    return error.message;
  }
  return fallback;
}

function requiresPasswordReauthentication(error: unknown) {
  if (typeof error !== "object" || error === null || !("code" in error)) return false;
  return error.code === "reauthentication_needed" || error.code === "reauth_nonce_missing";
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return context;
}
