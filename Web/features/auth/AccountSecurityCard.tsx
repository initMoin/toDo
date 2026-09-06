"use client";

import { useCallback, useEffect, useState, type FormEvent } from "react";
import Image from "next/image";
import { Icon } from "@/components/Icon";
import { supabase } from "@/lib/supabase";
import { useAuth, type WebTOTPEnrollment } from "./AuthProvider";

type WebPasskey = {
  id: string;
  friendly_name?: string;
  created_at: string;
  last_used_at?: string;
};

export function AccountSecurityCard() {
  const {
    user,
    isLoading,
    error: authError,
    mfaFactors,
    mfaAssuranceLevel,
    registerPasskey,
    setPassword,
    enrollTOTP,
    verifyMFA,
    unenrollMFA,
    requireAAL2,
  } = useAuth();
  const [passkeys, setPasskeys] = useState<WebPasskey[] | null>(null);
  const [passkeyError, setPasskeyError] = useState<string | null>(null);
  const [editingPasskeyID, setEditingPasskeyID] = useState<string | null>(null);
  const [passkeyName, setPasskeyName] = useState("");
  const [confirmingPasskeyID, setConfirmingPasskeyID] = useState<string | null>(null);
  const [isPasswordFormOpen, setIsPasswordFormOpen] = useState(false);
  const [password, setPasswordValue] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [passwordNonce, setPasswordNonce] = useState("");
  const [isPasswordVerificationRequired, setIsPasswordVerificationRequired] = useState(false);
  const [passwordMessage, setPasswordMessage] = useState<string | null>(null);
  const [totpEnrollment, setTotpEnrollment] = useState<WebTOTPEnrollment | null>(null);
  const [totpCode, setTotpCode] = useState("");
  const [mfaMessage, setMfaMessage] = useState<string | null>(null);

  const refreshPasskeys = useCallback(async () => {
    if (!supabase || !user) {
      setPasskeys(null);
      return;
    }
    const { data, error } = await supabase.auth.passkey.list();
    if (error) throw error;
    setPasskeys(data ?? []);
  }, [user]);

  useEffect(() => {
    let isCurrent = true;
    if (!supabase || !user) return () => { isCurrent = false; };
    void supabase.auth.passkey.list()
      .then(({ data, error }) => {
        if (!isCurrent) return;
        if (error) throw error;
        setPasskeys(data ?? []);
      })
      .catch(() => {
        if (isCurrent) setPasskeys(null);
      });
    return () => { isCurrent = false; };
  }, [user]);

  async function handlePasskey() {
    setPasskeyError(null);
    const didRegister = await registerPasskey();
    if (!didRegister) return;
    try {
      await refreshPasskeys();
    } catch (error) {
      setPasskeyError(error instanceof Error ? error.message : "Your passkeys could not be refreshed.");
    }
  }

  function beginPasskeyRename(passkey: WebPasskey, index: number) {
    setConfirmingPasskeyID(null);
    setEditingPasskeyID(passkey.id);
    setPasskeyName(passkey.friendly_name?.trim() || `Passkey ${index + 1}`);
    setPasskeyError(null);
  }

  async function handlePasskeyRename(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!supabase || !editingPasskeyID || !passkeyName.trim()) return;
    if (!await requireAAL2("rename a passkey")) return;
    setPasskeyError(null);
    const { error } = await supabase.auth.passkey.update({
      passkeyId: editingPasskeyID,
      friendlyName: passkeyName.trim(),
    });
    if (error) {
      setPasskeyError(error.message);
      return;
    }
    setEditingPasskeyID(null);
    setPasskeyName("");
    await refreshPasskeys();
  }

  async function handlePasskeyRemoval(passkeyID: string) {
    if (!supabase || confirmingPasskeyID !== passkeyID) {
      setEditingPasskeyID(null);
      setConfirmingPasskeyID(passkeyID);
      return;
    }
    if (!await requireAAL2("remove a passkey")) return;
    setPasskeyError(null);
    const { error } = await supabase.auth.passkey.delete({ passkeyId: passkeyID });
    if (error) {
      setPasskeyError(error.message);
      return;
    }
    setConfirmingPasskeyID(null);
    await refreshPasskeys();
  }

  async function handlePasswordSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPasswordMessage(null);
    if (password.length < 8) {
      setPasswordMessage("Use a password with at least 8 characters.");
      return;
    }
    if (password !== confirmation) {
      setPasswordMessage("The passwords do not match.");
      return;
    }
    if (isPasswordVerificationRequired && !/^\d{6}$/.test(passwordNonce)) {
      setPasswordMessage("Enter the six-digit verification code.");
      return;
    }
    const result = await setPassword(
      password,
      isPasswordVerificationRequired ? passwordNonce : undefined,
    );
    if (result === "verificationRequired") {
      setIsPasswordVerificationRequired(true);
      setPasswordMessage("Enter the six-digit code sent to your verified email.");
      return;
    }
    if (result === "saved") {
      setPasswordValue("");
      setConfirmation("");
      setPasswordNonce("");
      setIsPasswordVerificationRequired(false);
      setIsPasswordFormOpen(false);
      setPasswordMessage("Password saved.");
    }
  }

  function closePasswordForm() {
    setIsPasswordFormOpen(false);
    setPasswordValue("");
    setConfirmation("");
    setPasswordNonce("");
    setIsPasswordVerificationRequired(false);
    setPasswordMessage(null);
  }

  async function handleTOTPEnrollment() {
    setMfaMessage(null);
    const enrollment = await enrollTOTP();
    if (enrollment) setTotpEnrollment(enrollment);
  }

  async function handleTOTPVerification(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!totpEnrollment) return;
    const didVerify = await verifyMFA(totpEnrollment.factorID, totpCode);
    if (didVerify) {
      setTotpCode("");
      setTotpEnrollment(null);
      setMfaMessage("Authenticator app connected.");
    }
  }

  async function handleTOTPRemoval(factorID: string) {
    if (!window.confirm("Remove this authenticator from your toDō account?")) return;
    const didRemove = await unenrollMFA(factorID);
    if (didRemove) setMfaMessage("Authenticator app removed.");
  }

  async function handleTOTPCancellation() {
    if (!totpEnrollment) return;
    const didRemove = await unenrollMFA(totpEnrollment.factorID);
    if (didRemove) {
      setTotpCode("");
      setTotpEnrollment(null);
      setMfaMessage("Authenticator setup cancelled.");
    }
  }

  const emailVerified = Boolean(user?.email_confirmed_at);

  return (
    <section className="account-section" aria-labelledby="account-security-title">
      <h2 className="account-section-title" id="account-security-title">Security</h2>
      <div className="account-section-card account-security-card">
        <div className="account-list-row account-security-row">
          <Icon name="mail" size={19} />
          <span><strong>Verified email</strong><small>{emailVerified ? user?.email ?? "Verified" : "Verification required"}</small></span>
          <Icon name={emailVerified ? "check" : "alert"} size={18} />
        </div>
        <div className="account-list-row account-security-row">
          <Icon name="shield" size={19} />
          <span>
            <strong>Authenticator app</strong>
            <small>{mfaFactors.length ? `Connected · ${mfaAssuranceLevel === "aal2" ? "Verified now" : "Verification required"}` : "Recommended second factor"}</small>
          </span>
          {mfaFactors.length ? (
            <button className="account-security-inline-action" type="button" onClick={() => void handleTOTPRemoval(mfaFactors[0].id)} disabled={isLoading}>
              Remove
            </button>
          ) : (
            <button className="account-security-inline-action" type="button" onClick={() => void handleTOTPEnrollment()} disabled={isLoading || Boolean(totpEnrollment)}>
              Set up
            </button>
          )}
        </div>
        {totpEnrollment ? (
          <form className="account-security-totp-form" onSubmit={(event) => void handleTOTPVerification(event)}>
            <p>Scan this code with your authenticator app.</p>
            <Image
              className="account-security-totp-qr"
              src={totpQRSource(totpEnrollment.qrCode)}
              alt="Authenticator setup QR code"
              width={188}
              height={188}
              unoptimized
            />
            <label className="field-label" htmlFor="account-totp-secret">Setup key</label>
            <code id="account-totp-secret" className="account-security-secret">{totpEnrollment.secret}</code>
            <label className="field-label" htmlFor="account-totp-code">Authenticator code</label>
            <input
              id="account-totp-code"
              className="text-input sign-in-code-input"
              value={totpCode}
              onChange={(event) => setTotpCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
              inputMode="numeric"
              autoComplete="one-time-code"
              placeholder="000000"
              maxLength={6}
              disabled={isLoading}
            />
            <button className="primary-button" type="submit" disabled={isLoading || totpCode.length !== 6}>
              <Icon name="check" size={17} /> Verify authenticator
            </button>
            <button className="text-action" type="button" onClick={() => void handleTOTPCancellation()} disabled={isLoading}>
              Cancel
            </button>
          </form>
        ) : null}
        <div className="account-list-row account-security-row">
          <Icon name="key" size={19} />
          <span><strong>Passkeys</strong><small>{passkeys === null ? "Available on supported devices" : passkeys.length ? `${passkeys.length} connected` : "Not set up"}</small></span>
          <button className="account-security-inline-action" type="button" onClick={() => void handlePasskey()} disabled={isLoading}>
            {passkeys?.length ? "Add" : "Set up"}
          </button>
        </div>
        {passkeys?.length ? (
          <ul className="account-security-passkey-list" aria-label="Connected passkeys">
            {passkeys.map((passkey, index) => (
              <li key={passkey.id}>
                {editingPasskeyID === passkey.id ? (
                  <form className="account-security-passkey-edit" onSubmit={(event) => void handlePasskeyRename(event)}>
                    <label className="sr-only" htmlFor={`passkey-name-${passkey.id}`}>Passkey name</label>
                    <input
                      id={`passkey-name-${passkey.id}`}
                      className="text-input"
                      value={passkeyName}
                      onChange={(event) => setPasskeyName(event.target.value.slice(0, 120))}
                      autoComplete="off"
                      maxLength={120}
                    />
                    <button className="account-security-icon-action" type="submit" aria-label="Save passkey name" disabled={isLoading || !passkeyName.trim()}><Icon name="check" size={17} /></button>
                    <button className="account-security-icon-action" type="button" aria-label="Cancel passkey rename" onClick={() => setEditingPasskeyID(null)}><Icon name="close" size={17} /></button>
                  </form>
                ) : (
                  <>
                    <span>
                      <strong>{passkey.friendly_name?.trim() || `Passkey ${index + 1}`}</strong>
                      <small>Added {formatPasskeyDate(passkey.created_at)}</small>
                    </span>
                    {confirmingPasskeyID === passkey.id ? <small className="account-security-confirmation">Remove?</small> : null}
                    <button className="account-security-icon-action" type="button" aria-label={`Rename ${passkey.friendly_name?.trim() || `Passkey ${index + 1}`}`} onClick={() => beginPasskeyRename(passkey, index)} disabled={isLoading}><Icon name="edit" size={16} /></button>
                    <button className="account-security-icon-action account-security-icon-danger" type="button" aria-label={confirmingPasskeyID === passkey.id ? `Confirm removal of ${passkey.friendly_name?.trim() || `Passkey ${index + 1}`}` : `Remove ${passkey.friendly_name?.trim() || `Passkey ${index + 1}`}`} onClick={() => void handlePasskeyRemoval(passkey.id)} disabled={isLoading}><Icon name={confirmingPasskeyID === passkey.id ? "check" : "trash"} size={16} /></button>
                    {confirmingPasskeyID === passkey.id ? <button className="account-security-icon-action" type="button" aria-label="Cancel passkey removal" onClick={() => setConfirmingPasskeyID(null)}><Icon name="close" size={16} /></button> : null}
                  </>
                )}
              </li>
            ))}
          </ul>
        ) : null}
        <div className="account-list-row account-security-row">
          <Icon name="lock" size={19} />
          <span><strong>Password</strong><small>{emailVerified ? "Set or replace your password" : "Verify your email first"}</small></span>
          <button className="account-security-inline-action" type="button" onClick={() => isPasswordFormOpen ? closePasswordForm() : setIsPasswordFormOpen(true)} disabled={isLoading || !emailVerified}>
            Manage
          </button>
        </div>
        {isPasswordFormOpen ? (
          <form className="account-security-password-form" onSubmit={(event) => void handlePasswordSubmit(event)}>
            <label className="field-label" htmlFor="account-password">Password</label>
            <input id="account-password" className="text-input" type="password" autoComplete="new-password" value={password} onChange={(event) => setPasswordValue(event.target.value)} required />
            <label className="field-label" htmlFor="account-password-confirm">Confirm password</label>
            <input id="account-password-confirm" className="text-input" type="password" autoComplete="new-password" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} required />
            {isPasswordVerificationRequired ? (
              <>
                <label className="field-label" htmlFor="account-password-nonce">Verification code</label>
                <input id="account-password-nonce" className="text-input sign-in-code-input" inputMode="numeric" autoComplete="one-time-code" value={passwordNonce} onChange={(event) => setPasswordNonce(event.target.value.replace(/\D/g, "").slice(0, 6))} placeholder="000000" maxLength={6} required />
              </>
            ) : null}
            <button className="primary-button" type="submit" disabled={isLoading || (isPasswordVerificationRequired && passwordNonce.length !== 6)}><span>{isPasswordVerificationRequired ? "Verify and save" : "Save password"}</span><Icon name="check" size={17} /></button>
            <button className="text-action" type="button" onClick={closePasswordForm} disabled={isLoading}>Cancel</button>
          </form>
        ) : null}
        {passkeyError ? <p className="account-issue" role="alert">{passkeyError}</p> : null}
        {passwordMessage ? <p className="account-security-message" role="status">{passwordMessage}</p> : null}
        {mfaMessage ? <p className="account-security-message" role="status">{mfaMessage}</p> : null}
        {authError && !authError.includes("VITE_SUPABASE") ? <p className="account-issue" role="alert">{authError}</p> : null}
      </div>
    </section>
  );
}

function totpQRSource(qrCode: string) {
  return qrCode.startsWith("data:")
    ? qrCode
    : `data:image/svg+xml;charset=utf-8,${encodeURIComponent(qrCode)}`;
}

function formatPasskeyDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "recently";
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
}
