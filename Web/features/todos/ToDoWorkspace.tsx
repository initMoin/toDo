"use client";

import Link from "@/components/Link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { Icon } from "@/components/Icon";
import { SignInCard } from "@/features/auth/SignInCard";
import { AccountSetupCard } from "@/features/auth/AccountSetupCard";
import { useAuth } from "@/features/auth/AuthProvider";
import { StateCard, LoadingCard } from "@/components/StateCard";
import type { RemoteSnapshot, TodoPresentation } from "@/lib/types";
import type { TodoSaveResult } from "./data";
import {
  hasWebPlusAccess,
  isVisibleActiveTodo,
  loadEntitlements,
  loadRemoteSnapshot,
  presentTodo,
  isTodoDueSoon,
  isTodoOverdue,
  isTodoTimeSensitive,
  updateTodoCompletion,
  updateTodoLifecycle,
} from "./data";
import { NewTodoComposer } from "./NewTodoComposer";
import { saveOnboardingStep } from "@/lib/onboarding";
import {
  defaultWebPreferences,
  readStoredWebPreferences,
  saveStoredWebPreferences,
  webPreferencesChangedEvent,
  type WebPreferences,
} from "@/lib/webPreferences";
import { subscribeToWebRefresh } from "@/lib/webRefresh";

type DataState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "blocked" }
  | { status: "ready"; snapshot: RemoteSnapshot }
  | { status: "error"; message: string };

export type Filter = "all" | "due" | "time-sensitive" | "collab";
export type Sort = "position" | "due" | "newest";
type Group = "none" | "due" | "collab";

export function ToDoWorkspace({
  initialFilter = "all",
  initialSort = "position",
}: {
  initialFilter?: Filter;
  initialSort?: Sort;
}) {
  const {
    user,
    session,
    isLoading: authLoading,
    isConfigured,
    isResolved,
    resolutionState,
  } = useAuth();
  const [dataState, setDataState] = useState<DataState>({ status: "idle" });
  const [retryKey, setRetryKey] = useState(0);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<Filter>(initialFilter);
  const [preferences, setPreferences] = useState<WebPreferences>(defaultWebPreferences);
  const [sort, setSort] = useState<Sort>(initialSort);
  const [group, setGroup] = useState<Group>("none");
  const [updatingTodoID, setUpdatingTodoID] = useState<string | null>(null);
  const [mutationError, setMutationError] = useState<string | null>(null);

  async function handleCompletionChange(todoID: string, isDone: boolean) {
    if (updatingTodoID) return;

    setUpdatingTodoID(todoID);
    setMutationError(null);
    try {
      if (isDone) {
        await updateTodoLifecycle(todoID, preferences.removeAction === "archive" ? "archived" : "trashed");
      } else {
        await updateTodoCompletion(todoID, false);
      }
      setRetryKey((value) => value + 1);
    } catch (error) {
      setMutationError(
        error instanceof Error ? error.message : "The toDō could not be updated. Try again.",
      );
    } finally {
      setUpdatingTodoID(null);
    }
  }

  useEffect(() => {
    const handlePreferencesChange = () => {
      const next = readStoredWebPreferences();
      setPreferences(next);
      setSort(initialSort === "position" ? next.sort : initialSort);
      setGroup(next.group);
    };
    handlePreferencesChange();
    window.addEventListener("storage", handlePreferencesChange);
    window.addEventListener(webPreferencesChangedEvent, handlePreferencesChange);
    return () => {
      window.removeEventListener("storage", handlePreferencesChange);
      window.removeEventListener(webPreferencesChangedEvent, handlePreferencesChange);
    };
  }, [initialSort]);

  useEffect(() => {
    return subscribeToWebRefresh(() => setRetryKey((value) => value + 1));
  }, []);

  function handleTodoCreated(result: TodoSaveResult) {
    setDataState((current) => {
      if (current.status !== "ready") return current;
      return {
        status: "ready",
        snapshot: {
          ...current.snapshot,
          todos: [result.todo, ...current.snapshot.todos],
          nanoDos: [...result.nanoDos, ...current.snapshot.nanoDos],
          tags: [...result.tags, ...current.snapshot.tags.filter((tag) => !result.tags.some((item) => item.id === tag.id))],
          todoTags: [...result.todoTags, ...current.snapshot.todoTags],
        },
      };
    });
  }

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
          if (isCurrent) setDataState({ status: "blocked" });
          return;
        }

        const snapshot = await loadRemoteSnapshot();
        if (isCurrent) setDataState({ status: "ready", snapshot });
      } catch (error) {
        if (!isCurrent) return;
        setDataState({
          status: "error",
          message:
            error instanceof Error
              ? error.message
              : "The toDōs could not be loaded. Try again.",
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
        <StateCard eyebrow="Local setup" title="Connect Supabase to test the Web app">
          <p>
            This build intentionally does not invent task data. Add the browser-safe
            Supabase URL and publishable key to <code>Web/.env.local</code>, restart
            the dev server, and the real sign-in flow will appear here.
          </p>
          <p>
            The service-role key never belongs in this file or in browser code.
          </p>
        </StateCard>
      </div>
    );
  }

  if (authLoading) {
    return <div className="state-layout"><LoadingCard /></div>;
  }

  if (!user) {
    return (
      <div className="auth-layout">
        <SignInCard />
      </div>
    );
  }

  if (!isResolved) {
    return (
      <div className="auth-layout">
        <AccountSetupCard />
        <span className="sr-only">Account state: {resolutionState}</span>
      </div>
    );
  }

  if (dataState.status === "loading" || dataState.status === "idle") {
    return <div className="state-layout"><LoadingCard /></div>;
  }

  if (dataState.status === "blocked") {
    return (
      <div className="state-layout">
        <StateCard title="toDō+ required" tone="warning" />
      </div>
    );
  }

  if (dataState.status === "error") {
    return (
      <div className="state-layout">
        <StateCard eyebrow="Sync" title="Your toDōs could not be loaded" tone="error">
          <p>{dataState.message}</p>
          <p>
            The Web client could not complete this remote read. No local
            success state was shown, and no mutation was attempted.
          </p>
          <button
            className="primary-button"
            type="button"
            onClick={() => setRetryKey((current) => current + 1)}
          >
            Try again
          </button>
        </StateCard>
      </div>
    );
  }

  return (
    <ReadyWorkspace
      snapshot={dataState.snapshot}
      search={search}
      onSearch={setSearch}
      filter={filter}
      onFilter={setFilter}
      sort={sort}
      onSort={(value) => {
        setSort(value);
        const next = { ...preferences, sort: value };
        setPreferences(next);
        saveStoredWebPreferences(next);
      }}
      group={group}
      onGroup={(value) => {
        setGroup(value);
        const next = { ...preferences, group: value };
        setPreferences(next);
        saveStoredWebPreferences(next);
      }}
      sortReversed={preferences.sortReversed}
      updatingTodoID={updatingTodoID}
      mutationError={mutationError}
      onCompletionChange={handleCompletionChange}
      onTodoCreated={handleTodoCreated}
    />
  );
}

function ReadyWorkspace({
  snapshot,
  search,
  onSearch,
  filter,
  onFilter,
  sort,
  onSort,
  group,
  sortReversed,
  onGroup,
  updatingTodoID,
  mutationError,
  onCompletionChange,
  onTodoCreated,
}: {
  snapshot: RemoteSnapshot;
  search: string;
  onSearch: (value: string) => void;
  filter: Filter;
  onFilter: (value: Filter) => void;
  sort: Sort;
  onSort: (value: Sort) => void;
  group: Group;
  sortReversed: boolean;
  onGroup: (value: Group) => void;
  updatingTodoID: string | null;
  mutationError: string | null;
  onCompletionChange: (todoID: string, isDone: boolean) => Promise<void>;
  onTodoCreated: (result: TodoSaveResult) => void;
}) {
  const { user } = useAuth();
  const router = useRouter();
  const [isComposerOpen, setIsComposerOpen] = useState(false);
  const todos = useMemo(
    () =>
      snapshot.todos
        .filter(isVisibleActiveTodo)
        .map((todo) => presentTodo(todo, snapshot)),
    [snapshot],
  );
  const visibleTodos = useMemo(
    () =>
      todos
        .filter((todo) => matchesSearch(todo, search))
        .filter((todo) => matchesFilter(todo, filter))
        .sort((left, right) => {
          const comparison = compareTodos(left, right, sort);
          return sortReversed ? -comparison : comparison;
        }),
    [filter, search, sort, sortReversed, todos],
  );
  const groups = useMemo(
    () => groupTodos(visibleTodos, group),
    [group, visibleTodos],
  );

  useEffect(() => {
    const params = new URLSearchParams();
    if (filter !== "all") params.set("filter", filter);
    if (sort !== "position") params.set("sort", sort);
    const query = params.toString();
    window.history.replaceState({}, "", query ? `${window.location.pathname}?${query}` : window.location.pathname);
  }, [filter, sort]);

  return (
    <section className="workspace-shell" aria-labelledby="workspace-title">
      <div className="workspace-intro">
        <h1 className="sr-only" id="workspace-title">Active toDōs</h1>
        <div className="workspace-intro-actions">
          <button className="workspace-new-button" type="button" onClick={() => setIsComposerOpen(true)} aria-label="Add a new toDō" title="Add a new toDō">
            <Icon name="plus" size={25} strokeWidth={2.2} />
          </button>
        </div>
      </div>

      <div className="workspace-sync-line" aria-live="polite">
        <span className="sync-status" aria-label="Sync status: synced"><Icon name="check" size={16} strokeWidth={2.8} /> Synced</span>
        <span>{todos.length} active {todos.length === 1 ? "toDō" : "toDōs"}</span>
      </div>

      {isComposerOpen && user ? (
        <NewTodoComposer
          userID={user.id}
          collabs={snapshot.collabs}
          existingTags={snapshot.tags}
          onCancel={() => setIsComposerOpen(false)}
            onCreated={(result) => {
            const isFirstTodo = todos.length === 0;
              onTodoCreated(result);
            setIsComposerOpen(false);
            if (isFirstTodo) {
              saveOnboardingStep("detail");
                router.push(`/todos/${result.todo.id}?onboarding=detail`);
            }
          }}
        />
      ) : null}

      {mutationError ? (
        <div className="error-banner" role="alert">
          <span aria-hidden="true">!</span>
          <p>{mutationError}</p>
        </div>
      ) : null}

      <section className="todo-utility-tray" aria-labelledby="todo-tools-title">
        <h2 id="todo-tools-title" className="sr-only">toDō list tools</h2>
        <div className="list-toolbar" role="search">
        <label className="search-control">
          <span className="sr-only">Search toDōs, notes, tags, and NanoDos</span>
          <span className="search-symbol" aria-hidden="true"><Icon name="search" /></span>
          <input
            type="search"
            value={search}
            onChange={(event) => onSearch(event.target.value)}
            placeholder="Search toDōs, notes, tags, NanoDos"
          />
          {search ? (
            <button
              className="clear-search"
              type="button"
              onClick={() => onSearch("")}
              aria-label="Clear search"
            >
              <Icon name="close" />
            </button>
          ) : null}
        </label>

        <div className="toolbar-controls">
          <label>
            <span className="toolbar-label"><Icon name="filter" size={14} /> Filter</span>
            <select value={filter} onChange={(event) => onFilter(event.target.value as Filter)}>
              <option value="all">All active</option>
              <option value="due">Due soon</option>
              <option value="time-sensitive">Time-sensitive</option>
              <option value="collab">Collabs</option>
            </select>
          </label>
          <label>
            <span className="toolbar-label"><Icon name="task-list" size={14} /> Order</span>
            <select value={sort} onChange={(event) => onSort(event.target.value as Sort)}>
              <option value="position">toDō order</option>
              <option value="due">Due date</option>
              <option value="newest">Newest first</option>
            </select>
          </label>
          <label>
            <span className="toolbar-label"><Icon name="group" size={14} /> Group</span>
            <select value={group} onChange={(event) => onGroup(event.target.value as Group)}>
              <option value="none">No groups</option>
              <option value="due">Due date</option>
              <option value="collab">Collab</option>
            </select>
          </label>
        </div>
          <button
            className="reset-list-button"
            type="button"
            onClick={() => {
              onSearch("");
              onFilter("all");
              onSort("position");
              onGroup("none");
            }}
            disabled={!search && filter === "all" && sort === "position" && group === "none"}
            aria-label="Reset list view"
            title="Reset list view"
          >
            <Icon name="reset" />
          </button>
        </div>
      </section>

      {visibleTodos.length === 0 ? (
        <EmptyToDoState
          hasSearch={Boolean(search || filter !== "all")}
          filter={filter}
          onNewTodo={() => setIsComposerOpen(true)}
          onReset={() => {
            onSearch("");
            onFilter("all");
          }}
        />
      ) : (
        <div className="todo-list" aria-label="Active toDōs">
          {groups.map(([title, groupTodos]) => (
            <section className="todo-group" key={title}>
              {group !== "none" ? <h2 className="todo-group-title">{title}</h2> : null}
              <div className="todo-group-list">
                {groupTodos.map((todo) => (
                  <ToDoRow
                    key={todo.id}
                    todo={todo}
                    isUpdating={updatingTodoID === todo.id}
                    onComplete={() => void onCompletionChange(todo.id, true)}
                  />
                ))}
              </div>
            </section>
          ))}
        </div>
      )}

    </section>
  );
}

function ToDoRow({
  todo,
  isUpdating,
  onComplete,
}: {
  todo: TodoPresentation;
  isUpdating: boolean;
  onComplete: () => void;
}) {
  return (
    <div className={`todo-row${isOverdue(todo) ? " todo-row-overdue" : ""}`}>
      <button
        className="todo-complete-button"
        type="button"
        onClick={onComplete}
        disabled={isUpdating}
        aria-label={isUpdating ? `Completing ${todo.task}` : `Complete ${todo.task}`}
        aria-busy={isUpdating}
      >
        <span className="todo-status" aria-hidden="true" />
      </button>
      <Link className="todo-row-copy" href={`/todos/${todo.id}`}>
        <span className="todo-row-topline">
          <span className="todo-title">{todo.task}</span>
          {todo.tags[0] ? <span className="tag-pill">{todo.tags[0].name}</span> : null}
          {todo.tags.length > 1 ? <span className="tag-count">+{todo.tags.length - 1}</span> : null}
        </span>
        <span className="todo-meta">
          {isOverdue(todo) ? <span className="meta-chip meta-chip-overdue"><Icon name="alert" size={14} /> Overdue</span> : null}
          {todo.due_at ? <span className="meta-chip meta-chip-due"><Icon name="calendar" size={14} /> {formatDue(todo.due_at)}</span> : null}
          {todo.nanoDos.length ? <span className="meta-chip"><Icon name="task-list" size={14} /> {todo.nanoDos.filter((nanoDo) => nanoDo.is_done).length}/{todo.nanoDos.length}</span> : null}
          {todo.notes?.trim() ? <span className="meta-chip"><Icon name="copy" size={14} /> Notes</span> : null}
          {todo.due_at && todo.reminder_intent === "due" ? <span className="meta-chip"><Icon name="bell" size={14} /> Reminder</span> : null}
          {isTodoTimeSensitive(todo) ? <span className="meta-chip meta-chip-urgent"><Icon name="clock" size={14} /> Time-sensitive</span> : null}
          {todo.is_recurring ? <span className="meta-chip"><Icon name="repeat" size={14} /> {recurrenceLabel(todo)}</span> : null}
          {todo.collabName ? <span className="meta-chip meta-chip-collab"><Icon name="users" size={14} /> {todo.collabName}</span> : null}
        </span>
      </Link>
      <Link className="row-arrow" href={`/todos/${todo.id}`} aria-label={`Open ${todo.task}`}>
        <Icon name="arrow-right" />
      </Link>
    </div>
  );
}

function EmptyToDoState({
  hasSearch,
  filter,
  onNewTodo,
  onReset,
}: {
  hasSearch: boolean;
  filter: Filter;
  onNewTodo: () => void;
  onReset: () => void;
}) {
  const filterLabel = filter === "due" ? "Due soon" : filter === "time-sensitive" ? "Time-sensitive" : filter === "collab" ? "Collabs" : "this view";

  return (
    <section className="empty-state" aria-live="polite">
      <span className="empty-symbol" aria-hidden="true"><Icon name="plus" /></span>
      <h2>{hasSearch ? `No toDōs match ${filterLabel}.` : "Start with your first toDō."}</h2>
      <p>{hasSearch ? "Clear the current view or capture a fresh one." : "Capture it first; add details when you need them."}</p>
      <div className="empty-state-actions">
        <button className="home-new-button" type="button" onClick={onNewTodo}><Icon name="plus" /> New toDō</button>
        {hasSearch ? <button className="secondary-button" type="button" onClick={onReset}>Clear view</button> : null}
      </div>
    </section>
  );
}

function matchesSearch(todo: TodoPresentation, rawSearch: string) {
  const search = rawSearch.trim().toLocaleLowerCase();
  if (!search) return true;
  const haystack = [
    todo.task,
    todo.notes ?? "",
    todo.collabName ?? "",
    ...todo.tags.map((tag) => tag.name),
    ...todo.nanoDos.map((nanoDo) => nanoDo.task),
  ]
    .join(" ")
    .toLocaleLowerCase();
  return haystack.includes(search);
}

function matchesFilter(todo: TodoPresentation, filter: Filter) {
  switch (filter) {
    case "due":
      return isTodoDueSoon(todo);
    case "time-sensitive":
      return isTodoTimeSensitive(todo);
    case "collab":
      return Boolean(todo.collab_id);
    default:
      return true;
  }
}

function compareTodos(left: TodoPresentation, right: TodoPresentation, sort: Sort) {
  if (sort === "newest") {
    return timestamp(right.created_at) - timestamp(left.created_at);
  }
  if (sort === "due") {
    const leftDue = left.due_at ? timestamp(left.due_at) : Number.POSITIVE_INFINITY;
    const rightDue = right.due_at ? timestamp(right.due_at) : Number.POSITIVE_INFINITY;
    return leftDue - rightDue || timestamp(left.created_at) - timestamp(right.created_at);
  }
  return (left.sort_position ?? Number.POSITIVE_INFINITY) - (right.sort_position ?? Number.POSITIVE_INFINITY)
    || timestamp(left.created_at) - timestamp(right.created_at);
}

function groupTodos(todos: TodoPresentation[], group: Group) {
  if (group === "none") return [["", todos]] as [string, TodoPresentation[]][];
  const grouped = new Map<string, TodoPresentation[]>();
  for (const todo of todos) {
    const key = group === "collab" ? todo.collabName ?? "Personal" : dueGroup(todo.due_at);
    const existing = grouped.get(key) ?? [];
    existing.push(todo);
    grouped.set(key, existing);
  }
  return [...grouped.entries()];
}

function dueGroup(value: string | null) {
  if (!value) return "No due date";
  const date = new Date(value);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const dueDay = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  if (dueDay === today) return "Today";
  if (dueDay < today) return "Overdue";
  return "Upcoming";
}

function isOverdue(todo: TodoPresentation) {
  return isTodoOverdue(todo);
}

function timestamp(value: string | null) {
  return value ? new Date(value).getTime() : 0;
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

function recurrenceLabel(todo: TodoPresentation) {
  const interval = todo.recurrence_interval ?? 1;
  const unit = todo.recurrence_unit ?? "time";
  return `${interval} ${unit}${interval === 1 ? "" : "s"}`;
}
