"use client";

import { useState } from "react";
import { Icon } from "@/components/Icon";
import { useAuth, type AccountResolutionState } from "./AuthProvider";

const stateCopy: Record<AccountResolutionState, string> = {
  signedOut: "Sign in to continue.",
  resolving: "Checking the account behind this sign-in…",
  needsUsername: "Choose the public username that identifies this toDō account.",
  migrationRequired: "Confirm your username once to finish moving this account to the current account system.",
  mfaRequired: "Enter the code from your authenticator app before your toDōs open.",
  accountMismatch: "This provider is connected to a different toDō username. Nothing was linked or moved.",
  resolved: "Your account is ready.",
};

export function AccountSetupCard() {
  const {
    profileUsername,
    resolutionState,
    error,
    isLoading,
    completeAccountSetup,
    connectProvider,
    mfaFactors,
    verifyMFA,
    signOut,
    user,
  } = useAuth();
  const [enteredUsername, setEnteredUsername] = useState("");
  const [mfaCode, setMfaCode] = useState("");
  const username = profileUsername ?? enteredUsername;

  const normalized = normalizeUsername(username);
  const isMismatch = resolutionState === "accountMismatch";
  const isMFARequired = resolutionState === "mfaRequired";
  const mfaFactor = mfaFactors[0] ?? null;

  return (
    <section className="sign-in-card" aria-labelledby="account-setup-title">
      <p className="eyebrow">Account setup</p>
      <h1 id="account-setup-title">{isMFARequired ? "Verify your account." : "Finish your toDō account."}</h1>
      <p className="sign-in-copy">{stateCopy[resolutionState]}</p>

      {isMFARequired ? (
        <div className="sign-in-actions">
          <label className="field-label" htmlFor="account-mfa-code">Authenticator code</label>
          <input
            id="account-mfa-code"
            className="text-input sign-in-code-input"
            value={mfaCode}
            onChange={(event) => setMfaCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
            inputMode="numeric"
            autoComplete="one-time-code"
            placeholder="000000"
            maxLength={6}
            disabled={isLoading || !mfaFactor}
          />
          <button
            className="primary-button"
            type="button"
            onClick={() => mfaFactor && void verifyMFA(mfaFactor.id, mfaCode)}
            disabled={isLoading || !mfaFactor || mfaCode.length !== 6}
          >
            <Icon name="check" size={18} /> Verify
          </button>
          {!mfaFactor ? <p className="inline-error">Reload this page or sign out and try again.</p> : null}
          <button className="text-action" type="button" onClick={() => void signOut()} disabled={isLoading}>
            Sign out
          </button>
        </div>
      ) : isMismatch ? (
        <button
          className="secondary-button"
          type="button"
          onClick={() => void signOut()}
          disabled={isLoading}
        >
          Sign out and try again
        </button>
      ) : (
        <>
          <label className="field-label" htmlFor="account-username">
            Username
          </label>
          <input
            id="account-username"
            className="text-input"
            value={username}
            onChange={(event) => setEnteredUsername(event.target.value)}
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            placeholder="yourname"
            disabled={isLoading || resolutionState === "resolving"}
          />
          <button
            className="primary-button"
            type="button"
            onClick={() => void completeAccountSetup(username)}
            disabled={!normalized || isLoading || !user}
          >
            Continue
          </button>
        </>
      )}

      {resolutionState === "resolved" ? (
        <div className="sign-in-actions">
          <button className="provider-button" type="button" onClick={() => void connectProvider("apple")}>
            <Icon name="apple" size={18} /> Connect Apple
          </button>
          <button className="provider-button" type="button" onClick={() => void connectProvider("google")}>
            <Icon name="google" size={18} /> Connect Google
          </button>
        </div>
      ) : null}

      {error && !error.includes("VITE_SUPABASE") ? (
        <p className="inline-error" role="alert">{error}</p>
      ) : null}
    </section>
  );
}

function normalizeUsername(value: string): string | null {
  const normalized = value.trim().replace(/^@/, "").toLowerCase();
  if (!/^[a-z0-9._]{3,30}$/.test(normalized)) return null;
  if (normalized.startsWith(".") || normalized.endsWith(".")) return null;
  return normalized;
}
