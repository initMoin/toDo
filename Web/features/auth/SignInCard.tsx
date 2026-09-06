"use client";

import { useEffect, useRef, useState, type FormEvent, type RefObject } from "react";
import { Icon } from "@/components/Icon";
import { useAuth } from "./AuthProvider";

type SignInMode = "signIn" | "createAccount";
type SignInStep = "username" | "methods" | "email" | "password" | "code";

export function SignInCard() {
  const {
    requestEmailCode,
    verifyEmailCode,
    signIn,
    signInWithPassword,
    signInWithPasskey,
    isLoading,
    error,
  } = useAuth();
  const [mode, setMode] = useState<SignInMode>("signIn");
  const [step, setStep] = useState<SignInStep>("username");
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [code, setCode] = useState("");
  const [showOtherMethods, setShowOtherMethods] = useState(false);
  const firstActionRef = useRef<HTMLButtonElement | HTMLInputElement>(null);
  const normalizedUsername = normalizeUsername(username);

  useEffect(() => {
    if (step !== "username") firstActionRef.current?.focus();
  }, [step]);

  function resetToUsername() {
    setStep("username");
    setEmail("");
    setPassword("");
    setCode("");
    setShowOtherMethods(false);
  }

  function handleModeChange(nextMode: SignInMode) {
    setMode(nextMode);
    resetToUsername();
  }

  function handleUsernameSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (normalizedUsername && !isLoading) setStep("methods");
  }

  async function handleEmailSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!normalizedUsername || isLoading) return;
    if (step === "email") {
      const didSend = await requestEmailCode(mode, normalizedUsername, email);
      if (didSend) setStep("code");
      return;
    }
    if (step === "password") {
      await signInWithPassword(normalizedUsername, email, password);
    }
  }

  async function handleCodeSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!normalizedUsername || isLoading) return;
    await verifyEmailCode(mode, normalizedUsername, email, code);
  }

  return (
    <section className="sign-in-card" aria-labelledby="sign-in-title">
      <p className="eyebrow">toDō account</p>
      <h1 id="sign-in-title">Keep what matters in step.</h1>

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

      {step === "username" ? (
        <form className="sign-in-username-form" onSubmit={handleUsernameSubmit}>
          <div className="sign-in-username-control">
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
              aria-invalid={Boolean(username && !normalizedUsername)}
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
      ) : null}

      {step === "methods" ? (
        <div className="sign-in-provider-step" role="group" aria-label="Sign-in options">
          <div className="sign-in-actions">
            {mode === "signIn" ? (
              <button
                ref={firstActionRef as RefObject<HTMLButtonElement>}
                className="provider-button provider-button-passkey"
                type="button"
                onClick={() => void signInWithPasskey(normalizedUsername ?? "")}
                disabled={isLoading}
              >
                <Icon name="key" size={19} />
                <span>Use passkey</span>
              </button>
            ) : null}
            <button
              ref={mode === "createAccount" ? firstActionRef as RefObject<HTMLButtonElement> : undefined}
              className="provider-button provider-button-email"
              type="button"
              onClick={() => setStep(mode === "signIn" ? "password" : "email")}
              disabled={isLoading}
            >
              <Icon name="mail" size={19} />
              <span>{mode === "signIn" ? "Use email and password" : "Use email"}</span>
            </button>
            {mode === "signIn" ? (
              <button
                className="text-action"
                type="button"
                onClick={() => setStep("email")}
                disabled={isLoading}
              >
                Use an email code
              </button>
            ) : null}
            <button
              className="text-action"
              type="button"
              onClick={() => setShowOtherMethods((current) => !current)}
              aria-expanded={showOtherMethods}
              disabled={isLoading}
            >
              <span>Other sign-in methods</span>
              <Icon name={showOtherMethods ? "chevron-up" : "chevron-down"} size={16} />
            </button>
            {showOtherMethods ? (
              <>
                <button
                  className="provider-button provider-button-apple"
                  type="button"
                  onClick={() => void signIn("apple", mode, normalizedUsername ?? "")}
                  disabled={isLoading}
                >
                  <span className="provider-symbol" aria-hidden="true"><Icon name="apple" size={20} /></span>
                  <span>Continue with Apple</span>
                </button>
                <button
                  className="provider-button provider-button-google"
                  type="button"
                  onClick={() => void signIn("google", mode, normalizedUsername ?? "")}
                  disabled={isLoading}
                >
                  <span className="provider-symbol" aria-hidden="true"><Icon name="google" size={20} /></span>
                  <span>Continue with Google</span>
                </button>
              </>
            ) : null}
            <button className="text-action" type="button" onClick={resetToUsername} disabled={isLoading}>
              <Icon name="arrow-left" size={16} />
              <span>Change username</span>
            </button>
          </div>
        </div>
      ) : null}

      {step === "email" || step === "password" ? (
        <form className="sign-in-provider-step sign-in-email-form" onSubmit={(event) => void handleEmailSubmit(event)}>
          <label className="field-label" htmlFor="sign-in-email">Email</label>
          <input
            ref={firstActionRef as RefObject<HTMLInputElement>}
            id="sign-in-email"
            className="text-input"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            autoComplete="email"
            inputMode="email"
            placeholder="you@example.com"
            disabled={isLoading}
            required
          />
          {step === "password" ? (
            <>
              <label className="field-label" htmlFor="sign-in-password">Password</label>
              <input
                id="sign-in-password"
                className="text-input"
                type="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                autoComplete="current-password"
                disabled={isLoading}
                required
              />
            </>
          ) : null}
          <div className="sign-in-form-actions">
            <button className="primary-button" type="submit" disabled={isLoading}>
              <span>{isLoading ? "Working…" : step === "password" ? "Sign in" : "Send code"}</span>
              <Icon name="arrow-right" size={17} />
            </button>
            <button className="text-action" type="button" onClick={() => setStep("methods")} disabled={isLoading}>
              <Icon name="arrow-left" size={16} />
              <span>Other options</span>
            </button>
          </div>
        </form>
      ) : null}

      {step === "code" ? (
        <form className="sign-in-provider-step sign-in-email-form" onSubmit={(event) => void handleCodeSubmit(event)}>
          <label className="field-label" htmlFor="sign-in-code">Email code</label>
          <input
            ref={firstActionRef as RefObject<HTMLInputElement>}
            id="sign-in-code"
            className="text-input sign-in-code-input"
            value={code}
            onChange={(event) => setCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
            inputMode="numeric"
            autoComplete="one-time-code"
            placeholder="000000"
            maxLength={6}
            disabled={isLoading}
            required
          />
          <div className="sign-in-form-actions">
            <button className="primary-button" type="submit" disabled={isLoading || code.length !== 6}>
              <span>{isLoading ? "Checking…" : "Verify email"}</span>
              <Icon name="check" size={17} />
            </button>
            <button className="text-action" type="button" onClick={() => setStep("email")} disabled={isLoading}>
              Use a different email
            </button>
          </div>
        </form>
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
