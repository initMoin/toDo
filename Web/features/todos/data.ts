import { supabase } from "@/lib/supabase";
import type {
  Collab,
  Entitlement,
  NanoDo,
  RemoteSnapshot,
  Tag,
  Todo,
  TodoPresentation,
  TodoTag,
} from "@/lib/types";

const TODO_COLUMNS = [
  "id",
  "user_id",
  "collab_id",
  "task",
  "notes",
  "is_done",
  "due_at",
  "due_time_zone",
  "completed_at",
  "lifecycle_state",
  "reminder_intent",
  "is_recurring",
  "recurrence_unit",
  "recurrence_interval",
  "recurrence_mode",
  "recurrence_count",
  "recurrence_anchor_at",
  "recurrence_end_at",
  "complete_when_all_nanodos_done",
  "sort_position",
  "trashed_at",
  "created_at",
  "updated_at",
].join(",");

export type TodoCompletionPatch = Pick<Todo, "is_done" | "completed_at" | "lifecycle_state">;

export function todoCompletionPatch(
  isDone: boolean,
  completedAt = new Date().toISOString(),
): TodoCompletionPatch {
  return {
    is_done: isDone,
    completed_at: isDone ? completedAt : null,
    lifecycle_state: isDone ? "done" : "active",
  };
}

export async function loadEntitlements(): Promise<Entitlement[]> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const { data, error } = await supabase
    .from("current_account_entitlements")
    .select(
      "account_id,entitlement_key,status,access_mode,expires_at,web_read_only_until,source_kind,source_product_id,updated_at",
    )
    .order("updated_at", { ascending: false });

  if (error) {
    throw error;
  }

  return (data ?? []) as Entitlement[];
}

export function hasWebPlusAccess(entitlements: Entitlement[]) {
  return entitlements.some(
    (entitlement) =>
      ["todo_plus", "legacy_3_1"].includes(entitlement.entitlement_key) &&
      ["active", "grace"].includes(entitlement.status) &&
      entitlement.access_mode === "full",
  );
}

export async function loadRemoteSnapshot(): Promise<RemoteSnapshot> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const [todosResult, nanoDosResult, tagsResult, todoTagsResult] =
    await Promise.all([
      supabase
        .from("todos")
        .select(TODO_COLUMNS)
        .order("sort_position", { ascending: true, nullsFirst: false })
        .order("created_at", { ascending: false }),
      supabase
        .from("nanodos")
        .select("id,todo_id,user_id,task,is_done,tag_id,due_at,created_at,updated_at")
        .order("created_at", { ascending: true }),
      supabase
        .from("tags")
        .select("id,user_id,name,is_default,created_at,updated_at")
        .order("name", { ascending: true }),
      supabase
        .from("todo_tags")
        .select("todo_id,tag_id,created_at"),
    ]);

  const requiredResults = [
    todosResult,
    nanoDosResult,
    tagsResult,
    todoTagsResult,
  ];
  const firstError = requiredResults.find((result) => result.error)?.error;
  if (firstError) {
    throw firstError;
  }

  let collabs: Collab[] = [];
  const collabsResult = await supabase
    .from("collabs")
    .select("id,name,owner_user_id")
    .order("name", { ascending: true });
  if (!collabsResult.error) {
    collabs = (collabsResult.data ?? []) as Collab[];
  }

  return {
    todos: (todosResult.data ?? []) as Todo[],
    nanoDos: (nanoDosResult.data ?? []) as NanoDo[],
    tags: (tagsResult.data ?? []) as Tag[],
    todoTags: (todoTagsResult.data ?? []) as TodoTag[],
    collabs,
  };
}

export async function loadCollabs(): Promise<Collab[]> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const { data, error } = await supabase
    .from("collabs")
    .select("id,name,owner_user_id")
    .order("name", { ascending: true });

  if (error) {
    throw error;
  }

  return (data ?? []) as Collab[];
}

export async function createCollab(name: string, ownerUserID: string): Promise<Collab> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const normalizedName = name.trim();
  if (!normalizedName) {
    throw new Error("Give this Collab a name.");
  }

  const { data, error } = await supabase
    .from("collabs")
    .insert({ name: normalizedName, owner_user_id: ownerUserID })
    .select("id,name,owner_user_id")
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error("The Collab could not be created.");
  }

  return data as Collab;
}

export async function updateTodoCompletion(todoId: string, isDone: boolean): Promise<Todo> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const { data, error } = await supabase
    .from("todos")
    .update(todoCompletionPatch(isDone))
    .eq("id", todoId)
    .select(TODO_COLUMNS)
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error("The toDō could not be updated.");
  }

  return data as Todo;
}

export type TodoLifecycleState = "active" | "done" | "archived" | "trashed";

export async function updateTodoLifecycle(todoId: string, lifecycleState: TodoLifecycleState): Promise<void> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const isDone = lifecycleState === "done";
  const { error } = await supabase
    .from("todos")
    .update({
      is_done: isDone,
      completed_at: isDone ? new Date().toISOString() : null,
      lifecycle_state: lifecycleState,
      trashed_at: lifecycleState === "trashed" ? new Date().toISOString() : null,
    })
    .eq("id", todoId);

  if (error) throw error;
}

export async function deleteTodoPermanently(todoId: string): Promise<void> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const { error } = await supabase.from("todos").delete().eq("id", todoId);
  if (error) throw error;
}

export async function deleteTodosForUser(userID: string): Promise<void> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const { error } = await supabase.from("todos").delete().eq("user_id", userID);
  if (error) throw error;
}

export async function createTag(name: string, userID: string): Promise<Tag> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const normalizedName = name.trim();
  if (!normalizedName) throw new Error("Give this tag a name.");

  const { data, error } = await supabase
    .from("tags")
    .insert({ name: normalizedName, user_id: userID, is_default: false })
    .select("id,user_id,name,is_default,created_at,updated_at")
    .single();

  if (error) throw error;
  if (!data) throw new Error("The tag could not be created.");
  return data as Tag;
}

export async function deleteTag(tagID: string): Promise<void> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const { error } = await supabase.from("tags").delete().eq("id", tagID);
  if (error) throw error;
}

export async function createTodo(task: string, userID: string): Promise<Todo> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const { data, error } = await supabase
    .from("todos")
    .insert({
      user_id: userID,
      task: task.trim(),
      is_done: false,
      lifecycle_state: "active",
    })
    .select(TODO_COLUMNS)
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error("The new toDō could not be saved.");
  }

  return data as Todo;
}

export function isVisibleActiveTodo(todo: Todo) {
  return (
    !todo.is_done &&
    !["archived", "trashed"].includes(todo.lifecycle_state ?? "active")
  );
}

export function isTodoOverdue(todo: Pick<Todo, "due_at">, now = Date.now()) {
  return Boolean(todo.due_at && new Date(todo.due_at).getTime() < now);
}

export function isTodoDueSoon(
  todo: Pick<Todo, "due_at">,
  now = Date.now(),
  horizonDays = 7,
) {
  if (!todo.due_at || isTodoOverdue(todo, now)) return false;
  const dueAt = new Date(todo.due_at).getTime();
  return dueAt <= now + horizonDays * 24 * 60 * 60 * 1000;
}

export function isTodoTimeSensitive(todo: Pick<Todo, "reminder_intent">) {
  return todo.reminder_intent === "time_sensitive";
}

export function presentTodo(
  todo: Todo,
  snapshot: RemoteSnapshot,
): TodoPresentation {
  const tagIDs = new Set(
    snapshot.todoTags
      .filter((relation) => relation.todo_id === todo.id)
      .map((relation) => relation.tag_id),
  );

  return {
    ...todo,
    nanoDos: snapshot.nanoDos.filter((nanoDo) => nanoDo.todo_id === todo.id),
    tags: snapshot.tags.filter((tag) => tagIDs.has(tag.id)),
    collabName:
      snapshot.collabs.find((collab) => collab.id === todo.collab_id)?.name ??
      (todo.collab_id ? "Collab" : null),
  };
}
