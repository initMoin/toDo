"use client";

import Link from "@/components/Link";
import { useSyncExternalStore } from "react";
import type { ReactNode } from "react";
import { Icon } from "@/components/Icon";
import { AccountSetupCard } from "@/features/auth/AccountSetupCard";
import { SignInCard } from "@/features/auth/SignInCard";
import { useAuth } from "@/features/auth/AuthProvider";
import { LoadingCard } from "@/components/StateCard";
import { clearOnboarding, readOnboardingStep, saveOnboardingStep, subscribeToOnboarding } from "@/lib/onboarding";

export function Settings({ onboarding = false }: { onboarding?: boolean }) {
  const {
    user,
    isLoading,
    isConfigured,
    isResolved,
    resolutionState,
    profileUsername,
  } = useAuth();
  const storedOnboardingStep = useSyncExternalStore(
    subscribeToOnboarding,
    readOnboardingStep,
    () => null,
  );
  const isOnboarding = onboarding || storedOnboardingStep === "settings";

  if (!isConfigured) {
    return <div className="state-layout"><div className="state-card"><div><p className="eyebrow">Local setup</p><h2>Connect Supabase to open Settings</h2><div className="state-card-copy"><p>Add the browser-safe Supabase values to <code>Web/.env.local</code> and restart the local server.</p></div></div></div></div>;
  }
  if (isLoading) {
    return <div className="state-layout"><LoadingCard /></div>;
  }
  if (!user) return <div className="auth-layout"><SignInCard /></div>;
  if (!isResolved) {
    return <div className="auth-layout"><AccountSetupCard /></div>;
  }

  return (
    <section className="settings-shell" aria-labelledby="settings-title">
      <h1 className="sr-only" id="settings-title">settings</h1>
      {isOnboarding ? (
        <aside className="onboarding-card" aria-labelledby="onboarding-settings-title">
          <p className="eyebrow">Getting started</p>
          <h2 id="onboarding-settings-title">Your account is ready.</h2>
          <p>Settings is here when you need it. Your first toDō is saved and ready to follow across devices.</p>
          <Link className="primary-button" href="/" onClick={clearOnboarding}>Return to Home</Link>
        </aside>
      ) : null}

      <div className="settings-sections">
        <SettingsSection title="Account">
          <SettingsRow
            href="/account?from=settings"
            label={profileUsername ? `@${profileUsername}` : "Account"}
            detail="Profile and sign-in methods"
          />
        </SettingsSection>

        <SettingsSection title="toDō+">
          <SettingsRow href="/settings/membership" label="Membership" detail="Required for Web access" />
        </SettingsSection>

        <SettingsSection title="Sync" id="sync-settings-section">
          <div className="settings-sync-status">
            <span>Current Sync</span>
            <strong>Connected account</strong>
            <small>Changes are confirmed against Supabase before the Web view updates.</small>
          </div>
          <SettingsRow href="/settings/sync" label="Where to Save" detail="Connected account" />
        </SettingsSection>

        <SettingsSection title="Look & Feel">
          <SettingsRow href="/settings/appearance" label="Appearance" detail="Browser setting" />
          <SettingsRow href="/settings/tags" label="Tags" detail="Available in ToDos" />
        </SettingsSection>

        <SettingsSection title="Workflow">
          <SettingsRow href="/settings/behavior" label="Behavior" detail="Web-native task actions" />
          <SettingsRow href="/settings/notifications" label="Notifications" detail="Web push delivery" />
        </SettingsSection>

        <Link
          className="settings-guided-tour"
          href="/settings/tour"
          onClick={() => {
            saveOnboardingStep("detail");
          }}
        >
          <span>
            <strong>Guided Tour</strong>
            <small>Replay the setup flow for creating and reviewing a toDō.</small>
          </span>
          <Icon name="arrow-right" size={17} />
        </Link>

        <SettingsSection title="Manage Your Data">
          <SettingsRow href="/settings/data" label="Data Controls" detail="Export and account deletion" />
          <SettingsRow href="/settings/archives" label="Archives" detail="Completed and archived ToDos" />
          <SettingsRow href="/settings/trash" label="Trash" detail="Recently deleted ToDos" />
        </SettingsSection>

        <SettingsSection title="About">
          <SettingsRow href="/settings/about" label="About toDō" detail="Version and legal" />
        </SettingsSection>
      </div>
      <span className="sr-only">Account resolution: {resolutionState}</span>
    </section>
  );
}

function SettingsSection({ title, id, children }: { title: string; id?: string; children: ReactNode }) {
  return (
    <section className="settings-section" id={id} aria-labelledby={`${id ?? title}-title`}>
      <h2 className="settings-section-title" id={`${id ?? title}-title`}>{title}</h2>
      <div className="settings-section-card">{children}</div>
    </section>
  );
}

function SettingsRow({ href, label, detail }: { href?: string; label: string; detail: string }) {
  const content = (
    <>
      <span className="settings-row-copy">
        <strong>{label}</strong>
        <small>{detail}</small>
      </span>
      {href ? <Icon name="arrow-right" size={16} /> : null}
    </>
  );

  if (href) {
    return <Link className="settings-row" href={href}>{content}</Link>;
  }

  return <div className="settings-row settings-row-static">{content}</div>;
}
