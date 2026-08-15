"use client";

import type { ReactNode } from "react";
import { AccountSetupCard } from "@/features/auth/AccountSetupCard";
import { SignInCard } from "@/features/auth/SignInCard";
import { useAuth } from "@/features/auth/AuthProvider";
import { ProfileAvatar } from "./ProfileAvatar";

export function ProfileView() {
  const { user, isLoading, isConfigured, isResolved, profileUsername, profileAvatarURL } = useAuth();

  if (!isConfigured) {
    return <div className="state-layout"><ProfileState title="Connect Supabase to open My Profile"><p>Add the browser-safe Supabase values to <code>Web/.env.local</code> and restart the local server.</p></ProfileState></div>;
  }
  if (isLoading) {
    return <div className="state-layout"><p className="loading-message" aria-live="polite">Checking your toDō account…</p></div>;
  }
  if (!user) {
    return <div className="auth-layout"><SignInCard /></div>;
  }
  if (!isResolved) {
    return <div className="auth-layout"><AccountSetupCard /><p className="loading-message" aria-live="polite">My Profile stays paused until this provider is resolved to a username.</p></div>;
  }

  const username = profileUsername ?? "todo-user";
  const providers = (user.identities ?? []).map((identity) => identity.provider);

  return (
    <section className="profile-shell" aria-labelledby="profile-title">
      <h1 className="sr-only" id="profile-title">my profile</h1>
      <section className="profile-summary" aria-label="Profile summary">
        <ProfileAvatar username={username} avatarURL={profileAvatarURL} size={88} />
        <div>
          <p className="eyebrow">toDō account</p>
          <h2>@{username}</h2>
          <p>Used across your Account Sync surfaces.</p>
        </div>
      </section>

      <section className="profile-section" aria-labelledby="profile-details-title">
        <h2 className="profile-section-title" id="profile-details-title">Profile</h2>
        <div className="profile-section-card">
          <ProfileRow label="Username" value={`@${username}`} />
          <ProfileRow label="Profile image" value={profileAvatarURL ? "Connected" : "Initials"} />
        </div>
      </section>

      <section className="profile-section" aria-labelledby="profile-sign-in-title">
        <h2 className="profile-section-title" id="profile-sign-in-title">Sign-In Methods</h2>
        <div className="profile-section-card">
          {providers.map((provider) => <ProfileRow key={provider} label={providerLabel(provider)} value="Connected" />)}
        </div>
      </section>

    </section>
  );
}

function ProfileRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="profile-row">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function providerLabel(provider: string) {
  return provider === "apple" ? "Apple" : provider === "google" ? "Google" : provider;
}

function ProfileState({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="state-card">
      <div>
        <p className="eyebrow">My Profile</p>
        <h2>{title}</h2>
        <div className="state-card-copy">{children}</div>
      </div>
    </section>
  );
}
