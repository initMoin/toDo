export type Todo = {
  id: string;
  user_id: string;
  collab_id: string | null;
  task: string;
  notes: string | null;
  is_done: boolean;
  due_at: string | null;
  due_time_zone: string | null;
  completed_at: string | null;
  lifecycle_state: string | null;
  reminder_intent: string | null;
  is_recurring: boolean | null;
  recurrence_unit: string | null;
  recurrence_interval: number | null;
  recurrence_mode: string | null;
  recurrence_count: number | null;
  recurrence_anchor_at: string | null;
  recurrence_end_at: string | null;
  complete_when_all_nanodos_done: boolean | null;
  sort_position: number | null;
  trashed_at: string | null;
  created_at: string | null;
  updated_at: string | null;
};

export type NanoDo = {
  id: string;
  todo_id: string;
  user_id: string;
  task: string;
  is_done: boolean;
  tag_id: string | null;
  due_at: string | null;
  created_at: string | null;
  updated_at: string | null;
};

export type Tag = {
  id: string;
  user_id: string;
  name: string;
  is_default?: boolean | null;
  created_at?: string | null;
  updated_at?: string | null;
};

export type TodoTag = {
  todo_id: string;
  tag_id: string;
  created_at?: string | null;
};

export type Collab = {
  id: string;
  name: string;
  owner_user_id?: string | null;
};

export type Entitlement = {
  account_id: string;
  entitlement_key: string;
  status: string;
  access_mode: "full" | "read_only";
  expires_at: string | null;
  web_read_only_until: string | null;
  source_kind?: string | null;
  source_product_id?: string | null;
  updated_at?: string | null;
};

export type RemoteSnapshot = {
  todos: Todo[];
  nanoDos: NanoDo[];
  tags: Tag[];
  todoTags: TodoTag[];
  collabs: Collab[];
};

export type TodoPresentation = Todo & {
  nanoDos: NanoDo[];
  tags: Tag[];
  collabName: string | null;
};

export type TodoEditorNanoDo = {
  id?: string;
  task: string;
  is_done: boolean;
  due_at: string | null;
};

export type TodoEditorDraft = {
  task: string;
  notes: string;
  due_at: string | null;
  reminder_intent: "soft" | "due" | "timeSensitive";
  is_recurring: boolean;
  recurrence_unit: string | null;
  recurrence_interval: number | null;
  recurrence_mode: "finite" | "continuous" | null;
  recurrence_count: number | null;
  collab_id: string | null;
  tags: string[];
  nanoDos: TodoEditorNanoDo[];
  complete_when_all_nanodos_done: boolean;
};
