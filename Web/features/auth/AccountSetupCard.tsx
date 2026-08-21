"use client";

import { useState } from "react";
import { Icon } from "@/components/Icon";
import { useAuth, type AccountResolutionState } from "./AuthProvider";

const stateCopy: Record<AccountResolutionState, string> = {
  signedOut: "Sign in with Apple or Google to continue.",
  resolving: "Checking the account behind this sign-in…",
  needsUsername: "Choose the public username that identifies this toDō account.",
  migrationRequired: "Confirm your username once to finish moving this account to the current account system.",
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
    continueWithAuthenticatedAccount,
    connectProvider,
    user,
  } = useAuth();
  const [enteredUsername, setEnteredUsername] = useState("");
  const username = profileUsername ?? enteredUsername;

  const normalized = normalizeUsername(username);
  const isMismatch = resolutionState === "accountMismatch";

  return (
    <section className="sign-in-card" aria-labelledby="account-setup-title">
      <p className="eyebrow">Account setup</p>
      <h1 id="account-setup-title">Finish your toDō account.</h1>
      <p className="sign-in-copy">{stateCopy[resolutionState]}</p>

      {isMismatch ? (
        <button
          className="primary-button"
          type="button"
          onClick={() => void continueWithAuthenticatedAccount()}
          disabled={isLoading}
        >
          Continue with this provider account
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
