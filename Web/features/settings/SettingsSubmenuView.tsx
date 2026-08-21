"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState, type FormEvent, type ReactNode } from "react";
import { Icon, type IconName } from "@/components/Icon";
import { useAuth } from "@/features/auth/AuthProvider";
import {
  createTag,
  deleteTag,
  deleteTodoPermanently,
  deleteTodosForUser,
  hasWebPlusAccess,
  loadEntitlements,
  loadRemoteSnapshot,
  updateTodoLifecycle,
} from "@/features/todos/data";
import {
  createCalendarFeedURL,
  loadWebNotificationPreferences,
  registerWebPushSubscription,
  revokeCalendarFeed,
  saveWebNotificationPreferences,
  type WebNotificationPreferencePatch,
} from "@/lib/webIntegrations";
import { supabase } from "@/lib/supabase";
import type { RemoteSnapshot, Tag, Todo } from "@/lib/types";

export type SettingsSubmenuKey =
  | "appearance"
  | "archives"
  | "behavior"
  | "data"
  | "membership"
  | "notifications"
  | "sync"
  | "tags"
  | "tour"
  | "trash";

type ThemeName = "classic" | "coastal" | "ember" | "orchard" | "midnight" | "shift";
type AppearanceMode = "system" | "light" | "dark";
type SortOption = "dueDate" | "created" | "tag" | "dueMonth" | "tagSections" | "nanoDos";
type TimeSource = "location" | "device";
type RemoveAction = "archive" | "trash";
type NotificationSound = "default" | "silent" | "soft" | "bright" | "urgent" | "custom";
type CompletionSound = "off" | "soft" | "bright";
type BadgePolicy = "off" | "active" | "dueToday" | "overdue" | "timeSensitive" | "scheduled";

type SettingsPreferences = {
  theme: ThemeName;
  appearance: AppearanceMode;
  sort: SortOption;
  sortReversed: boolean;
  timeSource: TimeSource;
  dueTime: string;
  removeAction: RemoveAction;
  calendarMirror: boolean;
  tagsByDefault: boolean;
  reminderAlerts: boolean;
  notificationSound: NotificationSound;
  customSoundName: string;
  completionSound: CompletionSound;
  badgePolicy: BadgePolicy;
  snooze: { minutes: number[]; hours: number[]; days: number[] };
  trashAutoEmpty: "1 Week" | "2 Weeks" | "1 Month" | "3 Months" | "Never";
  matchDeletes: boolean;
};

const settingsStorageKey = "todo.web.settings.v2";
const defaultPreferences: SettingsPreferences = {
  theme: "classic",
  appearance: "system",
  sort: "dueDate",
  sortReversed: false,
  timeSource: "location",
  dueTime: "09:00",
  removeAction: "archive",
  calendarMirror: false,
  tagsByDefault: false,
  reminderAlerts: false,
  notificationSound: "default",
  customSoundName: "",
  completionSound: "off",
  badgePolicy: "overdue",
  snooze: { minutes: [5, 15, 30], hours: [1, 2], days: [1] },
  trashAutoEmpty: "1 Month",
  matchDeletes: true,
};

const submenuDetails: Record<SettingsSubmenuKey, {
  title: string;
  intro: string;
  eyebrow: string;
  heading: string;
  body: string;
  icon: IconName;
}> = {
  membership: { title: "toDō+", intro: "Membership recognition and access for this Web account.", eyebrow: "membership", heading: "toDō+", body: "Your Web access follows the same account entitlement used by toDō on Apple platforms.", icon: "sparkles" },
  sync: { title: "sync", intro: "The Web version keeps the shared Supabase account as its single sync destination.", eyebrow: "where to save", heading: "Supabase account sync", body: "Every Web change is authorized against the signed-in account before the view updates.", icon: "repeat" },
  appearance: { title: "appearance", intro: "Choose the look and appearance mode that make toDō feel like yours.", eyebrow: "look & feel", heading: "Make toDō your own", body: "These choices are stored on this browser and apply across the Web views.", icon: "paint-palette" },
  tags: { title: "tags", intro: "Create, review, and clean up the tag library shared by your ToDos.", eyebrow: "tag library", heading: "Keep your tags useful", body: "Default tags stay available, while custom tags can be added or removed from this view.", icon: "tag" },
  behavior: { title: "behavior", intro: "Set the way ToDos are ordered, timed, completed, and mirrored on the Web.", eyebrow: "workflow", heading: "Work the way you work", body: "The Web controls preserve the intent of the iOS and iPadOS Behavior view with browser-native controls.", icon: "task-list" },
  notifications: { title: "notifications", intro: "Control reminder permission, sounds, badges, and snooze choices.", eyebrow: "reminder alerts", heading: "Stay aware without being interrupted", body: "Web permission is requested only when you choose to enable reminder alerts.", icon: "bell" },
  tour: { title: "guided tour", intro: "Replay the short path through capture, review, and the Web task workflow.", eyebrow: "getting started", heading: "Capture, review, continue", body: "Use the same focused sequence as the Apple apps, adapted to browser navigation.", icon: "sparkles" },
  data: { title: "data controls", intro: "Export your account data, reset local choices, clear personal ToDos, or delete the account.", eyebrow: "manage your data", heading: "Your data stays yours", body: "These actions use the signed-in Supabase session and are intentionally explicit about destructive changes.", icon: "gear" },
  archives: { title: "archives", intro: "Review completed and archived ToDos, restore them, or permanently purge them.", eyebrow: "completed ToDos", heading: "A place to keep finished work", body: "Archives preserve the iOS and iPadOS distinction between completing a task and removing it from the active view.", icon: "archive" },
  trash: { title: "trash", intro: "Review deleted ToDos, restore them, or permanently empty the trash.", eyebrow: "recently deleted", heading: "Nothing disappears by accident", body: "Deleted ToDos remain recoverable until you permanently remove them or the auto-empty interval passes.", icon: "trash" },
};

export function SettingsSubmenuView({ kind }: { kind: SettingsSubmenuKey }) {
  const content = submenuDetails[kind];
  const { user, isConfigured, isResolved, signOut } = useAuth();
  const [preferences, setPreferences] = useSettingsPreferences();
  const requiresSnapshot = kind === "tags" || kind === "archives" || kind === "trash" || kind === "data";
  const { snapshot, isLoading, error, refresh } = useSettingsSnapshot(requiresSnapshot && Boolean(user) && isResolved && isConfigured);
  const [message, setMessage] = useState<string | null>(null);
  const [isBusy, setIsBusy] = useState(false);

  const runAction = useCallback(async (action: () => Promise<void>, successMessage: string) => {
    setIsBusy(true);
    setMessage(null);
    try {
      await action();
      setMessage(successMessage);
      await refresh();
    } catch (actionError) {
      setMessage(actionError instanceof Error ? actionError.message : "That change could not be saved.");
    } finally {
      setIsBusy(false);
    }
  }, [refresh]);

  const sharedProps = { preferences, setPreferences, isBusy, setMessage };

  return (
    <article className="settings-detail-shell settings-submenu-shell" aria-labelledby={`${kind}-title`}>
      <h1 className="sr-only" id={`${kind}-title`}>{content.title}</h1>
      <p className="settings-detail-intro">{content.intro}</p>
      <div className="settings-detail-content">
        <div className="settings-detail-lead">
          <span className="settings-detail-icon" aria-hidden="true"><Icon name={content.icon} size={20} /></span>
          <div><p className="eyebrow">{content.eyebrow}</p><h2>{content.heading}</h2><p>{content.body}</p></div>
        </div>
        {message ? <p className="settings-feedback" role="status">{message}</p> : null}
        {!isConfigured ? <p className="settings-platform-note">Connect Supabase to use account-backed Settings actions.</p> : null}
        {kind === "membership" ? <MembershipSettings userID={user?.id ?? null} /> : null}
        {kind === "sync" ? <SyncSettings {...sharedProps} /> : null}
        {kind === "appearance" ? <AppearanceSettings {...sharedProps} /> : null}
        {kind === "tags" ? <TagsSettings snapshot={snapshot} isLoading={isLoading} error={error} userID={user?.id ?? null} runAction={runAction} preferences={preferences} setPreferences={setPreferences} /> : null}
        {kind === "behavior" ? <BehaviorSettings {...sharedProps} userID={user?.id ?? null} /> : null}
        {kind === "notifications" ? <NotificationsSettings {...sharedProps} userID={user?.id ?? null} /> : null}
        {kind === "tour" ? <TourSettings /> : null}
        {kind === "data" ? <DataSettings snapshot={snapshot} isLoading={isLoading} userID={user?.id ?? null} runAction={runAction} signOut={signOut} setMessage={setMessage} setPreferences={setPreferences} /> : null}
        {kind === "archives" ? <ArchivesSettings snapshot={snapshot} isLoading={isLoading} error={error} runAction={runAction} /> : null}
        {kind === "trash" ? <TrashSettings snapshot={snapshot} isLoading={isLoading} error={error} preferences={preferences} setPreferences={setPreferences} runAction={runAction} /> : null}
      </div>
    </article>
  );
}

function MembershipSettings({ userID }: { userID: string | null }) {
  const [status, setStatus] = useState<"loading" | "active" | "inactive">(userID ? "loading" : "inactive");
  useEffect(() => {
    let active = true;
    if (!userID) return () => { active = false; };
    void loadEntitlements().then((entitlements) => { if (active) setStatus(hasWebPlusAccess(entitlements) ? "active" : "inactive"); }).catch(() => { if (active) setStatus("inactive"); });
    return () => { active = false; };
  }, [userID]);
  return <div className="settings-control-stack">
    <SettingsCard title="Current access" icon={status === "active" ? "check" : "sparkles"}>
      <div className={`settings-status-banner settings-status-${status}`}><span className="settings-status-icon"><Icon name={status === "active" ? "check" : "sparkles"} size={18} /></span><div><strong>{status === "loading" ? "Checking membership…" : status === "active" ? "toDō+ is active" : "toDō+ membership required"}</strong><p>{status === "active" ? "This account can open the Web app and use its synced task features." : "Sign in with the account that owns your toDō+ entitlement to open the Web app."}</p></div></div>
    </SettingsCard>
    <SettingsCard title="Included with toDō+" icon="sparkles">
      <SettingsList items={[["Personal Collabs", "Send and receive shared-list invitations."], ["Web access", "Keep your active ToDos available at do.yourtodo.today."], ["New features", "Receive the features included in your membership."]]} />
      <p className="settings-note">Membership purchases and subscription management remain tied to the account’s existing purchase system.</p>
    </SettingsCard>
  </div>;
}

function SyncSettings({ preferences, setPreferences }: SettingsSharedProps) {
  return <div className="settings-control-stack">
    <SettingsCard title="Current choice" icon="repeat"><div className="settings-status-banner settings-status-active"><span className="settings-status-icon"><Icon name="repeat" size={18} /></span><div><strong>Supabase account</strong><p>Web changes are saved to the signed-in account and remain available to the supported toDō platforms.</p></div></div></SettingsCard>
    <SettingsCard title="What syncs" icon="repeat"><SettingsList items={[["Personal ToDos", "Active, completed, archived, and trashed items."], ["Collabs", "Shared lists and their access stay with the account."], ["Profile image", "The finalized image from Profile is used across the site."]]} /></SettingsCard>
    <SettingsCard title="Account boundary" icon="users"><SettingsList items={[["Apple Sign-In", "A separate toDō account."], ["Google Sign-In", "A separate toDō account."], ["Account transfer", "Not part of the current Web flow."]]} /></SettingsCard>
    <SettingsCard title="Delete behavior" icon="repeat"><SettingsSwitch icon="repeat" label="Match Deletes Everywhere" detail="Keep task deletion behavior consistent with the synced account." checked={preferences.matchDeletes} onChange={(value) => setPreferences("matchDeletes", value)} /></SettingsCard>
  </div>;
}

function AppearanceSettings({ preferences, setPreferences }: SettingsSharedProps) {
  const themes: Array<{ id: ThemeName; title: string; subtitle: string; colors: string[] }> = [
    { id: "classic", title: "Classic", subtitle: "The original toDō yellow and blue.", colors: ["#e9a700", "#006ce7", "#62c400"] },
    { id: "coastal", title: "Coastal", subtitle: "Blue-green focus with a sunlit accent.", colors: ["#1490ad", "#1261a3", "#fabe2e"] },
    { id: "ember", title: "Ember", subtitle: "Warm, loud, and built for urgency.", colors: ["#ed4f1f", "#fa9429", "#592014"] },
    { id: "orchard", title: "Orchard", subtitle: "Fresh greens with a calm workday feel.", colors: ["#338f47", "#8fae3d", "#f2a62e"] },
    { id: "midnight", title: "Midnight", subtitle: "Deep blue accents with electric highlights.", colors: ["#2e3bbc", "#2ca6e0", "#e6c738"] },
    { id: "shift", title: "shift", subtitle: "Bold red, dark ink, clean white, and electric lime.", colors: ["#b50000", "#252525", "#c6f91f"] },
  ];
  const selectedTheme = themes.find((theme) => theme.id === preferences.theme) ?? themes[0];
  return <div className="settings-control-stack">
    <SettingsCard title="Appearance mode" icon="sun"><div className="settings-choice-grid settings-choice-grid-three">{([ ["system", "System", "sun"], ["light", "Light", "sun"], ["dark", "Dark", "moon"] ] as const).map(([id, label, icon]) => <ChoiceButton key={id} selected={preferences.appearance === id} onClick={() => setPreferences("appearance", id)}><Icon name={icon} size={18} /><span>{label}</span></ChoiceButton>)}</div><p className="settings-note">System follows the browser appearance preference.</p></SettingsCard>
    <SettingsCard title="Selected look" icon="paint-palette"><div className="settings-selected-look"><div><strong>{selectedTheme.title}</strong><p>{selectedTheme.subtitle}</p></div><ThemeSwatches colors={selectedTheme.colors} /></div><div className="settings-theme-grid">{themes.map((theme) => <button className={preferences.theme === theme.id ? "settings-theme-card settings-theme-selected" : "settings-theme-card"} key={theme.id} type="button" aria-pressed={preferences.theme === theme.id} onClick={() => setPreferences("theme", theme.id)}><ThemeSwatches colors={theme.colors} /><span className="settings-theme-title"><strong>{theme.title}</strong>{preferences.theme === theme.id ? <Icon name="check" size={15} /> : null}</span><small>{theme.subtitle}</small></button>)}</div></SettingsCard>
  </div>;
}

function BehaviorSettings({ preferences, setPreferences, userID, setMessage }: SettingsSharedProps & { userID: string | null }) {
  const ordering: Array<[SortOption, string]> = [["dueDate", "Due Date"], ["created", "Created"], ["tag", "By Tag"]];
  const grouping: Array<[SortOption, string]> = [["dueMonth", "Due by Month"], ["tagSections", "Tag Sections"], ["nanoDos", "Most NanoDos"]];
  const [calendarFeedURL, setCalendarFeedURL] = useState<string | null>(null);
  const [isCalendarBusy, setIsCalendarBusy] = useState(false);
  async function toggleCalendar(enabled: boolean) {
    if (!enabled) {
      setIsCalendarBusy(true);
      try {
        if (userID) await revokeCalendarFeed();
        setPreferences("calendarMirror", false);
        setCalendarFeedURL(null);
        setMessage("Calendar feed disabled.");
      } catch (error) {
        setMessage(error instanceof Error ? error.message : "The calendar feed could not be disabled.");
      } finally {
        setIsCalendarBusy(false);
      }
      return;
    }
    if (!userID) {
      setMessage("Sign in to create a private calendar feed.");
      return;
    }
    setIsCalendarBusy(true);
    try {
      const feedURL = await createCalendarFeedURL();
      setCalendarFeedURL(feedURL);
      setPreferences("calendarMirror", true);
      setMessage("Calendar feed created. Add its URL to your calendar app.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "The calendar feed could not be created.");
    } finally {
      setIsCalendarBusy(false);
    }
  }
  async function copyCalendarFeed() {
    if (!calendarFeedURL) return;
    try {
      await navigator.clipboard.writeText(calendarFeedURL);
      setMessage("Calendar feed URL copied.");
    } catch {
      setMessage("Copy is unavailable in this browser. Select the URL manually.");
    }
  }
  return <div className="settings-control-stack">
    <SettingsCard title="Order" icon="task-list"><ChoiceGroup label="Order" options={ordering} value={preferences.sort} onChange={(value) => setPreferences("sort", value)} /><ChoiceGroup label="Group" options={grouping} value={preferences.sort} onChange={(value) => setPreferences("sort", value)} /><SettingsSwitch icon="repeat" label="Reverse order" detail="Show the selected order in reverse." checked={preferences.sortReversed} onChange={(value) => setPreferences("sortReversed", value)} /></SettingsCard>
    <SettingsCard title="Timing" icon="clock"><ChoiceGroup label="Time Source" options={[["location", "Location"], ["device", "Device"]] as Array<[TimeSource, string]>} value={preferences.timeSource} onChange={(value) => setPreferences("timeSource", value)} /><div className="settings-input-row"><span><label htmlFor="default-due-time"><strong>Default Due Time</strong></label><small>Used when a due date is chosen without a time.</small></span><input id="default-due-time" type="time" value={preferences.dueTime} onChange={(event) => setPreferences("dueTime", event.target.value)} /></div></SettingsCard>
    <SettingsCard title="Remove from View" icon="archive"><ChoiceGroup label="Remove Action" options={[["archive", "Move to Archives"], ["trash", "Move to Trash"]] as Array<[RemoveAction, string]>} value={preferences.removeAction} onChange={(value) => setPreferences("removeAction", value)} /></SettingsCard>
    <SettingsCard title="Calendar" icon="calendar"><SettingsSwitch icon="calendar" label="Add Due toDōs to Calendar" detail="Creates a private calendar feed that Apple Calendar, Google Calendar, and Outlook can subscribe to." checked={preferences.calendarMirror} onChange={(value) => void toggleCalendar(value)} /><div className="settings-calendar-feed"><p>Calendar feeds refresh from your account and contain active ToDos with due dates.</p>{calendarFeedURL ? <><code>{calendarFeedURL}</code><button className="settings-quiet-action" type="button" disabled={isCalendarBusy} onClick={() => void copyCalendarFeed()}><Icon name="copy" size={15} /> Copy Calendar Feed URL</button></> : null}</div></SettingsCard>
  </div>;
}

function NotificationsSettings({ preferences, setPreferences, setMessage, userID }: SettingsSharedProps & { userID: string | null }) {
  const [permission, setPermission] = useState<NotificationPermission>("default");
  useEffect(() => {
    if (typeof Notification !== "undefined") window.setTimeout(() => setPermission(Notification.permission), 0);
  }, []);
  useEffect(() => {
    if (!userID) return;
    let active = true;
    const timer = window.setTimeout(() => {
      void loadWebNotificationPreferences(userID).then((remote) => {
        if (!active || !remote) return;
        setPreferences("reminderAlerts", remote.web_reminders_enabled);
        setPreferences("notificationSound", remote.web_reminder_sound as NotificationSound);
        setPreferences("customSoundName", remote.web_custom_sound_name ?? "");
        setPreferences("completionSound", remote.web_completion_sound as CompletionSound);
        setPreferences("badgePolicy", remote.web_badge_policy as BadgePolicy);
        if (isSnoozeOptions(remote.web_snooze_options)) setPreferences("snooze", remote.web_snooze_options);
      }).catch(() => { /* Local defaults remain available if the optional row is not present yet. */ });
    }, 0);
    return () => { active = false; window.clearTimeout(timer); };
  }, [setPreferences, userID]);
  function updateNotificationPreference<K extends keyof SettingsPreferences>(key: K, value: SettingsPreferences[K], patch: WebNotificationPreferencePatch) {
    setPreferences(key, value);
    if (userID) void saveWebNotificationPreferences(userID, patch).catch((error) => setMessage(error instanceof Error ? error.message : "Notification preferences could not be saved."));
  }
  async function requestPermission() {
    if (typeof Notification === "undefined") { setMessage("This browser does not support web notifications."); return; }
    try {
      const nextPermission = await Notification.requestPermission();
      setPermission(nextPermission);
      const enabled = nextPermission === "granted";
      updateNotificationPreference("reminderAlerts", enabled, { web_reminders_enabled: enabled });
      if (enabled && userID) {
        try {
          await registerWebPushSubscription(userID);
          setMessage("Background reminder delivery is connected on this browser.");
        } catch (error) {
          setMessage(error instanceof Error ? error.message : "Browser permission was allowed, but Web Push could not be connected.");
        }
      } else {
        setMessage(enabled ? "Reminder alerts are allowed on this browser." : "Reminder alerts remain off.");
      }
    } catch {
      setMessage("This browser did not allow notification permission to be requested.");
    }
  }
  const snooze = preferences.snooze;
  return <div className="settings-control-stack">
    <SettingsCard title="Reminder Alerts" icon="bell"><div className="settings-status-banner"><span className="settings-status-icon"><Icon name="bell" size={18} /></span><div><strong>{permission === "granted" ? "Allowed" : permission === "denied" ? "Blocked" : "Not requested"}</strong><p>Web push permission controls whether this browser can receive background reminder delivery.</p></div></div><button className="settings-detail-action" type="button" onClick={() => void requestPermission()}><Icon name="bell" size={16} /><span>{permission === "granted" ? "Refresh permission" : "Allow reminder alerts"}</span></button></SettingsCard>
    <SettingsCard title="Sounds" icon="speaker"><ChoiceGroup label="Reminder Sound" options={[["default", "Default"], ["silent", "Silent"], ["soft", "Soft Chime"], ["bright", "Bright Ping"], ["urgent", "Urgent Double"], ["custom", "Custom"]] as Array<[NotificationSound, string]>} value={preferences.notificationSound} onChange={(value) => updateNotificationPreference("notificationSound", value, { web_reminder_sound: value })} />{preferences.notificationSound === "custom" ? <label className="settings-file-action" htmlFor="custom-reminder-sound"><Icon name="speaker" size={16} /><span>{preferences.customSoundName || "Choose a reminder sound"}</span><input id="custom-reminder-sound" className="sr-only" type="file" accept="audio/*" onChange={(event) => { const name = event.target.files?.[0]?.name ?? ""; updateNotificationPreference("customSoundName", name, { web_custom_sound_name: name || null }); }} /></label> : null}<ChoiceGroup label="Completion Sound" options={[["off", "Off"], ["soft", "Soft"], ["bright", "Bright"]] as Array<[CompletionSound, string]>} value={preferences.completionSound} onChange={(value) => updateNotificationPreference("completionSound", value, { web_completion_sound: value })} /><div className="settings-guide-chips"><span><Icon name="bell" size={13} /> Due</span><span><Icon name="flame" size={13} /> Time-Sensitive</span><span><Icon name="speaker" size={13} /> Quiet</span></div></SettingsCard>
    <SettingsCard title="Badge" icon="check"><ChoiceGroup label="App badge" options={[["off", "Off"], ["active", "Active ToDos"], ["dueToday", "Due Today"], ["overdue", "Overdue"], ["timeSensitive", "Time-Sensitive"], ["scheduled", "Scheduled"]] as Array<[BadgePolicy, string]>} value={preferences.badgePolicy} onChange={(value) => updateNotificationPreference("badgePolicy", value, { web_badge_policy: value })} /></SettingsCard>
    <SettingsCard title="Snooze Options" icon="clock"><SnoozeGroup title="Minutes" values={[5, 10, 15, 30, 60]} selected={snooze.minutes} onChange={(value) => updateNotificationPreference("snooze", { ...snooze, minutes: value }, { web_snooze_options: { ...snooze, minutes: value } })} /><SnoozeGroup title="Hours" values={[1, 2, 4, 8]} selected={snooze.hours} onChange={(value) => updateNotificationPreference("snooze", { ...snooze, hours: value }, { web_snooze_options: { ...snooze, hours: value } })} /><SnoozeGroup title="Days" values={[1, 2, 3, 7]} selected={snooze.days} onChange={(value) => updateNotificationPreference("snooze", { ...snooze, days: value }, { web_snooze_options: { ...snooze, days: value } })} /><button className="settings-quiet-action" type="button" onClick={() => updateNotificationPreference("snooze", defaultPreferences.snooze, { web_snooze_options: defaultPreferences.snooze })}><Icon name="reset" size={15} /> Reset Snooze Options</button></SettingsCard>
  </div>;
}

function TagsSettings({ snapshot, isLoading, error, userID, runAction, preferences, setPreferences }: { snapshot: RemoteSnapshot | null; isLoading: boolean; error: string | null; userID: string | null; runAction: (action: () => Promise<void>, successMessage: string) => Promise<void>; preferences: SettingsPreferences; setPreferences: SettingsSharedProps["setPreferences"] }) {
  const [name, setName] = useState("");
  const [isAdding, setIsAdding] = useState(false);
  const usedTagIDs = useMemo(() => new Set((snapshot?.todoTags ?? []).map((relation) => relation.tag_id)), [snapshot]);
  const unusedTags = (snapshot?.tags ?? []).filter((tag) => !tag.is_default && !usedTagIDs.has(tag.id));
  async function addTag(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!userID || !name.trim()) return;
    setIsAdding(true);
    await runAction(async () => { await createTag(name, userID); setName(""); }, "Tag added to your library.");
    setIsAdding(false);
  }
  return <div className="settings-control-stack">
    <SettingsCard title="Defaults" icon="tag"><SettingsSwitch icon="tag" label="Show Tags While Creating" detail="Show the tag field when creating a toDō." checked={preferences.tagsByDefault} onChange={(value) => setPreferences("tagsByDefault", value)} /><p className="settings-note">This preference is stored on this browser and will be used by the Web composer.</p></SettingsCard>
    <SettingsCard title="Library" icon="tag">{isLoading ? <p className="settings-note">Loading your tags…</p> : null}{error ? <p className="settings-inline-error">{error}</p> : null}{snapshot ? <><div className="settings-tag-cloud">{snapshot.tags.map((tag) => <TagChip key={tag.id} tag={tag} isUsed={usedTagIDs.has(tag.id)} onDelete={() => void runAction(() => deleteTag(tag.id), "Tag removed from your library.")} />)}</div><form className="settings-add-form" onSubmit={(event) => void addTag(event)}><label htmlFor="new-tag">New tag</label><div><input id="new-tag" value={name} onChange={(event) => setName(event.target.value)} placeholder="e.g. errands" /><button className="settings-icon-submit" type="submit" aria-label="Add tag" disabled={isAdding || !name.trim()}><Icon name="plus" size={17} /></button></div></form><button className="settings-quiet-action" type="button" disabled={!unusedTags.length} onClick={() => void runAction(() => Promise.all(unusedTags.map((tag) => deleteTag(tag.id))).then(() => undefined), `${unusedTags.length} unused tag${unusedTags.length === 1 ? "" : "s"} removed.`)}><Icon name="tag" size={15} /> Remove Unused Tags <span>{unusedTags.length}</span></button></> : <p className="settings-note">Sign in with a connected Supabase account to manage tags.</p>}</SettingsCard>
  </div>;
}

function DataSettings({ snapshot, isLoading, userID, runAction, signOut, setMessage, setPreferences }: { snapshot: RemoteSnapshot | null; isLoading: boolean; userID: string | null; runAction: (action: () => Promise<void>, successMessage: string) => Promise<void>; signOut: () => Promise<void>; setMessage: (message: string) => void; setPreferences: SettingsSharedProps["setPreferences"] }) {
  const [isDeletingAccount, setIsDeletingAccount] = useState(false);
  const [exported, setExported] = useState(false);
  function exportData() {
    if (!snapshot) return;
    const file = new Blob([JSON.stringify(snapshot, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(file); const anchor = document.createElement("a"); anchor.href = url; anchor.download = `todo-export-${new Date().toISOString().slice(0, 10)}.json`; anchor.click(); URL.revokeObjectURL(url); setExported(true);
  }
  async function resetData() {
    if (!userID || !window.confirm("Delete every personal toDō and NanoDo from this account? This cannot be undone.")) return;
    await runAction(() => deleteTodosForUser(userID), "Your personal ToDos were deleted.");
  }
  async function deleteAccount() {
    if (!supabase || !window.confirm("Permanently delete your account, profile, shared lists, purchases, and all account data? This cannot be undone.")) return;
    setIsDeletingAccount(true);
    try { const { error } = await supabase.functions.invoke("delete-account", { body: {} }); if (error) throw error; await signOut(); window.location.assign("/"); } catch (error) { setIsDeletingAccount(false); setMessage(error instanceof Error ? error.message : "Account deletion could not be completed."); }
  }
  return <div className="settings-control-stack">
    <SettingsCard title="Export" icon="download"><SettingsList items={[["Account export", "Download your current ToDos, NanoDos, tags, and Collabs as JSON."]]} /><button className="settings-detail-action" type="button" disabled={isLoading || !snapshot} onClick={exportData}><Icon name="download" size={16} /><span>{exported ? "Export downloaded" : "Export account data"}</span></button></SettingsCard>
    <SettingsCard title="Preferences" icon="reset"><SettingsList items={[["Reset Choices", "Restore Web sorting, tag entry, timing, notification, and appearance choices."]]} /><button className="settings-quiet-action" type="button" onClick={() => { (Object.keys(defaultPreferences) as Array<keyof SettingsPreferences>).forEach((key) => setPreferences(key, defaultPreferences[key])); }}><Icon name="reset" size={15} /> Reset Choices</button></SettingsCard>
    <SettingsCard title="Start Fresh" icon="trash"><SettingsList items={[["Reset toDō Data", "Permanently delete personal ToDos and NanoDos without deleting your account, tags, or purchases."]]} /><button className="settings-danger-action" type="button" disabled={isLoading} onClick={() => void resetData()}><Icon name="trash" size={16} /> Reset toDō Data</button></SettingsCard>
    <SettingsCard title="Delete Account" icon="alert"><SettingsList items={[["Permanent deletion", "Deletes your profile, personal ToDos, owned shared lists, collaboration access, and account-linked purchases."]]} /><button className="settings-danger-action" type="button" disabled={isDeletingAccount} onClick={() => void deleteAccount()}><Icon name="alert" size={16} /> {isDeletingAccount ? "Deleting account…" : "Delete Account"}</button></SettingsCard>
  </div>;
}

function ArchivesSettings({ snapshot, isLoading, error, runAction }: { snapshot: RemoteSnapshot | null; isLoading: boolean; error: string | null; runAction: (action: () => Promise<void>, successMessage: string) => Promise<void> }) {
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const completed = (snapshot?.todos ?? []).filter((todo) => todo.is_done && todo.lifecycle_state !== "trashed");
  const archived = (snapshot?.todos ?? []).filter((todo) => todo.lifecycle_state === "archived");
  const items = [...completed, ...archived].filter((todo, index, list) => list.findIndex((candidate) => candidate.id === todo.id) === index);
  async function deleteSelected() { if (!selected.size || !window.confirm("Permanently delete the selected archived ToDos?")) return; await runAction(() => Promise.all([...selected].map((id) => deleteTodoPermanently(id))).then(() => undefined), "Selected archived ToDos were deleted."); setSelected(new Set()); }
  return <div className="settings-control-stack"><SettingsCard title="Completed" icon="check">{isLoading ? <p className="settings-note">Loading your archives…</p> : null}{error ? <p className="settings-inline-error">{error}</p> : null}{!isLoading && !items.length ? <EmptySettingsState icon="archive" title="Archives are empty" detail="Completed and archived ToDos will appear here." /> : null}{items.length ? <ArchiveList items={items} selected={selected} setSelected={setSelected} runAction={runAction} /> : null}{selected.size ? <button className="settings-danger-action" type="button" onClick={() => void deleteSelected()}><Icon name="trash" size={16} /> Delete selected ({selected.size})</button> : null}</SettingsCard></div>;
}

function TrashSettings({ snapshot, isLoading, error, preferences, setPreferences, runAction }: { snapshot: RemoteSnapshot | null; isLoading: boolean; error: string | null; preferences: SettingsPreferences; setPreferences: SettingsSharedProps["setPreferences"]; runAction: (action: () => Promise<void>, successMessage: string) => Promise<void> }) {
  const items = (snapshot?.todos ?? []).filter((todo) => todo.lifecycle_state === "trashed");
  async function emptyTrash() { if (!items.length || !window.confirm("Permanently delete every item in the trash? This cannot be undone.")) return; await runAction(() => Promise.all(items.map((todo) => deleteTodoPermanently(todo.id))).then(() => undefined), "Trash emptied."); }
  return <div className="settings-control-stack"><SettingsCard title="Auto-Empty Trash" icon="trash"><ChoiceGroup label="Delete after" options={[["1 Week", "1 Week"], ["2 Weeks", "2 Weeks"], ["1 Month", "1 Month"], ["3 Months", "3 Months"], ["Never", "Never"]] as Array<[SettingsPreferences["trashAutoEmpty"], string]>} value={preferences.trashAutoEmpty} onChange={(value) => setPreferences("trashAutoEmpty", value)} /><p className="settings-note">Deleted ToDos are permanently removed after this interval.</p></SettingsCard><SettingsCard title="Recently Deleted" icon="trash">{isLoading ? <p className="settings-note">Loading your trash…</p> : null}{error ? <p className="settings-inline-error">{error}</p> : null}{!isLoading && !items.length ? <EmptySettingsState icon="trash" title="Trash is empty" detail={`Items will be permanently deleted after ${preferences.trashAutoEmpty.toLowerCase()}.`} /> : null}{items.length ? <TrashList items={items} runAction={runAction} /> : null}{items.length ? <button className="settings-danger-action" type="button" onClick={() => void emptyTrash()}><Icon name="trash" size={16} /> Empty Trash Now</button> : null}</SettingsCard></div>;
}

function TourSettings() {
  return <div className="settings-control-stack"><SettingsCard title="The Web flow" icon="sparkles"><div className="settings-tour-steps"><TourStep number="01" icon="plus" title="Capture" detail="Start from Home with New toDō." /><TourStep number="02" icon="task-list" title="Review" detail="Open a ToDo from Up next or ToDos." /><TourStep number="03" icon="check" title="Continue" detail="Complete it, keep it active, or send it to Archives." /></div><Link className="settings-detail-action" href="/todos"><Icon name="task-list" size={16} /><span>Open ToDos</span></Link></SettingsCard></div>;
}

type SettingsSharedProps = { preferences: SettingsPreferences; setPreferences: <K extends keyof SettingsPreferences>(key: K, value: SettingsPreferences[K]) => void; isBusy: boolean; setMessage: (message: string) => void };

function SettingsCard({ title, icon, children }: { title: string; icon: IconName; children: ReactNode }) { const id = `${title.replace(/\s+/g, "-").toLowerCase()}-heading`; return <section className="settings-control-card" aria-labelledby={id}><div className="settings-control-heading"><span className="settings-control-heading-icon"><Icon name={icon} size={17} /></span><h2 id={id}>{title}</h2></div>{children}</section>; }
function SettingsSwitch({ icon, label, detail, checked, onChange }: { icon: IconName; label: string; detail: string; checked: boolean; onChange: (value: boolean) => void }) { return <button className="settings-switch" type="button" role="switch" aria-checked={checked} onClick={() => onChange(!checked)}><span className="settings-switch-icon"><Icon name={icon} size={16} /></span><span className="settings-switch-copy"><strong>{label}</strong><small>{detail}</small></span><span className={checked ? "settings-switch-control settings-switch-on" : "settings-switch-control"}><span /></span></button>; }
function ChoiceGroup<T extends string>({ label, options, value, onChange }: { label: string; options: Array<[T, string]>; value: T; onChange: (value: T) => void }) { return <div className="settings-choice-group"><span className="settings-choice-label">{label}</span><div className="settings-choice-list">{options.map(([option, title]) => <ChoiceButton key={option} selected={value === option} onClick={() => onChange(option)}>{title}</ChoiceButton>)}</div></div>; }
function ChoiceButton({ selected, onClick, children }: { selected: boolean; onClick: () => void; children: ReactNode }) { return <button className={selected ? "settings-choice settings-choice-selected" : "settings-choice"} type="button" aria-pressed={selected} onClick={onClick}>{children}</button>; }
function SettingsList({ items }: { items: Array<[string, string]> }) { return <div className="settings-info-list">{items.map(([title, detail]) => <div className="settings-info-row" key={title}><strong>{title}</strong><span>{detail}</span></div>)}</div>; }
function ThemeSwatches({ colors }: { colors: string[] }) { return <span className="settings-theme-swatches">{colors.map((color) => <i key={color} style={{ backgroundColor: color }} />)}</span>; }
function SnoozeGroup({ title, values, selected, onChange }: { title: string; values: number[]; selected: number[]; onChange: (values: number[]) => void }) { return <div className="settings-snooze-group"><span className="settings-choice-label">{title}</span><div className="settings-choice-list">{values.map((value) => { const isSelected = selected.includes(value); return <ChoiceButton key={value} selected={isSelected} onClick={() => onChange(isSelected ? selected.filter((item) => item !== value) : [...selected, value].sort((a, b) => a - b))}>{value} {title.toLowerCase().replace(/s$/, "")}{value === 1 ? "" : "s"}</ChoiceButton>; })}</div></div>; }
function TagChip({ tag, isUsed, onDelete }: { tag: Tag; isUsed: boolean; onDelete: () => void }) { return <span className="settings-tag-chip"><Icon name="tag" size={14} /><strong>{tag.name}</strong><small>{tag.is_default ? "Default" : isUsed ? "In use" : "Unused"}</small>{!tag.is_default ? <button type="button" aria-label={`Remove ${tag.name}`} onClick={onDelete}><Icon name="close" size={13} /></button> : null}</span>; }
function EmptySettingsState({ icon, title, detail }: { icon: IconName; title: string; detail: string }) { return <div className="settings-empty-state"><Icon name={icon} size={30} /><strong>{title}</strong><span>{detail}</span></div>; }
function ArchiveList({ items, selected, setSelected, runAction }: { items: Todo[]; selected: Set<string>; setSelected: (selected: Set<string>) => void; runAction: (action: () => Promise<void>, successMessage: string) => Promise<void> }) { return <div className="settings-record-list">{items.map((todo) => { const isSelected = selected.has(todo.id); return <div className="settings-record-row" key={todo.id}><button className="settings-record-select" type="button" aria-label={`${isSelected ? "Deselect" : "Select"} ${todo.task}`} aria-pressed={isSelected} onClick={() => { const next = new Set(selected); if (isSelected) next.delete(todo.id); else next.add(todo.id); setSelected(next); }}><Icon name={isSelected ? "check" : "task-list"} size={17} /></button><span className="settings-record-copy"><strong>{todo.task}</strong><small>{todo.lifecycle_state === "archived" ? "Archived" : "Completed"}{todo.updated_at ? ` · ${formatRecordDate(todo.updated_at)}` : ""}</small></span><button className="settings-record-action" type="button" onClick={() => void runAction(() => updateTodoLifecycle(todo.id, "active"), "ToDo restored to the active list.")}><Icon name="reset" size={16} /><span>Restore</span></button></div>; })}</div>; }
function TrashList({ items, runAction }: { items: Todo[]; runAction: (action: () => Promise<void>, successMessage: string) => Promise<void> }) { return <div className="settings-record-list">{items.map((todo) => <div className="settings-record-row" key={todo.id}><span className="settings-record-icon"><Icon name="trash" size={17} /></span><span className="settings-record-copy"><strong>{todo.task}</strong><small>{todo.trashed_at ? `Deleted ${formatRecordDate(todo.trashed_at)}` : "Recently deleted"}</small></span><span className="settings-record-actions"><button className="settings-record-action" type="button" onClick={() => void runAction(() => updateTodoLifecycle(todo.id, "active"), "ToDo restored to the active list.")}><Icon name="reset" size={16} /><span>Restore</span></button><button className="settings-record-delete" type="button" aria-label={`Delete ${todo.task} permanently`} onClick={() => { if (window.confirm(`Permanently delete “${todo.task}”?`)) void runAction(() => deleteTodoPermanently(todo.id), "ToDo permanently deleted."); }}><Icon name="trash" size={16} /></button></span></div>)}</div>; }
function TourStep({ number, icon, title, detail }: { number: string; icon: IconName; title: string; detail: string }) { return <div className="settings-tour-step"><span className="settings-tour-number">{number}</span><span className="settings-tour-icon"><Icon name={icon} size={17} /></span><span><strong>{title}</strong><small>{detail}</small></span></div>; }
function formatRecordDate(value: string) { return new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric" }).format(new Date(value)); }
function isSnoozeOptions(value: unknown): value is SettingsPreferences["snooze"] {
  if (!value || typeof value !== "object") return false;
  const options = value as Partial<SettingsPreferences["snooze"]>;
  return [options.minutes, options.hours, options.days].every((values) => Array.isArray(values) && values.every((item) => typeof item === "number"));
}

function useSettingsPreferences(): [SettingsPreferences, <K extends keyof SettingsPreferences>(key: K, value: SettingsPreferences[K]) => void] {
  const [preferences, setPreferencesState] = useState<SettingsPreferences>(defaultPreferences);
  const [isHydrated, setIsHydrated] = useState(false);
  useEffect(() => { window.setTimeout(() => { try { const stored = window.localStorage.getItem(settingsStorageKey); if (stored) setPreferencesState({ ...defaultPreferences, ...JSON.parse(stored) }); } catch { /* Use defaults when local storage is unavailable. */ } setIsHydrated(true); }, 0); }, []);
  useEffect(() => { if (!isHydrated) return; window.localStorage.setItem(settingsStorageKey, JSON.stringify(preferences)); document.documentElement.dataset.todoTheme = preferences.theme; if (preferences.appearance === "system") delete document.documentElement.dataset.todoAppearance; else document.documentElement.dataset.todoAppearance = preferences.appearance; }, [isHydrated, preferences]);
  const setPreference = useCallback(<K extends keyof SettingsPreferences>(key: K, value: SettingsPreferences[K]) => { setPreferencesState((current) => ({ ...current, [key]: value })); }, []);
  return [preferences, setPreference];
}

function useSettingsSnapshot(enabled: boolean) {
  const [snapshot, setSnapshot] = useState<RemoteSnapshot | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const refresh = useCallback(async () => { if (!enabled) return; setIsLoading(true); try { setSnapshot(await loadRemoteSnapshot()); setError(null); } catch (loadError) { setError(loadError instanceof Error ? loadError.message : "Your synced Settings data could not be loaded."); } finally { setIsLoading(false); } }, [enabled]);
  useEffect(() => {
    if (!enabled) return;
    let active = true;
    window.setTimeout(() => { if (active) setIsLoading(true); }, 0);
    void loadRemoteSnapshot().then((nextSnapshot) => {
      if (!active) return;
      setSnapshot(nextSnapshot);
      setError(null);
    }).catch((loadError) => {
      if (active) setError(loadError instanceof Error ? loadError.message : "Your synced Settings data could not be loaded.");
    }).finally(() => {
      if (active) setIsLoading(false);
    });
    return () => { active = false; };
  }, [enabled]);
  return { snapshot, isLoading, error, refresh };
}
