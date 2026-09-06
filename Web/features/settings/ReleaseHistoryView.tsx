import { Icon } from "@/components/Icon";
import { webReleases } from "@/lib/webReleaseData";

export function ReleaseHistoryView() {
  return (
    <article className="settings-detail-shell release-history-shell" aria-labelledby="release-history-title">
      <h1 className="sr-only" id="release-history-title">release history</h1>
      <p className="release-history-intro">See what changed in toDō Web, release by release.</p>
      <div className="release-history-list">
        {webReleases.map((release) => (
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
