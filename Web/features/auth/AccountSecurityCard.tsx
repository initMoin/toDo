"use client";

import { useEffect, useState } from "react";
import { Icon } from "@/components/Icon";
import { supabase } from "@/lib/supabase";
import { useAuth } from "./AuthProvider";

type WebPasskey = {
  id: string;
  friendly_name?: string;
  created_at: string;
};

export function AccountSecurityCard() {
  const { user, mfaFactors, mfaAssuranceLevel, error: authError } = useAuth();
  const [passkeys, setPasskeys] = useState<WebPasskey[] | null>(null);
  const emailVerified = Boolean(user?.email_confirmed_at);

  useEffect(() => {
    let isCurrent = true;
    if (!supabase || !user) return () => { isCurrent = false; };

    void supabase.auth.passkey.list()
      .then(({ data, error }) => {
        if (!isCurrent || error) return;
        setPasskeys(data ?? []);
      })
      .catch(() => {
        if (isCurrent) setPasskeys(null);
      });

    return () => { isCurrent = false; };
  }, [user]);

  return (
    <section className="account-section" aria-labelledby="account-security-title">
      <h2 className="account-section-title" id="account-security-title">Security</h2>
      <div className="account-section-card account-security-card" aria-readonly="true">
        <StatusRow icon="mail" title="Verified email" detail={emailVerified ? user?.email ?? "Verified" : "Verification required"} complete={emailVerified} />
        <StatusRow
          icon="shield"
          title="Authenticator app"
          detail={mfaFactors.length
            ? `Connected · ${mfaAssuranceLevel === "aal2" ? "Verified now" : "Verification required"}`
            : "Not set up"}
          complete={mfaFactors.length > 0}
        />
        <StatusRow
          icon="key"
          title="Passkeys"
          detail={passkeys === null ? "Available on supported devices" : passkeys.length ? `${passkeys.length} connected` : "Not set up"}
          complete={Boolean(passkeys?.length)}
        />
        {passkeys?.length ? (
          <ul className="account-security-passkey-list" aria-label="Connected passkeys">
            {passkeys.map((passkey, index) => (
              <li key={passkey.id}>
                <span>
                  <strong>{passkey.friendly_name?.trim() || `Passkey ${index + 1}`}</strong>
                  <small>Added {formatPasskeyDate(passkey.created_at)}</small>
                </span>
                <Icon name="check" size={16} aria-hidden="true" />
              </li>
            ))}
          </ul>
        ) : null}
        <StatusRow icon="lock" title="Password" detail={emailVerified ? "Configured" : "Verification required"} complete={emailVerified} />
        {authError && !authError.includes("VITE_SUPABASE") ? <p className="account-issue" role="alert">{authError}</p> : null}
      </div>
    </section>
  );
}

function StatusRow({ icon, title, detail, complete }: { icon: "mail" | "shield" | "key" | "lock"; title: string; detail: string; complete: boolean }) {
  return (
    <div className="account-list-row account-security-row">
      <Icon name={icon} size={19} />
      <span><strong>{title}</strong><small>{detail}</small></span>
      <Icon name={complete ? "check" : "alert"} size={18} />
    </div>
  );
}

function formatPasskeyDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "recently";
  return new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric", year: "numeric" }).format(date);
}
