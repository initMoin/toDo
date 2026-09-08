import type { ReactNode } from "react";
import { Icon } from "@/components/Icon";

export function StateCard({
  eyebrow,
  title,
  children,
  tone = "neutral",
  action,
}: {
  eyebrow?: string;
  title: string;
  children?: ReactNode;
  tone?: "neutral" | "warning" | "error" | "success";
  action?: ReactNode;
}) {
  return (
    <section className={`state-card state-card-${tone}`} aria-live="polite">
      <div className="state-card-icon" aria-hidden="true">
        <Icon name={tone === "error" ? "alert" : tone === "warning" ? "plus" : "task-list"} size={28} />
      </div>
      <div>
        {eyebrow ? <p className="eyebrow">{eyebrow}</p> : null}
        <h2>{title}</h2>
        {children ? <div className="state-card-copy">{children}</div> : null}
        {action ? <div className="state-card-action">{action}</div> : null}
      </div>
    </section>
  );
}

export function LoadingCard() {
  return (
    <section className="loading-card" aria-label="Loading toDōs" aria-busy="true">
      <span className="loading-line loading-line-short" />
      <span className="loading-line" />
      <span className="loading-line loading-line-meta" />
    </section>
  );
}
