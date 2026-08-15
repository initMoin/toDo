"use client";

import { useState } from "react";
import { Icon } from "@/components/Icon";
import type { Todo } from "@/lib/types";
import { createTodo } from "./data";

export function NewTodoComposer({
  userID,
  onCreated,
  onCancel,
}: {
  userID: string;
  onCreated: (todo: Todo) => void;
  onCancel: () => void;
}) {
  const [task, setTask] = useState("");
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const trimmedTask = task.trim();
    if (!trimmedTask || isSaving) return;

    setIsSaving(true);
    setError(null);
    try {
      const todo = await createTodo(trimmedTask, userID);
      onCreated(todo);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "The new toDō could not be saved.");
      setIsSaving(false);
    }
  }

  return (
    <section className="new-todo-composer" aria-labelledby="new-todo-title">
      <div className="new-todo-composer-heading">
        <div>
          <p className="eyebrow">Capture</p>
          <h2 id="new-todo-title">New toDō</h2>
        </div>
        <button className="composer-close" type="button" onClick={onCancel} aria-label="Close New toDō" title="Close New toDō">
          <Icon name="close" />
        </button>
      </div>
      <form onSubmit={handleSubmit}>
        <label className="sr-only" htmlFor="new-todo-task">What needs doing?</label>
        <textarea
          id="new-todo-task"
          className="new-todo-input"
          value={task}
          onChange={(event) => setTask(event.target.value)}
          placeholder="What needs doing?"
          rows={3}
        />
        {error ? <p className="inline-error" role="alert">{error}</p> : null}
        <div className="new-todo-composer-actions">
          <button className="secondary-button" type="button" onClick={onCancel} disabled={isSaving}>
            Cancel
          </button>
          <button className="primary-button" type="submit" disabled={!task.trim() || isSaving} aria-busy={isSaving}>
            {isSaving ? "Saving…" : "Save toDō"}
          </button>
        </div>
      </form>
    </section>
  );
}
