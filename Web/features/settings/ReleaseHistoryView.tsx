import { Icon } from "@/components/Icon";

const releases = [
  {
    version: "3.1",
    latest: true,
    notes: [
      "Added toDō+ membership and expanded personal Collab options.",
      "Added custom reminder sounds and improved completion feedback.",
      "Improved voice entry, NanoDo reminders, onboarding, and accessibility.",
      "Unified the experience across iPhone, iPad, Apple Watch, and Mac.",
      "And much more, shaped around the way you work.",
    ],
  },
  {
    version: "3.0.1",
    latest: false,
    notes: [
      "Improved sync reliability across devices.",
      "Refined notifications, widgets, Live Activities, and localization.",
      "Fixed stability and presentation issues reported after 3.0.",
    ],
  },
  {
    version: "3.0",
    latest: false,
    notes: [
      "Introduced Home, Momentum, and the redesigned toDō workflow.",
      "Added toDō Sync, Apple Watch, Mac, widgets, and Live Activities.",
      "Rebuilt the app around a consistent cross-platform design.",
    ],
  },
];

export function ReleaseHistoryView() {
  return (
    <article className="settings-detail-shell release-history-shell" aria-labelledby="release-history-title">
      <h1 className="sr-only" id="release-history-title">release history</h1>
      <p className="release-history-intro">See what changed, release by release.</p>
      <div className="release-history-list">
        {releases.map((release) => (
          <article className="release-entry" key={release.version}>
            <div className="release-entry-heading">
              <h2>{release.version}</h2>
              {release.latest ? <span>Latest</span> : null}
            </div>
            <ul>
              {release.notes.map((note) => (
                <li key={note}><Icon name="check" size={14} strokeWidth={2.4} /><span>{note}</span></li>
              ))}
            </ul>
          </article>
        ))}
      </div>
    </article>
  );
}
