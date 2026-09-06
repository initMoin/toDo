"use client";

import Link from "@/components/Link";
import { useEffect, useState, type FormEvent, type ReactNode } from "react";
import { Icon } from "@/components/Icon";
import { AccountSetupCard } from "@/features/auth/AccountSetupCard";
import { ProviderMethodsCard } from "@/features/auth/ProviderMethodsCard";
import { AccountSecurityCard } from "@/features/auth/AccountSecurityCard";
import { SignInCard } from "@/features/auth/SignInCard";
import { useAuth } from "@/features/auth/AuthProvider";
import { createCollab, loadCollabs } from "@/features/todos/data";
import type { Collab } from "@/lib/types";
import { ProfileAvatar } from "./ProfileAvatar";

export function AccountView({ fromSettings = false }: { fromSettings?: boolean }) {
  const {
    user,
    isLoading,
    isConfigured,
    isResolved,
    profileUsername,
    profileAvatarURL,
    continueWithAuthenticatedAccount,
    signOut,
    error: authError,
  } = useAuth();

  if (!isConfigured) {
    return <div className="state-layout"><StateMessage title="Connect Supabase to open Account"><p>Add the browser-safe Supabase values to <code>Web/.env.local</code> and restart the local server.</p></StateMessage></div>;
  }
  if (isLoading) {
    return <div className="state-layout"><p className="loading-message" aria-live="polite">Checking your toDō account…</p></div>;
  }
  if (!user) {
    return <div className="auth-layout"><SignInCard /></div>;
  }
  if (!isResolved) {
    return <div className="auth-layout"><AccountSetupCard /><p className="loading-message" aria-live="polite">Account stays paused until this provider is resolved to a username.</p></div>;
  }

  const username = profileUsername ?? "todo-user";

  return (
    <section className="account-shell" aria-labelledby="account-title">
      <h1 className="sr-only" id="account-title">account</h1>
      <div className="account-content">
        <AccountSummary username={username} avatarURL={profileAvatarURL} fromSettings={fromSettings} />

        <ProviderMethodsCard
          connectedProviders={new Set((user.identities ?? []).map((identity) => identity.provider))}
        />

        <AccountSecurityCard />

        <CollabsSection userID={user.id} />

        <section className="account-section" aria-labelledby="account-actions-title">
          <h2 className="account-section-title" id="account-actions-title">Account Actions</h2>
          <div className="account-section-card account-actions-card">
            <button className="account-list-row account-action-row" type="button" onClick={() => void continueWithAuthenticatedAccount()} disabled={isLoading}>
              <Icon name="reset" size={19} />
              <span><strong>Refresh Account</strong></span>
            </button>
            <button className="account-list-row account-action-row account-list-row-destructive" type="button" onClick={() => void signOut()} disabled={isLoading}>
              <Icon name="sign-out" size={19} />
              <span><strong>Sign Out</strong></span>
            </button>
          </div>
        </section>

        {authError ? (
          <section className="account-section" aria-labelledby="account-issue-title">
            <h2 className="account-section-title" id="account-issue-title">Account Issue</h2>
            <p className="account-issue" role="alert">{authError}</p>
          </section>
        ) : null}
      </div>
    </section>
  );
}

function AccountSummary({ username, avatarURL, fromSettings }: { username: string; avatarURL: string | null; fromSettings: boolean }) {
  return (
    <section className="account-section" aria-labelledby="account-summary-title">
      <h2 className="sr-only" id="account-summary-title">Account summary</h2>
      <Link className="account-section-card account-summary-card account-summary-link" href={fromSettings ? "/account/profile?from=settings" : "/account/profile"}>
        <ProfileAvatar username={username} avatarURL={avatarURL} size={46} />
        <div>
          <strong>@{username}</strong>
          <span>toDō account</span>
        </div>
        <Icon name="arrow-right" size={17} />
      </Link>
    </section>
  );
}

function CollabsSection({ userID }: { userID: string }) {
  const [collabs, setCollabs] = useState<Collab[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isCreateFormOpen, setIsCreateFormOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [newCollabName, setNewCollabName] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let isCurrent = true;
    void loadCollabs()
      .then((nextCollabs) => {
        if (isCurrent) setCollabs(nextCollabs);
      })
      .catch((loadError) => {
        if (isCurrent) setError(loadError instanceof Error ? loadError.message : "Collabs could not be loaded.");
      })
      .finally(() => {
        if (isCurrent) setIsLoading(false);
      });

    return () => {
      isCurrent = false;
    };
  }, [userID]);

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setIsSubmitting(true);
    try {
      const collab = await createCollab(newCollabName, userID);
      setCollabs((current) => [...current, collab].sort((left, right) => left.name.localeCompare(right.name)));
      setNewCollabName("");
      setIsCreateFormOpen(false);
    } catch (createError) {
      setError(createError instanceof Error ? createError.message : "The Collab could not be created.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <section className="account-section" aria-labelledby="account-collabs-title">
      <div className="account-section-heading">
        <h2 className="account-section-title" id="account-collabs-title">Collabs</h2>
        <button className="account-section-action" type="button" onClick={() => setIsCreateFormOpen((current) => !current)} aria-expanded={isCreateFormOpen}>
          <Icon name="plus" size={16} /> New Collab
        </button>
      </div>
      <div className="account-section-card account-collabs-card">
        {isLoading ? <p className="account-muted">Loading Collabs…</p> : null}
        {!isLoading && collabs.length === 0 ? <p className="account-muted">Create a Collab when you are ready to work with another user.</p> : null}
        {collabs.length > 0 ? (
          <ul className="account-list" aria-label="Your Collabs">
            {collabs.map((collab) => (
              <li className="account-list-row" key={collab.id}>
                <Icon name="group" size={19} />
                <span><strong>{collab.name}</strong><small>Shared list</small></span>
              </li>
            ))}
          </ul>
        ) : null}
        {isCreateFormOpen ? (
          <form className="account-inline-form" onSubmit={handleCreate}>
            <label htmlFor="new-collab-name">Collab Name</label>
            <div>
              <input id="new-collab-name" value={newCollabName} onChange={(event) => setNewCollabName(event.target.value)} autoComplete="off" maxLength={80} required />
              <button className="secondary-button" type="submit" disabled={!newCollabName.trim() || isSubmitting}>
                <Icon name="plus" size={15} /> {isSubmitting ? "Creating…" : "Create"}
              </button>
            </div>
          </form>
        ) : null}
        {error ? <p className="account-issue" role="alert">{error}</p> : null}
      </div>
    </section>
  );
}

function StateMessage({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="state-card">
      <div>
        <p className="eyebrow">Local setup</p>
        <h2>{title}</h2>
        <div className="state-card-copy">{children}</div>
      </div>
    </section>
  );
}
