"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
import { Icon, type IconName } from "@/components/Icon";
import { AccountSetupCard } from "@/features/auth/AccountSetupCard";
import { SignInCard } from "@/features/auth/SignInCard";
import { useAuth } from "@/features/auth/AuthProvider";
import { LoadingCard, StateCard } from "@/components/StateCard";
import {
  hasWebPlusAccess,
  isTodoDueSoon,
  isTodoOverdue,
  isTodoTimeSensitive,
  isVisibleActiveTodo,
  loadEntitlements,
  loadRemoteSnapshot,
} from "@/features/todos/data";
import type { RemoteSnapshot, Todo } from "@/lib/types";

type StatsState =
  | { status: "idle" | "loading" }
  | { status: "blocked" }
  | { status: "ready"; snapshot: RemoteSnapshot }
  | { status: "error"; message: string };

export function Stats() {
  const { user, isLoading: authLoading, isConfigured, isResolved } = useAuth();
  const [state, setState] = useState<StatsState>({ status: "idle" });
  const [retryKey, setRetryKey] = useState(0);

  useEffect(() => {
    let isCurrent = true;

    if (!isConfigured || authLoading || !user || !isResolved) {
      return () => {
        isCurrent = false;
      };
    }

    void (async () => {
      try {
        const entitlements = await loadEntitlements();
        if (!hasWebPlusAccess(entitlements)) {
          if (isCurrent) setState({ status: "blocked" });
          return;
        }

        const snapshot = await loadRemoteSnapshot();
        if (isCurrent) setState({ status: "ready", snapshot });
      } catch (error) {
        if (!isCurrent) return;
        setState({
          status: "error",
          message: error instanceof Error ? error.message : "Stats could not be loaded.",
        });
      }
    })();

    return () => {
      isCurrent = false;
    };
  }, [authLoading, isConfigured, isResolved, retryKey, user]);

  if (!isConfigured) {
    return <div className="state-layout"><StateCard eyebrow="Local setup" title="Connect Supabase to open Stats"><p>Add the browser-safe Supabase values to <code>Web/.env.local</code> and restart the local server.</p></StateCard></div>;
  }
  if (authLoading) {
    return <div className="state-layout"><LoadingCard /><p className="loading-message" aria-live="polite">Checking your toDō account…</p></div>;
  }
  if (!user) return <div className="auth-layout"><SignInCard /></div>;
  if (!isResolved) {
    return <div className="auth-layout"><AccountSetupCard /><p className="loading-message" aria-live="polite">Stats stays paused until this provider is resolved to a username.</p></div>;
  }
  if (state.status === "idle" || state.status === "loading") {
    return <div className="state-layout"><LoadingCard /><p className="loading-message" aria-live="polite">Loading your Stats…</p></div>;
  }
  if (state.status === "blocked") {
    return <div className="state-layout"><StateCard eyebrow="toDō+" title="Stats is part of toDō+" tone="warning"><p>Use the account with your active toDō+ entitlement to open Stats.</p></StateCard></div>;
  }
  if (state.status === "error") {
    return <div className="state-layout"><StateCard eyebrow="Sync" title="Stats could not be loaded" tone="error"><p>{state.message}</p><button className="primary-button" type="button" onClick={() => setRetryKey((value) => value + 1)}>Try again</button></StateCard></div>;
  }

  return <ReadyStats snapshot={state.snapshot} />;
}

function ReadyStats({ snapshot }: { snapshot: RemoteSnapshot }) {
  const stats = useMemo(() => buildStats(snapshot), [snapshot]);

  return (
    <section className="stats-shell" aria-labelledby="stats-title">
      <h1 className="sr-only" id="stats-title">stats</h1>
      <StatsHero stats={stats} />
      <section className="stats-focus-section" aria-labelledby="stats-focus-title">
        <h2 className="sr-only" id="stats-focus-title">Current focus</h2>
        <div className="stats-focus-grid">
          <StatsFocusTile label="Due Today" value={String(stats.dueToday)} icon="calendar" tone="green" />
          <StatsFocusTile label="Time-Sensitive" value={String(stats.timeSensitive)} icon="clock" tone="red" />
          <StatsFocusTile label="Scheduled" value={stats.dueCoverage} icon="calendar" tone="blue" />
          <StatsFocusTile label="Recurring" value={String(stats.recurring)} icon="repeat" tone="yellow" />
        </div>
      </section>

      <StatsActivity todos={snapshot.todos} />

      <div className="stats-board-grid">
        <StatsBoardCard title="Momentum" icon="bar-chart" tone="green">
          <StatsProgressRow label="Completion Rate" value={`${stats.completionRate}%`} progress={stats.completionRate} tone="green" />
          <StatsProgressRow label="NanoDo Completion" value={`${stats.nanoCompletionRate}%`} progress={stats.nanoCompletionRate} tone="green" />
          <div className="stats-compact-grid">
            <StatsCompactMetric label="Created This Week" value={stats.createdThisWeek} />
            <StatsCompactMetric label="Done This Week" value={stats.completedThisWeek} />
            <StatsCompactMetric label="Done 30 Days" value={stats.completedThisMonth} />
          </div>
        </StatsBoardCard>

        <StatsBoardCard title="Workload Shape" icon="task-list" tone="blue">
          <StatsDetailRow label="Open NanoDos" value={stats.openNanoDos} />
          <StatsDetailRow label="Average NanoDos" value={stats.averageNanoDos} />
          <StatsDetailRow label="Oldest Active" value={stats.oldestActive} />
        </StatsBoardCard>

        <StatsBoardCard title="Organization" icon="tag" tone="yellow">
          <StatsDetailRow label="Top Tag" value={stats.topTag} />
          <StatsDetailRow label="Archived" value={stats.archived} />
          <StatsDetailRow label="Trash" value={stats.trashed} />
          <StatsDetailRow label="Total toDōs" value={stats.total} />
        </StatsBoardCard>

        <StatsBoardCard title="Completion Trends" icon="bar-chart" tone="green">
          <div className="stats-compact-grid stats-compact-grid-two">
            <StatsCompactMetric label="Done Last 7 Days" value={stats.completedLastSevenDays} />
            <StatsCompactMetric label="Daily Average" value={stats.completedDailyAverage} />
          </div>
          <StatsProgressRow label="Overall Completion" value={`${stats.completionRate}%`} progress={stats.completionRate} tone="green" />
        </StatsBoardCard>

        <StatsBoardCard title="Planning Accuracy" icon="calendar" tone="blue">
          <StatsProgressRow label="On-Time Due Completion" value={`${stats.onTimeRate}%`} progress={stats.onTimeRate} tone="blue" />
          <StatsDetailRow label="Completed Before Due" value={stats.onTimeCompleted} />
          <StatsDetailRow label="Completed After Due" value={stats.lateCompleted} />
          <StatsDetailRow label="No-Due Completions" value={stats.noDueCompleted} />
        </StatsBoardCard>

        <StatsBoardCard title="Pressure Signals" icon="alert" tone="red">
          <StatsProgressRow label="Focus Pressure" value={stats.pressureLabel} progress={stats.pressureScore} tone="red" />
          <StatsDetailRow label="Stale 7 Days" value={stats.staleSeven} />
          <StatsDetailRow label="Stale 14 Days" value={stats.staleFourteen} />
          <StatsDetailRow label="Overdue Recurring" value={stats.overdueRecurring} />
        </StatsBoardCard>
      </div>

      <p className="stats-platform-note">Stats reflects your synced toDō data. Apple-only insight processing is not reproduced in the browser.</p>
    </section>
  );
}

type StatsModel = {
  active: number;
  completed: number;
  overdue: number;
  dueToday: number;
  dueSoon: number;
  timeSensitive: number;
  recurring: number;
  dueCoverage: string;
  completionRate: number;
  nanoCompletionRate: number;
  createdThisWeek: number;
  completedThisWeek: number;
  completedThisMonth: number;
  openNanoDos: number;
  averageNanoDos: string;
  oldestActive: string;
  topTag: string;
  archived: number;
  trashed: number;
  total: number;
  completedLastSevenDays: number;
  completedDailyAverage: string;
  onTimeRate: number;
  onTimeCompleted: number;
  lateCompleted: number;
  noDueCompleted: number;
  pressureScore: number;
  pressureLabel: string;
  staleSeven: number;
  staleFourteen: number;
  overdueRecurring: number;
};

function buildStats(snapshot: RemoteSnapshot): StatsModel {
  const now = new Date();
  const active = snapshot.todos.filter(isVisibleActiveTodo);
  const completed = snapshot.todos.filter(isDoneTodo);
  const dueToday = active.filter((todo) => todo.due_at && isSameDay(new Date(todo.due_at), now)).length;
  const dueSoon = active.filter((todo) => isTodoDueSoon(todo)).length;
  const overdue = active.filter((todo) => isTodoOverdue(todo)).length;
  const recurring = active.filter((todo) => Boolean(todo.is_recurring)).length;
  const scheduled = snapshot.todos.filter((todo) => Boolean(todo.due_at)).length;
  const nanoDos = snapshot.nanoDos;
  const completedNanoDos = nanoDos.filter((nanoDo) => nanoDo.is_done).length;
  const dueCompletions = completed.filter((todo) => todo.due_at);
  const onTimeCompleted = dueCompletions.filter((todo) => new Date(todo.completed_at ?? 0).getTime() <= new Date(todo.due_at ?? 0).getTime()).length;
  const lateCompleted = dueCompletions.length - onTimeCompleted;
  const completedLastSevenDays = completed.filter((todo) => isWithinDays(todo.completed_at, 7, now)).length;
  const completedThisWeek = completed.filter((todo) => isWithinDays(todo.completed_at, 7, now)).length;
  const completedThisMonth = completed.filter((todo) => isWithinDays(todo.completed_at, 30, now)).length;
  const staleSeven = active.filter((todo) => isOlderThan(todo, 7, now)).length;
  const staleFourteen = active.filter((todo) => isOlderThan(todo, 14, now)).length;
  const overdueRecurring = active.filter((todo) => Boolean(todo.is_recurring) && isTodoOverdue(todo)).length;
  const pressureScore = Math.min(100, overdue * 18 + staleSeven * 4 + active.length * 2);

  return {
    active: active.length,
    completed: completed.length,
    overdue,
    dueToday,
    dueSoon,
    timeSensitive: active.filter(isTodoTimeSensitive).length,
    recurring,
    dueCoverage: snapshot.todos.length ? `${Math.round((scheduled / snapshot.todos.length) * 100)}%` : "0%",
    completionRate: percent(completed.length, snapshot.todos.length),
    nanoCompletionRate: percent(completedNanoDos, nanoDos.length),
    createdThisWeek: snapshot.todos.filter((todo) => isWithinDays(todo.created_at, 7, now)).length,
    completedThisWeek,
    completedThisMonth,
    openNanoDos: nanoDos.filter((nanoDo) => !nanoDo.is_done).length,
    averageNanoDos: active.length ? (nanoDos.length / active.length).toFixed(1) : "0.0",
    oldestActive: oldestActiveLabel(active),
    topTag: topTagLabel(snapshot),
    archived: snapshot.todos.filter((todo) => todo.lifecycle_state === "archived").length,
    trashed: snapshot.todos.filter((todo) => todo.lifecycle_state === "trashed").length,
    total: snapshot.todos.length,
    completedLastSevenDays,
    completedDailyAverage: (completedLastSevenDays / 7).toFixed(1),
    onTimeRate: percent(onTimeCompleted, dueCompletions.length),
    onTimeCompleted,
    lateCompleted,
    noDueCompleted: completed.filter((todo) => !todo.due_at).length,
    pressureScore,
    pressureLabel: pressureScore >= 70 ? "High" : pressureScore >= 35 ? "Moderate" : "Light",
    staleSeven,
    staleFourteen,
    overdueRecurring,
  };
}

function StatsHero({ stats }: { stats: StatsModel }) {
  return (
    <section className="stats-hero" aria-labelledby="stats-hero-title">
      <div className="stats-hero-heading">
        <span className="stats-hero-icon"><Icon name="bar-chart" size={21} /></span>
        <div>
          <h2 id="stats-hero-title">Measure what matters</h2>
        </div>
      </div>
      <div className="stats-hero-metrics">
        <StatsHeroMetric label="Active" value={stats.active} tone="blue" />
        <StatsHeroMetric label="Done" value={stats.completed} tone="green" />
        <StatsHeroMetric label="Overdue" value={stats.overdue} tone="red" />
      </div>
    </section>
  );
}

function StatsHeroMetric({ label, value, tone }: { label: string; value: number; tone: StatTone }) {
  return <div className={`stats-hero-metric stats-tone-${tone}`}><strong>{value}</strong><span>{label}</span></div>;
}

function StatsFocusTile({ label, value, icon, tone }: { label: string; value: string; icon: IconName; tone: StatTone }) {
  return (
    <article className={`stats-focus-tile stats-tone-${tone}`}>
      <span className="stats-focus-icon"><Icon name={icon} size={17} /></span>
      <span className="stats-focus-label">{label}</span>
      <strong>{value}</strong>
    </article>
  );
}

type StatTone = "blue" | "green" | "red" | "yellow";

function StatsActivity({ todos }: { todos: Todo[] }) {
  const days = useMemo(() => activityDays(todos, new Date(), 84), [todos]);
  return (
    <section className="stats-activity" aria-labelledby="stats-activity-title">
      <div className="stats-section-heading">
        <div><p className="eyebrow">Activity</p><h2 id="stats-activity-title">Completion rhythm</h2></div>
        <span>Last 12 weeks</span>
      </div>
      <div className="stats-activity-grid" aria-label="Completion rhythm over the last 12 weeks">
        {days.map((day) => <span className={`stats-activity-cell stats-activity-level-${Math.min(day.count, 4)}`} key={day.key} title={`${day.count} completed on ${day.label}`} aria-label={`${day.count} completed on ${day.label}`} />)}
      </div>
      <div className="stats-activity-legend"><span>Less</span><i /><i /><i /><i /><i className="stats-activity-level-4" /><span>More</span></div>
    </section>
  );
}

function StatsBoardCard({ title, icon, tone, children }: { title: string; icon: IconName; tone: StatTone; children: ReactNode }) {
  return (
    <section className={`stats-board-card stats-tone-${tone}`}>
      <div className="stats-board-card-heading"><span className="stats-board-icon"><Icon name={icon} size={18} /></span><h2>{title}</h2></div>
      <div className="stats-board-card-content">{children}</div>
    </section>
  );
}

function StatsProgressRow({ label, value, progress, tone }: { label: string; value: string; progress: number; tone: StatTone }) {
  return <div className="stats-progress-row"><div><span>{label}</span><strong>{value}</strong></div><span className={`stats-progress-track stats-tone-${tone}`}><span style={{ width: `${Math.min(100, Math.max(0, progress))}%` }} /></span></div>;
}

function StatsCompactMetric({ label, value }: { label: string; value: number | string }) {
  return <div className="stats-compact-metric"><strong>{value}</strong><span>{label}</span></div>;
}

function StatsDetailRow({ label, value }: { label: string; value: number | string }) {
  return <div className="stats-detail-row"><span>{label}</span><strong>{value}</strong></div>;
}

function isDoneTodo(todo: Todo) {
  return todo.is_done || todo.lifecycle_state === "done";
}

function percent(numerator: number, denominator: number) {
  return denominator ? Math.round((numerator / denominator) * 100) : 0;
}

function isSameDay(left: Date, right: Date) {
  return left.getFullYear() === right.getFullYear() && left.getMonth() === right.getMonth() && left.getDate() === right.getDate();
}

function isWithinDays(value: string | null, days: number, now: Date) {
  if (!value) return false;
  const timestamp = new Date(value).getTime();
  return timestamp >= now.getTime() - days * 24 * 60 * 60 * 1000;
}

function isOlderThan(todo: Todo, days: number, now: Date) {
  const reference = todo.updated_at ?? todo.created_at;
  return Boolean(reference && new Date(reference).getTime() < now.getTime() - days * 24 * 60 * 60 * 1000);
}

function oldestActiveLabel(todos: Todo[]) {
  const oldest = [...todos].sort((left, right) => new Date(left.created_at ?? 0).getTime() - new Date(right.created_at ?? 0).getTime())[0];
  return oldest?.created_at ? new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric" }).format(new Date(oldest.created_at)) : "None";
}

function topTagLabel(snapshot: RemoteSnapshot) {
  const counts = new Map<string, number>();
  for (const relation of snapshot.todoTags) {
    const tag = snapshot.tags.find((item) => item.id === relation.tag_id);
    if (tag) counts.set(tag.name, (counts.get(tag.name) ?? 0) + 1);
  }
  const top = [...counts.entries()].sort((left, right) => right[1] - left[1])[0];
  return top ? `#${top[0]} · ${top[1]}` : "No tag activity";
}

function activityDays(todos: Todo[], now: Date, count: number) {
  return Array.from({ length: count }, (_, index) => {
    const date = new Date(now);
    date.setHours(0, 0, 0, 0);
    date.setDate(date.getDate() - (count - index - 1));
    const dayEnd = new Date(date);
    dayEnd.setDate(dayEnd.getDate() + 1);
    const completedCount = todos.filter((todo) => {
      if (!isDoneTodo(todo) || !todo.completed_at) return false;
      const completedAt = new Date(todo.completed_at).getTime();
      return completedAt >= date.getTime() && completedAt < dayEnd.getTime();
    }).length;
    return {
      key: date.toISOString(),
      count: completedCount,
      label: new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric" }).format(date),
    };
  });
}
