export type ThemeName = "classic" | "coastal" | "ember" | "orchard" | "midnight" | "shift";
export type AppearanceMode = "system" | "light" | "dark";
export type SortOption = "position" | "due" | "newest";
export type GroupOption = "none" | "due" | "collab";
export type TimeSource = "location" | "device";
export type RemoveAction = "archive" | "trash";
export type NotificationSound = "default" | "silent" | "soft" | "bright" | "urgent" | "custom";
export type CompletionSound = "off" | "soft" | "bright";
export type BadgePolicy = "off" | "active" | "dueToday" | "overdue" | "timeSensitive" | "scheduled";
export type TrashAutoEmpty = "1 Week" | "2 Weeks" | "1 Month" | "3 Months" | "Never";

export type WebPreferences = {
  theme: ThemeName;
  appearance: AppearanceMode;
  sort: SortOption;
  group: GroupOption;
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
  trashAutoEmpty: TrashAutoEmpty;
  matchDeletes: boolean;
};

export const webPreferencesStorageKey = "todo.web.settings.v2";
export const webPreferencesChangedEvent = "todo-web-preferences-changed";

export const defaultWebPreferences: WebPreferences = {
  theme: "classic",
  appearance: "system",
  sort: "position",
  group: "none",
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

const validThemes = new Set<ThemeName>([
  "classic",
  "coastal",
  "ember",
  "orchard",
  "midnight",
  "shift",
]);
const validAppearanceModes = new Set<AppearanceMode>(["system", "light", "dark"]);
const validTimeSources = new Set<TimeSource>(["location", "device"]);
const validRemoveActions = new Set<RemoveAction>(["archive", "trash"]);
const validNotificationSounds = new Set<NotificationSound>([
  "default",
  "silent",
  "soft",
  "bright",
  "urgent",
  "custom",
]);
const validCompletionSounds = new Set<CompletionSound>(["off", "soft", "bright"]);
const validBadgePolicies = new Set<BadgePolicy>([
  "off",
  "active",
  "dueToday",
  "overdue",
  "timeSensitive",
  "scheduled",
]);
const validTrashAutoEmpty = new Set<TrashAutoEmpty>([
  "1 Week",
  "2 Weeks",
  "1 Month",
  "3 Months",
  "Never",
]);

export function readStoredWebPreferences(): WebPreferences {
  if (typeof window === "undefined") return cloneDefaults();

  try {
    const stored = window.localStorage.getItem(webPreferencesStorageKey);
    if (!stored) return cloneDefaults();

    const parsed = JSON.parse(stored) as Partial<WebPreferences> & {
      sort?: unknown;
      group?: unknown;
    };
    return normalizeWebPreferences(parsed);
  } catch {
    return cloneDefaults();
  }
}

export function saveStoredWebPreferences(preferences: WebPreferences) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(webPreferencesStorageKey, JSON.stringify(preferences));
    window.dispatchEvent(new Event(webPreferencesChangedEvent));
  } catch {
    // Device-local preferences are optional; the current in-memory value still applies.
  }
}

export function normalizeWebPreferences(
  value: Partial<Omit<WebPreferences, "sort" | "group">> & {
    sort?: unknown;
    group?: unknown;
  },
): WebPreferences {
  const legacySort = value.sort === "dueDate"
    ? "due"
    : value.sort === "created"
      ? "newest"
      : value.sort === "position" || value.sort === "due" || value.sort === "newest"
        ? value.sort
        : defaultWebPreferences.sort;
  const legacyGroup = value.group === "dueMonth" || value.group === "tagSections"
    ? "due"
    : value.group === "nanoDos"
      ? "collab"
      : value.group === "none" || value.group === "due" || value.group === "collab"
        ? value.group
        : defaultWebPreferences.group;

  return {
    ...cloneDefaults(),
    ...value,
    theme: validThemes.has(value.theme as ThemeName) ? value.theme as ThemeName : defaultWebPreferences.theme,
    appearance: validAppearanceModes.has(value.appearance as AppearanceMode) ? value.appearance as AppearanceMode : defaultWebPreferences.appearance,
    sort: legacySort,
    group: legacyGroup,
    sortReversed: typeof value.sortReversed === "boolean" ? value.sortReversed : defaultWebPreferences.sortReversed,
    timeSource: validTimeSources.has(value.timeSource as TimeSource) ? value.timeSource as TimeSource : defaultWebPreferences.timeSource,
    dueTime: typeof value.dueTime === "string" && /^\d{2}:\d{2}$/.test(value.dueTime) ? value.dueTime : defaultWebPreferences.dueTime,
    removeAction: validRemoveActions.has(value.removeAction as RemoveAction) ? value.removeAction as RemoveAction : defaultWebPreferences.removeAction,
    calendarMirror: typeof value.calendarMirror === "boolean" ? value.calendarMirror : defaultWebPreferences.calendarMirror,
    tagsByDefault: typeof value.tagsByDefault === "boolean" ? value.tagsByDefault : defaultWebPreferences.tagsByDefault,
    reminderAlerts: typeof value.reminderAlerts === "boolean" ? value.reminderAlerts : defaultWebPreferences.reminderAlerts,
    notificationSound: validNotificationSounds.has(value.notificationSound as NotificationSound) ? value.notificationSound as NotificationSound : defaultWebPreferences.notificationSound,
    customSoundName: typeof value.customSoundName === "string" ? value.customSoundName : defaultWebPreferences.customSoundName,
    completionSound: validCompletionSounds.has(value.completionSound as CompletionSound) ? value.completionSound as CompletionSound : defaultWebPreferences.completionSound,
    badgePolicy: validBadgePolicies.has(value.badgePolicy as BadgePolicy) ? value.badgePolicy as BadgePolicy : defaultWebPreferences.badgePolicy,
    snooze: normalizeSnooze(value.snooze),
    trashAutoEmpty: validTrashAutoEmpty.has(value.trashAutoEmpty as TrashAutoEmpty) ? value.trashAutoEmpty as TrashAutoEmpty : defaultWebPreferences.trashAutoEmpty,
    matchDeletes: typeof value.matchDeletes === "boolean" ? value.matchDeletes : defaultWebPreferences.matchDeletes,
  };
}

function normalizeSnooze(value: WebPreferences["snooze"] | undefined) {
  if (!value || typeof value !== "object") return cloneDefaults().snooze;
  const clean = (values: unknown, fallback: number[]) =>
    Array.isArray(values)
      ? [...new Set(values.filter((item): item is number => typeof item === "number" && Number.isFinite(item) && item > 0))].sort((a, b) => a - b)
      : fallback;
  return {
    minutes: clean(value.minutes, defaultWebPreferences.snooze.minutes),
    hours: clean(value.hours, defaultWebPreferences.snooze.hours),
    days: clean(value.days, defaultWebPreferences.snooze.days),
  };
}

function cloneDefaults(): WebPreferences {
  return {
    ...defaultWebPreferences,
    snooze: {
      minutes: [...defaultWebPreferences.snooze.minutes],
      hours: [...defaultWebPreferences.snooze.hours],
      days: [...defaultWebPreferences.snooze.days],
    },
  };
}
