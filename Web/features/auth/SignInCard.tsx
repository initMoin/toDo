"use client";

import { useAuth } from "./AuthProvider";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { Icon } from "@/components/Icon";

export function SignInCard() {
  const { signIn, isLoading, error } = useAuth();
  const [mode, setMode] = useState<"signIn" | "createAccount">("signIn");
  const [username, setUsername] = useState("");
  const [providerStepVisible, setProviderStepVisible] = useState(false);
  const firstProviderButtonRef = useRef<HTMLButtonElement>(null);
  const normalizedUsername = normalizeUsername(username);

  useEffect(() => {
    if (providerStepVisible) firstProviderButtonRef.current?.focus();
  }, [providerStepVisible]);

  function advanceToProviderStep() {
    if (!normalizedUsername || isLoading) return;
    setProviderStepVisible(true);
  }

  function handleUsernameSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    advanceToProviderStep();
  }

  function handleUsernameChange(value: string) {
    setUsername(value);
    setProviderStepVisible(false);
  }

  function handleModeChange(nextMode: "signIn" | "createAccount") {
    setMode(nextMode);
    setProviderStepVisible(false);
  }

  return (
    <section className="sign-in-card">
      <p className="eyebrow">toDō Sync</p>
      <h1>Keep what matters in step.</h1>

      <div className="sign-in-mode" role="group" aria-label="Account action">
        <button
          className={mode === "signIn" ? "mode-button mode-button-selected" : "mode-button"}
          type="button"
          onClick={() => handleModeChange("signIn")}
        >
          Sign in
        </button>
        <button
          className={mode === "createAccount" ? "mode-button mode-button-selected" : "mode-button"}
          type="button"
          onClick={() => handleModeChange("createAccount")}
        >
          Create account
        </button>
      </div>

      <form className="sign-in-username-form" onSubmit={handleUsernameSubmit}>
        <div className="sign-in-username-control">
          <label className="field-label" htmlFor="sign-in-username">Username</label>
          <input
            id="sign-in-username"
            className="text-input"
            value={username}
            onChange={(event) => handleUsernameChange(event.target.value)}
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            placeholder="yourname"
            aria-invalid={Boolean(username && !normalizedUsername)}
            onKeyDown={(event) => {
              if (event.key === "Enter") {
                event.preventDefault();
                advanceToProviderStep();
              }
            }}
          />
        </div>
        <button
          className="sign-in-forward-button"
          type="submit"
          aria-label="Move forward to sign-in options"
          title="Move forward"
          disabled={isLoading || !normalizedUsername}
        >
          <Icon name="arrow-right" size={21} />
        </button>
      </form>

      {providerStepVisible ? (
        <div
          className="sign-in-provider-step"
          role="group"
          aria-live="polite"
          aria-label="Sign-in options"
        >
          <div className="sign-in-actions">
            <button
              ref={firstProviderButtonRef}
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
