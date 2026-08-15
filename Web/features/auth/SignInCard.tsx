"use client";

import { useAuth } from "./AuthProvider";
import { useState } from "react";
import { Icon } from "@/components/Icon";

export function SignInCard() {
  const { signIn, isLoading, error } = useAuth();
  const [mode, setMode] = useState<"signIn" | "createAccount">("signIn");
  const [username, setUsername] = useState("");
  const normalizedUsername = normalizeUsername(username);

  return (
    <section className="sign-in-card">
      <p className="eyebrow">toDō Sync</p>
      <h1>Keep what matters in step.</h1>
      <p className="sign-in-copy">
        Sign in to see the toDōs you already use across iPhone, Android, and Web.
        Web access is part of toDō+.
      </p>

      <div className="sign-in-mode" role="group" aria-label="Account action">
        <button
          className={mode === "signIn" ? "mode-button mode-button-selected" : "mode-button"}
          type="button"
          onClick={() => setMode("signIn")}
        >
          Sign in
        </button>
        <button
          className={mode === "createAccount" ? "mode-button mode-button-selected" : "mode-button"}
          type="button"
          onClick={() => setMode("createAccount")}
        >
          Create account
        </button>
      </div>

      <label className="field-label" htmlFor="sign-in-username">Username</label>
      <input
        id="sign-in-username"
        className="text-input"
        value={username}
        onChange={(event) => setUsername(event.target.value)}
        autoCapitalize="none"
        autoCorrect="off"
        spellCheck={false}
        placeholder="yourname"
      />
      <p className="field-help">Displayed as @{normalizedUsername ?? "username"}. Apple or Google proves ownership.</p>

      <div className="sign-in-actions">
        <button
          className="provider-button provider-button-apple"
          type="button"
          onClick={() => void signIn("apple", mode, normalizedUsername ?? "")}
          disabled={isLoading || !normalizedUsername}
        >
          <span className="provider-symbol" aria-hidden="true"><Icon name="apple" size={20} /></span>
          <span>Continue with Apple</span>
        </button>
        <button
          className="provider-button provider-button-google"
          type="button"
          onClick={() => void signIn("google", mode, normalizedUsername ?? "")}
          disabled={isLoading || !normalizedUsername}
        >
          <span className="provider-symbol" aria-hidden="true"><Icon name="google" size={20} /></span>
          <span>Continue with Google</span>
        </button>
      </div>

      {error && !error.includes("VITE_SUPABASE") ? (
        <p className="inline-error" role="alert">{error}</p>
      ) : null}

      <p className="sign-in-note">
        Your username identifies the toDō account you mean. You can connect the
        other provider later from Account Settings; usernames and email addresses
        never connect accounts automatically.
      </p>
    </section>
  );
}

function normalizeUsername(value: string): string | null {
  const normalized = value.trim().replace(/^@/, "").toLowerCase();
  if (!/^[a-z0-9._]{3,30}$/.test(normalized)) return null;
  if (normalized.startsWith(".") || normalized.endsWith(".")) return null;
  return normalized;
}
