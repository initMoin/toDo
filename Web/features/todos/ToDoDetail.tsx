"use client";

import Link from "@/components/Link";
import { useEffect, useState, useSyncExternalStore, type ReactNode } from "react";
import { Icon, type IconName } from "@/components/Icon";
import { SignInCard } from "@/features/auth/SignInCard";
import { AccountSetupCard } from "@/features/auth/AccountSetupCard";
import { useAuth } from "@/features/auth/AuthProvider";
import { StateCard, LoadingCard } from "@/components/StateCard";
import type { Collab, Tag, TodoEditorDraft, TodoPresentation } from "@/lib/types";
import { readOnboardingStep, saveOnboardingStep, subscribeToOnboarding, type OnboardingStep } from "@/lib/onboarding";
import {
  hasWebPlusAccess,
  isTodoOverdue,
  loadEntitlements,
  loadRemoteSnapshot,
  presentTodo,
  updateTodoCompletion,
  updateTodoLifecycle,
} from "./data";
import { TodoEditor } from "./TodoEditor";
import type { TodoSaveResult } from "./data";
import { subscribeToWebRefresh } from "@/lib/webRefresh";
import { readStoredWebPreferences } from "@/lib/webPreferences";

export function ToDoDetail({
  todoId,
  onboardingStep,
}: {
  todoId: string;
  onboardingStep?: OnboardingStep;
}) {
  const { user, session, isLoading: authLoading, isConfigured, isResolved } = useAuth();
  const [state, setState] = useState<DetailState>({ status: "idle" });
  const [retryKey, setRetryKey] = useState(0);
  const [isUpdating, setIsUpdating] = useState(false);
  const [mutationError, setMutationError] = useState<string | null>(null);
  const storedOnboardingStep = useSyncExternalStore(
    subscribeToOnboarding,
    readOnboardingStep,
    () => null,
  );
  const guidedStep = onboardingStep ?? storedOnboardingStep;

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
        const record = snapshot.todos.find((todo) => todo.id === todoId);
        if (!record) {
          if (isCurrent) setState({ status: "missing" });
          return;
        }
        if (isCurrent) {
          setState({ status: "ready", todo: presentTodo(record, snapshot), collabs: snapshot.collabs, tags: snapshot.tags });
        }
      } catch (error) {
        if (!isCurrent) return;
        setState({
          status: "error",
          message: error instanceof Error ? error.message : "The toDō could not be loaded.",
        });
      }
    })();

    return () => {
      isCurrent = false;
    };
  }, [authLoading, isConfigured, isResolved, retryKey, session?.access_token, todoId, user]);

  if (!isConfigured) {
    return (
      <div className="state-layout">
        <StateCard eyebrow="Local setup" title="Connect Supabase to open this toDō">
          <p>Add the browser-safe Supabase values to <code>Web/.env.local</code> and restart the local server.</p>
        </StateCard>
      </div>
    );
  }

  if (authLoading) {
    return <div className="state-layout"><LoadingCard /></div>;
  }

  if (!user) {
    return <div className="auth-layout"><SignInCard /></div>;
  }

  if (!isResolved) {
    return <div className="auth-layout"><AccountSetupCard /></div>;
  }

  if (state.status === "idle" || state.status === "loading") {
    return <div className="state-layout"><LoadingCard /></div>;
  }

  if (state.status === "blocked") {
    return (
      <div className="state-layout">
        <StateCard title="toDō+ required" tone="warning" />
      </div>
    );
  }

  if (state.status === "missing") {
    return (
      <div className="state-layout">
        <StateCard eyebrow="toDō" title="That toDō is not available">
          <p>It may have been completed, removed, or is no longer visible to this account.</p>
        </StateCard>
      </div>
    );
  }

  if (state.status === "error") {
    return (
      <div className="state-layout">
        <StateCard eyebrow="Sync" title="This toDō could not be loaded" tone="error">
          <p>{state.message}</p>
          <button className="primary-button" type="button" onClick={() => setRetryKey((value) => value + 1)}>
            Try again
          </button>
        </StateCard>
      </div>
    );
  }

  if (state.status !== "ready") {
    return null;
  }

  async function handleCompletionChange(isDone: boolean) {
    if (state.status !== "ready" || isUpdating) return;

    setIsUpdating(true);
    setMutationError(null);
    try {
      if (isDone) {
        const preferences = readStoredWebPreferences();
        await updateTodoLifecycle(
          state.todo.id,
          preferences.removeAction === "archive" ? "archived" : "trashed",
        );
      } else {
        await updateTodoCompletion(state.todo.id, false);
      }
      setRetryKey((value) => value + 1);
    } catch (error) {
      setMutationError(
        error instanceof Error ? error.message : "The toDō could not be updated. Try again.",
      );
    } finally {
      setIsUpdating(false);
    }
  }

  return (
    <DetailContent
      todo={state.todo}
      userID={user.id}
      collabs={state.collabs}
      existingTags={state.tags}
      guidedStep={guidedStep}
      isUpdating={isUpdating}
      mutationError={mutationError}
      onCompletionChange={handleCompletionChange}
      onTodoSaved={(result) => setState((current) => current.status === "ready" ? {
        ...current,
        todo: {
          ...current.todo,
          ...result.todo,
          nanoDos: result.nanoDos,
          tags: result.tags,
          collabName: result.collabName,
        },
      } : current)}
    />
  );
}

type DetailState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "blocked" | "missing" }
  | { status: "error"; message: string }
  | { status: "ready"; todo: TodoPresentation; collabs: Collab[]; tags: Tag[] };

function DetailContent({
  todo,
  userID,
  collabs,
  existingTags,
  guidedStep,
  isUpdating,
  mutationError,
  onCompletionChange,
  onTodoSaved,
}: {
  todo: TodoPresentation;
  userID: string;
  collabs: Collab[];
  existingTags: Tag[];
  guidedStep: OnboardingStep | null;
  isUpdating: boolean;
  mutationError: string | null;
  onCompletionChange: (isDone: boolean) => Promise<void>;
  onTodoSaved: (result: TodoSaveResult, draft: TodoEditorDraft) => void;
}) {
  const [isEditing, setIsEditing] = useState(false);
  const isDone = todo.is_done || ["done", "archived"].includes(todo.lifecycle_state ?? "");
  const isOverdue = !isDone && isTodoOverdue(todo);

  if (isEditing) {
    return (
      <section className="detail-shell" aria-labelledby="detail-edit-title">
        <TodoEditor
          userID={userID}
          mode="edit"
          initialTodo={todo}
          collabs={collabs}
          existingTags={existingTags}
          onSaved={(result, draft) => {
            onTodoSaved(result, draft);
            setIsEditing(false);
          }}
          onCancel={() => setIsEditing(false)}
        />
      </section>
    );
  }

  return (
    <section className="detail-shell" aria-labelledby="detail-title">
      <div className="detail-title-card">
        <h1 id="detail-title" className="detail-title">{todo.task}</h1>
        <div className="detail-action-row">
          <p className={`detail-state${isOverdue ? " detail-state-overdue" : ""}`}>
            <span className={`todo-status${isDone ? " todo-status-done" : ""}`} aria-hidden="true">
              {isDone ? <Icon name="check" size={13} strokeWidth={3} /> : null}
            </span>
            {isDone ? "Completed toDō" : isOverdue ? "Overdue toDō" : "Active toDō"}
          </p>
          <div className="detail-actions">
          <button
            className="detail-edit-button"
            type="button"
            onClick={() => setIsEditing(true)}
            aria-label="Edit toDō"
            title="Edit toDō"
          >
            <Icon name="edit" size={19} />
            <span>Edit</span>
          </button>
          <button
            className="primary-button detail-complete-action"
            type="button"
            onClick={() => void onCompletionChange(!isDone)}
            disabled={isUpdating}
            aria-busy={isUpdating}
          >
            <Icon name="check" size={19} />
            {isUpdating ? "Saving…" : isDone ? "Reopen toDō" : "Complete toDō"}
          </button>
          </div>
        </div>
      </div>

      {mutationError ? <p className="inline-error" role="alert">{mutationError}</p> : null}

      {guidedStep === "detail" ? (
        <aside className="onboarding-card" aria-labelledby="onboarding-detail-title">
          <p className="eyebrow">Getting started</p>
          <h2 id="onboarding-detail-title">Review your toDō.</h2>
          <p>Your first toDō is saved. Review its status and details here; you can make changes whenever you need them.</p>
          <Link
            className="primary-button"
            href="/settings?onboarding=settings"
            onClick={() => saveOnboardingStep("settings")}
          >
            Continue to Settings
          </Link>
        </aside>
      ) : null}

      <h2 className="detail-section-title">Details</h2>
      <div className="detail-grid">
        {todo.due_at ? (
          <DetailCard label="Due" icon="calendar" tone="yellow">
            <p>{formatDue(todo.due_at)}</p>
          </DetailCard>
        ) : null}
        <DetailCard label="Reminder" icon="clock" tone="dark">
          <p>{reminderLabel(todo.reminder_intent ?? "soft")}</p>
        </DetailCard>
        {todo.collabName ? (
          <DetailCard label="Collab" icon="users" tone="blue">
            <p>{todo.collabName}</p>
          </DetailCard>
        ) : null}
        {todo.is_recurring ? (
          <DetailCard label="Repeat" icon="repeat" tone="green">
            <p>{recurrenceLabel(todo)}</p>
          </DetailCard>
        ) : null}
        <DetailCard label="Updated" icon="calendar" tone="blue">
          <p>{formatDue(todo.updated_at ?? todo.created_at ?? new Date().toISOString())}</p>
        </DetailCard>
      </div>

      {todo.tags.length ? (
        <section className="detail-subsection" aria-labelledby="tags-title">
          <h2 id="tags-title">Tags</h2>
          <div className="detail-tags">
            {todo.tags.map((tag) => <span className="tag-pill" key={tag.id}>{tag.name}</span>)}
          </div>
        </section>
      ) : null}

      <section className="detail-subsection" aria-labelledby="nanodos-title">
        <div className="detail-subsection-heading">
          <h2 id="nanodos-title">NanoDos</h2>
          <span>{todo.nanoDos.length}</span>
        </div>
        {todo.nanoDos.length ? (
          <ul className="nano-list">
            {todo.nanoDos.map((nanoDo) => (
              <li className={nanoDo.is_done ? "nano-done" : ""} key={nanoDo.id}>
                <span className="nano-status" aria-hidden="true">{nanoDo.is_done ? <Icon name="check" size={12} strokeWidth={3} /> : null}</span>
                <span>{nanoDo.task}</span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="detail-muted">No NanoDos yet.</p>
        )}
      </section>

      {todo.notes?.trim() ? (
        <section className="detail-subsection" aria-labelledby="notes-title">
          <h2 id="notes-title">Notes</h2>
          <p className="detail-notes">{todo.notes.trim()}</p>
        </section>
      ) : null}

      {!todo.due_at && !todo.collabName && !todo.is_recurring && !todo.tags.length && !todo.nanoDos.length && !todo.notes?.trim() ? (
        <p className="detail-muted detail-empty-message">No extra detail yet. Add a due date, notes, tags, or NanoDos to make this toDō more useful.</p>
      ) : null}
    </section>
  );
}

function DetailCard({
  label,
  icon,
  tone,
  children,
}: {
  label: string;
  icon: IconName;
  tone: "yellow" | "dark" | "blue" | "green";
  children: ReactNode;
}) {
  return (
    <article className={`detail-card detail-card-${tone}`}>
      <span className="detail-card-symbol" aria-hidden="true"><Icon name={icon} size={25} /></span>
      <div>
        <p className="detail-card-label">{label}</p>
        <div className="detail-card-value">{children}</div>
      </div>
    </article>
  );
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

function reminderLabel(value: string) {
  if (value === "soft") return "Quiet";
  if (value === "due") return "Due";
  if (value === "time_sensitive") return "Time-Sensitive";
  return value.replaceAll("_", " ");
}

function recurrenceLabel(todo: TodoPresentation) {
  const interval = todo.recurrence_interval ?? 1;
  const unit = todo.recurrence_unit ?? "time";
  return `${interval} ${unit}${interval === 1 ? "" : "s"}`;
}
