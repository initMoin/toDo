import { supabase } from "@/lib/supabase";
import type {
  Collab,
  Entitlement,
  NanoDo,
  RemoteSnapshot,
  Tag,
  Todo,
  TodoEditorDraft,
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

export type TodoSaveResult = {
  todo: Todo;
  nanoDos: NanoDo[];
  tags: Tag[];
  todoTags: TodoTag[];
  collabName: string | null;
};

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

export async function createTodo(
  draft: TodoEditorDraft | string,
  userID: string,
): Promise<TodoSaveResult> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const normalizedDraft = typeof draft === "string"
    ? defaultTodoDraft(draft)
    : normalizeTodoDraft(draft);

  const { data, error } = await supabase
    .from("todos")
    .insert({
      user_id: userID,
      task: normalizedDraft.task,
      notes: normalizedDraft.notes,
      is_done: false,
      lifecycle_state: "active",
      due_at: normalizedDraft.due_at,
      reminder_intent: normalizedDraft.reminder_intent,
      is_recurring: normalizedDraft.is_recurring,
      recurrence_unit: normalizedDraft.is_recurring ? normalizedDraft.recurrence_unit : null,
      recurrence_interval: normalizedDraft.is_recurring ? normalizedDraft.recurrence_interval : null,
      recurrence_mode: normalizedDraft.is_recurring ? normalizedDraft.recurrence_mode : null,
      recurrence_count: normalizedDraft.is_recurring && normalizedDraft.recurrence_mode === "finite"
        ? normalizedDraft.recurrence_count
        : null,
      complete_when_all_nanodos_done: normalizedDraft.complete_when_all_nanodos_done,
      collab_id: normalizedDraft.collab_id,
    })
    .select(TODO_COLUMNS)
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error("The new toDō could not be saved.");
  }

  return saveTodoRelations(data as Todo, normalizedDraft);
}

export async function updateTodoDetails(
  todoID: string,
  draft: TodoEditorDraft,
): Promise<TodoSaveResult> {
  if (!supabase) {
    throw new Error("Supabase is not configured for this local Web build.");
  }

  const normalizedDraft = normalizeTodoDraft(draft);
  const { data, error } = await supabase
    .from("todos")
    .update({
      task: normalizedDraft.task,
      notes: normalizedDraft.notes,
      due_at: normalizedDraft.due_at,
      reminder_intent: normalizedDraft.reminder_intent,
      is_recurring: normalizedDraft.is_recurring,
      recurrence_unit: normalizedDraft.is_recurring ? normalizedDraft.recurrence_unit : null,
      recurrence_interval: normalizedDraft.is_recurring ? normalizedDraft.recurrence_interval : null,
      recurrence_mode: normalizedDraft.is_recurring ? normalizedDraft.recurrence_mode : null,
      recurrence_count: normalizedDraft.is_recurring && normalizedDraft.recurrence_mode === "finite"
        ? normalizedDraft.recurrence_count
        : null,
      complete_when_all_nanodos_done: normalizedDraft.complete_when_all_nanodos_done,
      collab_id: normalizedDraft.collab_id,
    })
    .eq("id", todoID)
    .select(TODO_COLUMNS)
    .single();

  if (error) throw error;
  if (!data) throw new Error("The toDō could not be updated.");

  return saveTodoRelations(data as Todo, normalizedDraft);
}

async function saveTodoRelations(todo: Todo, draft: TodoEditorDraft): Promise<TodoSaveResult> {
  if (!supabase) throw new Error("Supabase is not configured for this local Web build.");

  const tags = await resolveTags(draft.tags, todo.user_id);
  const { error: deleteTagError } = await supabase.from("todo_tags").delete().eq("todo_id", todo.id);
  if (deleteTagError) throw deleteTagError;

  const todoTags = tags.length
    ? tags.map((tag) => ({ todo_id: todo.id, tag_id: tag.id }))
    : [];
  if (todoTags.length) {
    const { error } = await supabase.from("todo_tags").insert(todoTags);
    if (error) throw error;
  }

  const { error: deleteNanoDoError } = await supabase.from("nanodos").delete().eq("todo_id", todo.id);
  if (deleteNanoDoError) throw deleteNanoDoError;

  const nanoDoDrafts = draft.nanoDos.filter((nanoDo) => nanoDo.task.trim());
  const { data: nanoDos, error: nanoDoError } = nanoDoDrafts.length
    ? await supabase
      .from("nanodos")
      .insert(nanoDoDrafts.map((nanoDo) => ({
        todo_id: todo.id,
        user_id: todo.user_id,
        task: nanoDo.task.trim(),
        is_done: nanoDo.is_done,
        due_at: nanoDo.due_at,
      })))
      .select("id,todo_id,user_id,task,is_done,tag_id,due_at,created_at,updated_at")
    : { data: [], error: null };
  if (nanoDoError) throw nanoDoError;

  let collabName: string | null = null;
  if (todo.collab_id) {
    const collabResult = await supabase
      .from("collabs")
      .select("name")
      .eq("id", todo.collab_id)
      .maybeSingle();
    if (!collabResult.error) collabName = collabResult.data?.name ?? "Collab";
  }

  return {
    todo,
    nanoDos: (nanoDos ?? []) as NanoDo[],
    tags,
    todoTags,
    collabName,
  };
}

async function resolveTags(names: string[], userID: string): Promise<Tag[]> {
  if (!supabase) throw new Error("Supabase is not configured for this local Web build.");

  const normalizedNames = [...new Set(names.map((name) => name.trim()).filter(Boolean))];
  if (!normalizedNames.length) return [];

  const { data: existing, error } = await supabase
    .from("tags")
    .select("id,user_id,name,is_default,created_at,updated_at")
    .eq("user_id", userID);
  if (error) throw error;

  const tags = (existing ?? []) as Tag[];
  const resolved: Tag[] = [];
  for (const name of normalizedNames) {
    const existingTag = tags.find((tag) => tag.name.toLocaleLowerCase() === name.toLocaleLowerCase());
    if (existingTag) {
      resolved.push(existingTag);
      continue;
    }
    resolved.push(await createTag(name, userID));
  }
  return resolved;
}

function defaultTodoDraft(task: string): TodoEditorDraft {
  return {
    task,
    notes: "",
    due_at: null,
    reminder_intent: "soft",
    is_recurring: false,
    recurrence_unit: null,
    recurrence_interval: null,
    recurrence_mode: null,
    recurrence_count: null,
    collab_id: null,
    tags: [],
    nanoDos: [],
    complete_when_all_nanodos_done: false,
  };
}

function normalizeTodoDraft(draft: TodoEditorDraft): TodoEditorDraft {
  const task = draft.task.trim();
  if (!task) throw new Error("Give this toDō a task.");

  const isRecurring = Boolean(draft.is_recurring);
  return {
    ...draft,
    task,
    notes: draft.notes.trim(),
    due_at: draft.due_at || null,
    reminder_intent: draft.due_at ? draft.reminder_intent : "soft",
    is_recurring: isRecurring,
    recurrence_unit: isRecurring ? draft.recurrence_unit ?? "days" : null,
    recurrence_interval: isRecurring ? Math.max(1, draft.recurrence_interval ?? 1) : null,
    recurrence_mode: isRecurring ? draft.recurrence_mode ?? "continuous" : null,
    recurrence_count: isRecurring && draft.recurrence_mode === "finite"
      ? Math.max(1, draft.recurrence_count ?? 1)
      : null,
    tags: [...new Set(draft.tags.map((tag) => tag.trim()).filter(Boolean))],
    nanoDos: draft.nanoDos.map((nanoDo) => ({
      ...nanoDo,
      task: nanoDo.task.trim(),
      due_at: nanoDo.due_at || null,
    })),
  };
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
  return todo.reminder_intent === "timeSensitive" || todo.reminder_intent === "time_sensitive";
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
