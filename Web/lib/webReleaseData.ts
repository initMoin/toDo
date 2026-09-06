export type WebRelease = {
  version: string;
  latest?: boolean;
  notes: string[];
};

export const webReleases: WebRelease[] = [
  {
    version: "3.1 Web",
    latest: true,
    notes: [
      "Built the browser-native toDō Web foundation with TypeScript, Vinext, responsive routes, and Cloudflare Worker delivery.",
      "Added Apple and Google sign-in, username resolution, returning sessions, account-mismatch protection, and toDō+ access gating.",
      "Added ToDo creation and editing with notes, due dates, reminder intent, recurrence, Tags, NanoDos, and basic Collab assignment.",
      "Added completion, reopening, archive, trash, restore, permanent deletion, JSON export, reset, and account-deletion controls.",
      "Added Account/Profile, Settings subviews, onboarding, Web Push registration controls, and private calendar-feed controls.",
    ],
  },
];

export const webReleasePreview = webReleases[0].notes;
