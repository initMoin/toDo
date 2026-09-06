import type { ReactNode, SVGProps } from "react";

export type IconName =
  | "alert"
  | "apple"
  | "archive"
  | "arrow-left"
  | "arrow-right"
  | "arrow-up-right"
  | "bar-chart"
  | "bell"
  | "bolt"
  | "calendar"
  | "chevron-down"
  | "chevron-up"
  | "check"
  | "clock"
  | "close"
  | "copy"
  | "filter"
  | "flame"
  | "download"
  | "edit"
  | "google"
  | "group"
  | "home"
  | "key"
  | "lock"
  | "location"
  | "mail"
  | "moon"
  | "paint-palette"
  | "plus"
  | "repeat"
  | "reset"
  | "search"
  | "shield"
  | "speaker"
  | "sparkles"
  | "sun"
  | "gear"
  | "sign-out"
  | "tag"
  | "task-list"
  | "trash"
  | "users";

const paths: Record<IconName, ReactNode> = {
  alert: <path d="M12 3.5 21 20H3L12 3.5Zm0 5.5v5m0 3.5h.01" />,
  apple: <path fill="currentColor" stroke="none" d="M15.7 12.3c0-2.1 1.7-3.1 1.8-3.2-1-1.5-2.5-1.7-3-1.8-1.3-.1-2.6.8-3.3.8-.7 0-1.7-.8-2.8-.8-1.4 0-2.8.9-3.5 2.1-1.5 2.6-.4 6.4 1 8.5.7 1 1.5 2 2.6 2 .9 0 1.4-.6 2.7-.6 1.3 0 1.7.6 2.7.6 1.1 0 1.8-1 2.5-2 .8-1.1 1.1-2.2 1.1-2.2-.1 0-1.8-.7-1.8-3.4Zm-2.2-6.4c.6-.7 1-1.6.9-2.5-.8 0-1.8.5-2.4 1.2-.5.6-1 1.5-.9 2.4.9.1 1.8-.4 2.4-1.1Z" />,
  archive: <path d="M4 7h16v13H4V7Zm-1-4h18v4H3V3Zm5 8h8" />,
  "arrow-left": <path d="m14.5 5-7 7 7 7M8 12h13" />,
  "arrow-right": <path d="M3 12h13m-6.5-7 7 7-7 7" />,
  "arrow-up-right": <path d="M7 17 17 7m-9 0h9v9" />,
  "bar-chart": <path d="M5 20V10m7 10V4m7 16v-7" />,
  bell: <path d="M6 10a6 6 0 0 1 12 0c0 6 2 6 2 8H4c0-2 2-2 2-8Zm4 11h4" />,
  bolt: <path d="m13.2 2.8-8 11h6.1l-.5 8.4 8-11h-6.1l.5-8.4Z" />,
  calendar: <path d="M6 3v3m12-3v3M4 9h16M5 5h14a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z" />,
  "chevron-down": <path d="m6 9 6 6 6-6" />,
  "chevron-up": <path d="m6 15 6-6 6 6" />,
  check: <path d="m5 12 4.5 4.5L19 7" />,
  clock: <path d="M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm0-14v5l3.5 2" />,
  close: <path d="m6 6 12 12M18 6 6 18" />,
  copy: <path d="M8 8h11v12H8V8Zm-3 8H4V4h11v4" />,
  filter: <path d="M4 5h16l-6.5 7.2v5.2l-3 1v-6.2L4 5Z" />,
  download: <path d="M12 3v12m0 0 4-4m-4 4-4-4M4 20h16" />,
  edit: <path d="m4 16.5-.8 3.3 3.3-.8L18.8 6.7a2.3 2.3 0 0 0-3.3-3.3L4 16.5Zm9.8-10.8 4.5 4.5" />,
  flame: <path d="M12.1 21c4.1 0 7-2.8 7-6.8 0-3.5-2-6.3-5.2-9.4.1 2.5-1 4.1-2.4 5.1-.3-2.2-1.6-4-3.4-5.1.2 3.1-2.3 5.1-2.3 8.5 0 4.4 2.7 7.7 6.3 7.7Z" />,
  google: <><path d="M20 12a8 8 0 1 1-2.3-5.7" /><path d="M20 12h-7" /></>,
  group: <path d="M8 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm8-1a2.5 2.5 0 1 0 0-5m-12 12a4 4 0 0 1 8 0m2 0a4 4 0 0 1 6 0" />,
  home: <path d="m3 10 9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1v-9Z" />,
  key: <path d="M14 10a4 4 0 1 0-7.7 1.7L3 15v3h3v-2h2v-2h2.3A4 4 0 0 0 14 10Zm0 0h7m-3 0v3m-3-3v2" />,
  lock: <path d="M6 10h12v10H6V10Zm3 0V7a3 3 0 0 1 6 0v3" />,
  location: <path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Zm-5 0a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />,
  mail: <path d="M4 6h16v12H4V6Zm0 1 8 6 8-6" />,
  moon: <path d="M20 15.5A8.5 8.5 0 0 1 8.5 4 8.5 8.5 0 1 0 20 15.5Z" />,
  "paint-palette": <path d="M12 4a8 8 0 1 0 0 16h1.2c1.2 0 1.8-1.5.9-2.3-.9-.8-.3-2.3.9-2.3H17a3 3 0 0 0 3-3A8.7 8.7 0 0 0 12 4ZM7.5 11h.01M9.5 7.5h.01M14 7.5h.01M16 11h.01" />,
  plus: <path d="M12 5v14M5 12h14" />,
  repeat: <path d="M17 2.5 20.5 6 17 9.5M4 6h16m-9 15.5L7.5 18 11 14.5M20 18H4" />,
  reset: <path d="M4 9a8 8 0 1 1 1.6 7.2M4 4v5h5" />,
  search: <path d="m20 20-4.5-4.5m2-4.5a6.5 6.5 0 1 1-13 0 6.5 6.5 0 0 1 13 0Z" />,
  shield: <path d="M12 3 20 6v6c0 4.6-3.1 7.7-8 9-4.9-1.3-8-4.4-8-9V6l8-3Zm-3 9 2 2 4-5" />,
  speaker: <path d="M4 10h4l5-4v12l-5-4H4v-4Zm12-2a5 5 0 0 1 0 8m2-10a8 8 0 0 1 0 12" />,
  sparkles: <path d="m12 3 1.2 4.8L18 9l-4.8 1.2L12 15l-1.2-4.8L6 9l4.8-1.2L12 3ZM19 15l.6 2.4L22 18l-2.4.6L19 21l-.6-2.4L16 18l2.4-.6L19 15Z" />,
  sun: <path d="M12 3v2m0 14v2M3 12h2m14 0h2M5.6 5.6 7 7m10 10 1.4 1.4M18.4 5.6 17 7M7 17l-1.4 1.4M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0Z" />,
  gear: <><path d="M9.7 3.7 10.4 2h3.2l.7 1.7 1.5.9 1.8-.4 2.3 2.3-.4 1.8.9 1.5 1.7.7v3.2l-1.7.7-.9 1.5.4 1.8-2.3 2.3-1.8-.4-1.5.9-.7 1.7h-3.2l-.7-1.7-1.5-.9-1.8.4-2.3-2.3.4-1.8-.9-1.5L2 13.7v-3.2l1.7-.7.9-1.5-.4-1.8 2.3-2.3 1.8.4 1.4-.9Z" /><circle cx="12" cy="12" r="3.2" /></>,
  "sign-out": <path d="M13 5H5a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h8m4-4 4-3-4-3m4 3H9" />,
  tag: <path d="M4 5v6l9 9 7-7-9-9H5a1 1 0 0 0-1 1Zm3 3h.01" />,
  "task-list": <path d="M8 6h11M8 12h11M8 18h11M4 6h.01M4 12h.01M4 18h.01" />,
  trash: <path d="M5 7h14m-9 4v6m4-6v6M9 3h6l1 4H8l1-4Zm-3 4 1 14h10l1-14" />,
  users: <path d="M16 20v-1.5a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4V20m6-9a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm5-5a2.5 2.5 0 0 1 0 5m1 4h.5a3.5 3.5 0 0 1 3.5 3.5V20" />,
};

export function Icon({
  name,
  size = 18,
  strokeWidth = 1.9,
  ...props
}: { name: IconName; size?: number; strokeWidth?: number } & Omit<SVGProps<SVGSVGElement>, "children">) {
  return (
    <svg
      aria-hidden="true"
      focusable="false"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      {...props}
    >
      {paths[name]}
    </svg>
  );
}
