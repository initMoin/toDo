"use client";

import type { Collab, Tag } from "@/lib/types";
import { TodoEditor } from "./TodoEditor";
import type { TodoSaveResult } from "./data";

export function NewTodoComposer({
  userID,
  collabs,
  existingTags,
  onCreated,
  onCancel,
}: {
  userID: string;
  collabs: Collab[];
  existingTags: Tag[];
  onCreated: (result: TodoSaveResult) => void;
  onCancel: () => void;
}) {
  return <TodoEditor userID={userID} mode="create" collabs={collabs} existingTags={existingTags} onSaved={(result) => onCreated(result)} onCancel={onCancel} />;
}
