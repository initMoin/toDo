import type { ReactNode } from "react";
import Link from "@/components/Link";

export function LegalShell({
  eyebrow,
  title,
  children,
}: {
  eyebrow: string;
  title: string;
  children: ReactNode;
}) {
  return (
    <main className="legal-page">
      <header className="legal-header">
        <Link className="wordmark" href="/" aria-label="toDō home"><span>toD</span><span className="wordmark-o">ō</span></Link>
      </header>
      <article className="legal-card">
        <p className="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        <p className="legal-updated">Last updated September 8, 2026</p>
        <div className="legal-copy">{children}</div>
      </article>
    </main>
  );
}
