"use client";

import Link from "@/components/Link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { Icon } from "@/components/Icon";
import { AccountSetupCard } from "@/features/auth/AccountSetupCard";
import { SignInCard } from "@/features/auth/SignInCard";
import { useAuth } from "@/features/auth/AuthProvider";
import { LoadingCard, StateCard } from "@/components/StateCard";
import type { RemoteSnapshot, TodoPresentation } from "@/lib/types";
import { NewTodoComposer } from "@/features/todos/NewTodoComposer";
import {
  hasWebPlusAccess,
  isVisibleActiveTodo,
  loadEntitlements,
  loadRemoteSnapshot,
  presentTodo,
  isTodoDueSoon,
  isTodoOverdue,
  isTodoTimeSensitive,
} from "@/features/todos/data";
import { saveOnboardingStep } from "@/lib/onboarding";
import { subscribeToWebRefresh } from "@/lib/webRefresh";

type HomeState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "blocked" }
  | { status: "ready"; snapshot: RemoteSnapshot }
  | { status: "error"; message: string };

type PreviewFilter = "due" | "time-sensitive" | "recent";

export function Home() {
  const { user, session, isLoading: authLoading, isConfigured, isResolved } = useAuth();
  const [state, setState] = useState<HomeState>({ status: "idle" });
  const [retryKey, setRetryKey] = useState(0);

  useEffect(() => subscribeToWebRefresh(() => setRetryKey((value) => value + 1)), []);

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
          message: error instanceof Error ? error.message : "Your Home could not be loaded.",
        });
      }
    })();

    return () => {
      isCurrent = false;
    };
  }, [authLoading, isConfigured, isResolved, retryKey, session?.access_token, user]);

  if (!isConfigured) {
    return (
      <div className="state-layout">
        <StateCard eyebrow="Local setup" title="Connect Supabase to open Home">
          <p>
            Add the browser-safe Supabase URL and publishable key to <code>Web/.env.local</code>,
            restart the local server, and the real Home surface will appear here.
          </p>
        </StateCard>
      </div>
    );
  }

  if (authLoading) {
    return (
      <div className="state-layout">
        <LoadingCard />
        <p className="loading-message" aria-live="polite">Checking your toDō account…</p>
      </div>
    );
  }

  if (!user) {
    return <div className="auth-layout"><SignInCard /></div>;
  }

  if (!isResolved) {
    return (
      <div className="auth-layout">
        <AccountSetupCard />
        <p className="loading-message" aria-live="polite">
          Home stays paused until this provider is resolved to a username.
        </p>
      </div>
    );
  }

  if (state.status === "idle" || state.status === "loading") {
    return (
      <div className="state-layout">
        <LoadingCard />
        <p className="loading-message" aria-live="polite">Loading your Home…</p>
      </div>
    );
  }

  if (state.status === "blocked") {
    return (
      <div className="state-layout">
        <StateCard eyebrow="toDō+" title="Home is part of toDō+" tone="warning">
          <p>Use the account with your active toDō+ entitlement to open your synced Home.</p>
        </StateCard>
      </div>
    );
  }

  if (state.status === "error") {
    return (
      <div className="state-layout">
        <StateCard eyebrow="Sync" title="Home could not be loaded" tone="error">
          <p>{state.message}</p>
          <p>Your records are safe. Open toDōs to retry the synced list.</p>
          <Link className="primary-button" href="/todos">Open toDōs</Link>
        </StateCard>
      </div>
    );
  }

  return <ReadyHome snapshot={state.snapshot} userID={user.id} />;
}

function ReadyHome({ snapshot, userID }: { snapshot: RemoteSnapshot; userID: string }) {
  const router = useRouter();
  const [previewFilter, setPreviewFilter] = useState<PreviewFilter>("due");
  const [isComposerOpen, setIsComposerOpen] = useState(false);
  const [localSnapshot, setLocalSnapshot] = useState(snapshot);
  useEffect(() => {
    const timer = window.setTimeout(() => setLocalSnapshot(snapshot), 0);
    return () => window.clearTimeout(timer);
  }, [snapshot]);
  const activeTodos = useMemo(
    () => localSnapshot.todos
      .filter(isVisibleActiveTodo)
      .map((todo) => presentTodo(todo, localSnapshot)),
    [localSnapshot],
  );
  const previewTodos = useMemo(
    () => previewFor(activeTodos, previewFilter),
    [activeTodos, previewFilter],
  );
  const dueSoonCount = activeTodos.filter((todo) => isDueSoon(todo)).length;
  const overdueCount = activeTodos.filter((todo) => isOverdue(todo)).length;
  const timeSensitiveCount = activeTodos.filter(isTodoTimeSensitive).length;
  const completedCount = localSnapshot.todos.filter(
    (todo) => todo.is_done || todo.lifecycle_state === "done",
  ).length;

  return (
    <section className="home-shell" aria-labelledby="home-title">
      <section className="home-primary-card">
        <h1 id="home-title">What matters now?</h1>
        <div className="home-action-row">
          <button
            className="home-new-button"
            type="button"
            onClick={() => setIsComposerOpen(true)}
          >
            <span className="home-plus-mark" aria-hidden="true"><Icon name="plus" /></span>
            New toDō
          </button>
          <Link className="home-see-all-button" href="/todos">
            <Icon name="check" />
            See all toDōs
            <span className="home-count">{activeTodos.length}</span>
            <Icon name="arrow-right" />
          </Link>
        </div>
        {isComposerOpen ? (
          <NewTodoComposer
            userID={userID}
            collabs={localSnapshot.collabs}
            existingTags={localSnapshot.tags}
            onCancel={() => setIsComposerOpen(false)}
            onCreated={(result) => {
              const isFirstTodo = activeTodos.length === 0;
              setLocalSnapshot((current) => ({
                ...current,
                todos: [result.todo, ...current.todos],
                nanoDos: [...result.nanoDos, ...current.nanoDos],
                tags: [
                  ...result.tags,
                  ...current.tags.filter((tag) => !result.tags.some((item) => item.id === tag.id)),
                ],
                todoTags: [...result.todoTags, ...current.todoTags],
              }));
              setIsComposerOpen(false);
              if (isFirstTodo) {
                saveOnboardingStep("detail");
                router.push(`/todos/${result.todo.id}?onboarding=detail`);
              }
            }}
          />
        ) : null}
      </section>

      <section className="home-section" aria-labelledby="up-next-title">
        <div className="home-section-heading">
          <h2 id="up-next-title">Up next</h2>
        </div>
        <div className="home-filter-pills" role="group" aria-label="Home preview filter">
          {([
            ["due", "Due soon"],
            ["time-sensitive", "Time-sensitive"],
            ["recent", "Recent"],
          ] as const).map(([value, label]) => (
            <button
              className={previewFilter === value ? "home-filter home-filter-selected" : "home-filter"}
              key={value}
              type="button"
              aria-pressed={previewFilter === value}
              onClick={() => setPreviewFilter(value)}
            >
              {label}
            </button>
          ))}
        </div>
        {previewTodos.length ? (
          <div className="home-preview-list">
            {previewTodos.slice(0, 3).map((todo) => <HomePreviewRow key={todo.id} todo={todo} />)}
          </div>
        ) : (
          <HomePreviewEmpty filter={previewFilter} />
        )}
      </section>

      <section className="home-section home-momentum" aria-labelledby="momentum-title">
        <div className="home-section-heading">
          <h2 id="momentum-title">Momentum</h2>
          <Link className="home-stats-button" href="/stats">
            <span>Stats</span>
            <Icon name="bar-chart" size={16} />
          </Link>
        </div>
        <div className="home-metrics">
          <HomeMetric label="Active" value={activeTodos.length} icon="bolt" tone="blue" />
          <HomeMetric label="Due soon" value={dueSoonCount} icon="clock" tone="yellow" />
          <HomeMetric label="Overdue" value={overdueCount} icon="alert" tone="red" />
          <HomeMetric label="Time-sensitive" value={timeSensitiveCount} icon="flame" tone="dark" />
        </div>
        <div className="home-completed-summary">
          <span className="home-completed-icon" aria-hidden="true"><Icon name="check" size={16} /></span>
          <span>Completed</span>
          <strong>{completedCount}</strong>
        </div>
      </section>
    </section>
  );
}

function HomeMetric({
  label,
  value,
  icon,
  tone,
}: {
  label: string;
  value: number;
  icon: "alert" | "bolt" | "clock" | "flame";
  tone: "blue" | "dark" | "red" | "yellow";
}) {
  return (
    <div className={`home-metric-card home-metric-${tone}`}>
      <div className="home-metric-value">
        <span className="home-metric-icon" aria-hidden="true"><Icon name={icon} size={15} /></span>
        <strong>{value}</strong>
      </div>
      <span>{label}</span>
    </div>
  );
}

function HomePreviewRow({ todo }: { todo: TodoPresentation }) {
  return (
    <Link className={`home-preview-row${isOverdue(todo) ? " home-preview-row-overdue" : ""}`} href={`/todos/${todo.id}`}>
      <span className="home-preview-copy">
        <span className="home-preview-title">{todo.task}</span>
        {isOverdue(todo) || todo.due_at ? (
          <span className="home-preview-meta">
            {isOverdue(todo) ? <span className="home-preview-overdue-label"><Icon name="alert" size={14} /> Overdue</span> : null}
            {todo.due_at ? formatDue(todo.due_at) : null}
          </span>
        ) : null}
      </span>
      {isTodoTimeSensitive(todo) ? (
        <span className="home-urgent-mark" aria-label="Time-sensitive"><Icon name="clock" /></span>
      ) : null}
    </Link>
  );
}

function HomePreviewEmpty({ filter }: { filter: PreviewFilter }) {
  const copy = {
    due: "Nothing is due in the next seven days.",
    "time-sensitive": "No time-sensitive toDōs right now.",
    recent: "No recent toDōs in the current window.",
  }[filter];

  return (
    <div className="home-empty-preview">
      <p>{copy}</p>
    </div>
  );
}

function previewFor(todos: TodoPresentation[], filter: PreviewFilter) {
  return [...todos]
    .filter((todo) => {
      if (filter === "due") return isDueSoon(todo);
      if (filter === "time-sensitive") return isTodoTimeSensitive(todo);
      return timestamp(todo.created_at) >= Date.now() - 30 * 24 * 60 * 60 * 1000;
    })
    .sort((left, right) => {
      if (filter === "recent") return timestamp(right.created_at) - timestamp(left.created_at);
      return dueTimestamp(left.due_at) - dueTimestamp(right.due_at);
    });
}

function isDueSoon(todo: TodoPresentation) {
  return isTodoDueSoon(todo);
}

function isOverdue(todo: TodoPresentation) {
  return isTodoOverdue(todo);
}

function timestamp(value: string | null) {
  return value ? new Date(value).getTime() : 0;
}

function dueTimestamp(value: string | null) {
  return value ? new Date(value).getTime() : Number.POSITIVE_INFINITY;
}

function formatDue(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(value));
}
