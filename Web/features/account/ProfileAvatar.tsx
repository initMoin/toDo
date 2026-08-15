"use client";

import type { CSSProperties } from "react";

export function ProfileAvatar({
  username,
  avatarURL,
  size = 44,
  className = "",
}: {
  username: string;
  avatarURL: string | null;
  size?: number;
  className?: string;
}) {
  const safeURL = normalizeAvatarURL(avatarURL);
  const initials = getInitials(username);

  return (
    <span
      className={`profile-avatar ${className}`.trim()}
      style={{ "--profile-avatar-size": `${size}px` } as CSSProperties}
      role="img"
      aria-label={`Profile image for @${username}`}
    >
      {safeURL ? (
        <img
          src={safeURL}
          alt=""
          aria-hidden="true"
          referrerPolicy="no-referrer"
          onError={(event) => {
            event.currentTarget.hidden = true;
            event.currentTarget.nextElementSibling?.removeAttribute("hidden");
          }}
        />
      ) : null}
      <span className="profile-avatar-initials" hidden={Boolean(safeURL)} aria-hidden="true">
        {initials}
      </span>
    </span>
  );
}

function normalizeAvatarURL(value: string | null) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === "https:" ? url.toString() : null;
  } catch {
    return null;
  }
}

function getInitials(username: string) {
  const letters = username.replace(/[^a-z0-9]/gi, "").slice(0, 2).toUpperCase();
  return letters || "TD";
}
