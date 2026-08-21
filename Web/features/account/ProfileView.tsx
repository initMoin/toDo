"use client";

import { useEffect, useRef, useState, type ChangeEvent, type PointerEvent, type ReactNode } from "react";
import { Icon } from "@/components/Icon";
import { AccountSetupCard } from "@/features/auth/AccountSetupCard";
import { SignInCard } from "@/features/auth/SignInCard";
import { useAuth } from "@/features/auth/AuthProvider";
import { ProfileAvatar } from "./ProfileAvatar";

export function ProfileView() {
  const { user, isLoading, isConfigured, isResolved, profileUsername, profileAvatarURL, saveProfileImage, error: authError } = useAuth();
  const [imageSource, setImageSource] = useState<string | null>(null);
  const [imageError, setImageError] = useState<string | null>(null);
  const [isSavingImage, setIsSavingImage] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

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

  function handleImageSelection(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    setImageError(null);
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      setImageError("Choose an image file.");
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      setImageError("Choose an image smaller than 5 MB.");
      return;
    }
    setImageSource(URL.createObjectURL(file));
  }

  async function handleImageSave(image: Blob) {
    setIsSavingImage(true);
    setImageError(null);
    try {
      const didSave = await saveProfileImage(image);
      if (!didSave) return;
      setImageSource(null);
    } catch (error) {
      setImageError(error instanceof Error ? error.message : "Your profile image could not be saved.");
    } finally {
      setIsSavingImage(false);
    }
  }

  return (
    <section className="profile-shell" aria-labelledby="profile-title">
      <h1 className="sr-only" id="profile-title">my profile</h1>
      <section className="profile-summary" aria-label="Profile summary">
        <div className="profile-avatar-editor-trigger">
          <ProfileAvatar username={username} avatarURL={profileAvatarURL} size={88} />
          <button
            className="profile-avatar-action"
            type="button"
            aria-label={profileAvatarURL ? "Adjust profile image" : "Choose profile image"}
            onClick={() => inputRef.current?.click()}
          >
            <Icon name={profileAvatarURL ? "edit" : "plus"} size={16} />
          </button>
          <input ref={inputRef} className="sr-only" type="file" accept="image/*" onChange={handleImageSelection} />
        </div>
        <div>
          <p className="eyebrow">toDō account</p>
          <h2>@{username}</h2>
        </div>
      </section>

      {imageSource ? (
        <ProfileImageEditor
          source={imageSource}
          isSaving={isSavingImage}
          onCancel={() => setImageSource(null)}
          onSave={(image) => void handleImageSave(image)}
        />
      ) : null}

      {imageError || (authError && !authError.includes("VITE_SUPABASE")) ? <p className="profile-inline-error" role="alert">{imageError ?? authError}</p> : null}

      <section className="profile-section" aria-labelledby="profile-details-title">
        <h2 className="profile-section-title" id="profile-details-title">Profile</h2>
        <div className="profile-section-card">
          <ProfileRow label="Username" value={`@${username}`} />
          <ProfileRow label="Profile image" value={profileAvatarURL ? "Set" : "Not set"} />
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

function ProfileImageEditor({
  source,
  isSaving,
  onCancel,
  onSave,
}: {
  source: string;
  isSaving: boolean;
  onCancel: () => void;
  onSave: (image: Blob) => void;
}) {
  const imageRef = useRef<HTMLImageElement>(null);
  const [zoom, setZoom] = useState(1);
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const dragRef = useRef<{ x: number; y: number; position: { x: number; y: number } } | null>(null);

  useEffect(() => () => URL.revokeObjectURL(source), [source]);

  function handlePointerDown(event: PointerEvent<HTMLDivElement>) {
    event.currentTarget.setPointerCapture(event.pointerId);
    dragRef.current = { x: event.clientX, y: event.clientY, position };
  }

  function handlePointerMove(event: PointerEvent<HTMLDivElement>) {
    if (!dragRef.current) return;
    const deltaX = (event.clientX - dragRef.current.x) / 130;
    const deltaY = (event.clientY - dragRef.current.y) / 130;
    setPosition({
      x: clamp(dragRef.current.position.x + deltaX, -1, 1),
      y: clamp(dragRef.current.position.y + deltaY, -1, 1),
    });
  }

  function handlePointerUp() {
    dragRef.current = null;
  }

  async function finalizeImage() {
    const image = imageRef.current;
    if (!image?.naturalWidth || !image.naturalHeight) return;
    const square = Math.min(image.naturalWidth, image.naturalHeight) / zoom;
    const maxX = image.naturalWidth - square;
    const maxY = image.naturalHeight - square;
    const sourceX = (maxX / 2) - (position.x * maxX / 2);
    const sourceY = (maxY / 2) - (position.y * maxY / 2);
    const canvas = document.createElement("canvas");
    canvas.width = 512;
    canvas.height = 512;
    const context = canvas.getContext("2d");
    if (!context) return;
    context.drawImage(image, sourceX, sourceY, square, square, 0, 0, 512, 512);
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.88));
    if (blob) onSave(blob);
  }

  return (
    <section className="profile-image-editor" aria-labelledby="profile-image-editor-title">
      <div className="profile-image-editor-heading">
        <div>
          <p className="eyebrow">Profile image</p>
          <h2 id="profile-image-editor-title">Adjust image</h2>
        </div>
        <button className="icon-button" type="button" onClick={onCancel} aria-label="Cancel profile image"><Icon name="close" size={18} /></button>
      </div>
      <div
        className="profile-image-crop"
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
        role="application"
        aria-label="Drag the image to adjust its crop"
      >
        <img
          ref={imageRef}
          src={source}
          alt=""
          style={{ transform: `translate(${position.x * -12}%, ${position.y * -12}%) scale(${zoom})` }}
          onLoad={(event) => { imageRef.current = event.currentTarget; }}
        />
      </div>
      <label className="profile-image-zoom" htmlFor="profile-image-zoom">
        <span>Zoom</span>
        <input id="profile-image-zoom" type="range" min="1" max="3" step="0.05" value={zoom} onChange={(event) => setZoom(Number(event.target.value))} />
      </label>
      <div className="profile-image-editor-actions">
        <button className="icon-action-button" type="button" onClick={onCancel} disabled={isSaving} aria-label="Cancel profile image" title="Cancel"><Icon name="close" size={18} /></button>
        <button className="icon-action-button profile-image-save-action" type="button" onClick={() => void finalizeImage()} disabled={isSaving} aria-label={isSaving ? "Saving profile image" : "Save profile image"} title={isSaving ? "Saving…" : "Save image"}><Icon name="check" size={18} /></button>
      </div>
    </section>
  );
}

function clamp(value: number, minimum: number, maximum: number) {
  return Math.min(Math.max(value, minimum), maximum);
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
