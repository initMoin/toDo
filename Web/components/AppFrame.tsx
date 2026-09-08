"use client";

import type { ReactNode } from "react";
import Link from "@/components/Link";
import { useSyncExternalStore } from "react";
import { Icon } from "@/components/Icon";
import { useAuth } from "@/features/auth/AuthProvider";
import { ProfileAvatar } from "@/features/account/ProfileAvatar";
import { LoadingCard } from "@/components/StateCard";

type AppFrameMode =
  | "home"
  | "todos"
  | "detail"
  | "stats"
  | "settings"
  | "settings-detail"
  | "settings-releases"
  | "account"
  | "account-settings"
  | "account-profile"
  | "account-profile-settings";

function SiteHeader({ mode, title }: { mode: AppFrameMode; title?: string }) {
  const { user, profileUsername, profileAvatarURL, webAccessState } = useAuth();
  const username = profileUsername ?? "toDō account";

  if (mode === "home") {
    return (
      <header className="site-header site-header-home">
        <div className="site-header-home-brand">
          <span className="header-date"><TodayLabel /></span>
          <Link className="wordmark" href="/" aria-label="toDō home">
            <span>toD</span><span className="wordmark-o">ō</span><span className="wordmark-plus" aria-hidden="true">+</span>
          </Link>
        </div>
        <HeaderAccountActions mode={mode} username={username} user={user} avatarURL={profileAvatarURL} webAccessState={webAccessState} />
      </header>
    );
  }

  return (
    <header className={`site-header site-header-${mode}`}>
      <div className="site-header-side site-header-side-left">
        {mode === "detail" ? (
          <Link className="header-link header-icon-button" href="/todos" aria-label="Back to active toDōs" title="Back to active toDōs">
            <Icon name="arrow-left" />
          </Link>
        ) : mode === "settings-detail" || mode === "settings-releases" || mode === "account-settings" ? (
          <Link className="header-link header-icon-button" href="/settings" aria-label="Back to Settings" title="Back to Settings">
            <Icon name="arrow-left" />
          </Link>
        ) : mode === "account-profile-settings" ? (
          <Link className="header-link header-icon-button" href="/account?from=settings" aria-label="Back to Account" title="Back to Account">
            <Icon name="arrow-left" />
          </Link>
        ) : mode === "account-profile" ? (
          <Link className="header-link header-icon-button" href="/account" aria-label="Back to Account" title="Back to Account">
            <Icon name="arrow-left" />
          </Link>
        ) : (
          <Link className="header-link header-icon-button header-home-link" href="/" aria-label="toDō Home" title="toDō Home">
            <Icon name="home" />
          </Link>
        )}
      </div>

      <div className="site-header-center">
        <span className="site-header-title">{title ?? headerTitle(mode)}</span>
      </div>

      <HeaderAccountActions mode={mode} username={username} user={user} avatarURL={profileAvatarURL} webAccessState={webAccessState} />
    </header>
  );
}

function headerTitle(mode: AppFrameMode) {
  switch (mode) {
    case "todos":
      return "toDō";
    case "detail":
      return "your toDō";
    case "stats":
      return "stats";
    case "settings":
      return "settings";
    case "settings-detail":
      return "about toDō";
    case "settings-releases":
      return "release history";
    case "account":
    case "account-settings":
      return "account";
    case "account-profile":
    case "account-profile-settings":
      return "my profile";
    default:
      return "toDō";
  }
}

function HeaderAccountActions({
  mode,
  username,
  user,
  avatarURL,
  webAccessState,
}: {
  mode: AppFrameMode;
  username: string;
  user: { user_metadata?: Record<string, unknown> } | null;
  avatarURL: string | null;
  webAccessState: ReturnType<typeof useAuth>["webAccessState"];
}) {
  return (
    <div className="site-header-side site-header-side-right">
      {user && mode === "home" && webAccessState === "granted" ? (
        <>
          <Link className="header-profile-link" href="/account" aria-label={`Open @${username} Account`} title={`Open @${username} Account`}>
            <ProfileAvatar username={username} avatarURL={avatarURL} size={46} />
          </Link>
          <Link className="header-link header-icon-button header-settings-link" href="/settings" aria-label="Settings" title="Settings">
            <Icon name="gear" />
          </Link>
        </>
      ) : null}
    </div>
  );
}

function TodayLabel() {
  return useSyncExternalStore(
    () => () => {},
    formatToday,
    () => "Today",
  );
}

function formatToday() {
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(new Date());
}

export function AppFrame({
  children,
  mode = "home",
  title,
}: {
  children: ReactNode;
  mode?: AppFrameMode;
  title?: string;
}) {
  const { user, isResolved, webAccessState, signOut } = useAuth();

  if (user && isResolved && webAccessState !== "granted") {
    return (
      <div className="app-background">
        <header className="site-header site-header-restricted">
          <span className="wordmark" aria-label="toDō">
            <span>toD</span><span className="wordmark-o">ō</span><span className="wordmark-plus" aria-hidden="true">+</span>
          </span>
        </header>
        <main className="app-main">
          <div className="state-layout">
            {webAccessState === "checking" ? <LoadingCard /> : (
              <section
                className={webAccessState === "denied" ? "restricted-access-card state-card-warning" : "restricted-access-card state-card-error"}
                aria-live="polite"
              >
                <span className="restricted-access-icon" aria-hidden="true">
                  <Icon name={webAccessState === "denied" ? "plus" : "alert"} size={28} />
                </span>
                <h2>{webAccessState === "denied" ? "toDō+ required" : "Web access unavailable"}</h2>
                <button
                  className="restricted-logout-button"
                  type="button"
                  aria-label="Log out"
                  title="Log out"
                  onClick={() => void signOut()}
                >
                  <Icon name="sign-out" size={22} />
                </button>
              </section>
            )}
          </div>
        </main>
      </div>
    );
  }

  return (
    <div className="app-background">
      <SiteHeader mode={mode} title={title} />
      <main className="app-main">{children}</main>
    </div>
  );
}
