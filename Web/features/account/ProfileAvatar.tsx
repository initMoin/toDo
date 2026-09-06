"use client";

import type { CSSProperties } from "react";
import Image from "next/image";

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

  return (
    <span
      key={safeURL ?? "empty-profile-image"}
      className={`profile-avatar ${className}`.trim()}
      style={{ "--profile-avatar-size": `${size}px`, width: `${size}px`, height: `${size}px` } as CSSProperties}
      role="img"
      aria-label={`Profile image for @${username}`}
    >
      {safeURL ? (
        <Image
          src={safeURL}
          alt=""
          width={size}
          height={size}
          unoptimized
          aria-hidden="true"
          referrerPolicy="no-referrer"
          onError={(event) => {
            event.currentTarget.hidden = true;
          }}
        />
      ) : null}
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
