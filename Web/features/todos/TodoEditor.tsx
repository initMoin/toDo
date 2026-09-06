"use client";

import { useEffect, useMemo, useState, type FormEvent } from "react";
import { Icon } from "@/components/Icon";
import type { Collab, Tag, TodoEditorDraft, TodoEditorNanoDo, TodoPresentation } from "@/lib/types";
import { createTodo, TodoSaveError, updateTodoDetails, type TodoSaveResult } from "./data";
import { readStoredWebPreferences } from "@/lib/webPreferences";

export function TodoEditor({
  userID,
  mode,
  initialTodo,
  collabs,
  existingTags,
  onSaved,
  onCancel,
}: {
  userID: string;
  mode: "create" | "edit";
  initialTodo?: TodoPresentation | null;
  collabs: Collab[];
  existingTags: Tag[];
  onSaved: (result: TodoSaveResult, draft: TodoEditorDraft) => void;
  onCancel: () => void;
}) {
  const [draft, setDraft] = useState<TodoEditorDraft>(() => draftFromTodo(initialTodo));
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isPartiallySaved, setIsPartiallySaved] = useState(false);
  const [showTags, setShowTags] = useState(mode === "edit");
  useEffect(() => {
    if (mode === "edit") return;
    const timer = window.setTimeout(() => setShowTags(readStoredWebPreferences().tagsByDefault), 0);
    return () => window.clearTimeout(timer);
  }, [mode]);
  const tagSuggestions = useMemo(
    () => showTags
      ? existingTags.filter((tag) => !draft.tags.includes(tag.name)).slice(0, 8)
      : [],
    [draft.tags, existingTags, showTags],
  );

  function updateDraft(patch: Partial<TodoEditorDraft>) {
    setDraft((current) => ({ ...current, ...patch }));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (isSaving) return;

    setIsSaving(true);
    setError(null);
    setIsPartiallySaved(false);
    try {
      const result = mode === "create"
        ? await createTodo(draft, userID)
        : await updateTodoDetails(initialTodo?.id ?? "", draft);
      onSaved(result, draft);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "The toDō could not be saved.");
      setIsPartiallySaved(nextError instanceof TodoSaveError);
      setIsSaving(false);
    }
  }

  function addNanoDo() {
    updateDraft({
      nanoDos: [...draft.nanoDos, { task: "", is_done: false, due_at: null }],
    });
  }

  function updateNanoDo(index: number, patch: Partial<TodoEditorNanoDo>) {
    updateDraft({
      nanoDos: draft.nanoDos.map((nanoDo, itemIndex) => itemIndex === index ? { ...nanoDo, ...patch } : nanoDo),
    });
  }

  function removeNanoDo(index: number) {
    updateDraft({ nanoDos: draft.nanoDos.filter((_, itemIndex) => itemIndex !== index) });
  }

  function addTag(name: string) {
    const normalized = name.trim();
    if (!normalized || draft.tags.some((tag) => tag.toLocaleLowerCase() === normalized.toLocaleLowerCase())) return;
    updateDraft({ tags: [...draft.tags, normalized] });
  }

  return (
    <section className={`todo-editor todo-editor-${mode}`} aria-labelledby={`${mode}-todo-title`}>
      <div className="todo-editor-heading">
        <div>
          <p className="eyebrow">{mode === "create" ? "Capture" : "Edit"}</p>
          <h2 id={`${mode}-todo-title`}>{mode === "create" ? "New toDō" : "Edit toDō"}</h2>
        </div>
        <button className="composer-close" type="button" onClick={onCancel} aria-label="Close toDō editor" title="Close">
          <Icon name="close" />
        </button>
      </div>

      <form onSubmit={handleSubmit}>
        <label className="todo-editor-field todo-editor-task-field">
          <span className="todo-editor-label">toDō</span>
          <textarea
            value={draft.task}
            onChange={(event) => updateDraft({ task: event.target.value })}
            placeholder="What do you wanna toDō?"
            rows={2}
          />
        </label>

        <div className="todo-editor-attribute-grid">
          <label className="todo-editor-field">
            <span className="todo-editor-label"><Icon name="calendar" size={16} /> Due</span>
            <input
              type="datetime-local"
              value={toLocalDateTimeInput(draft.due_at)}
              onChange={(event) => updateDraft({ due_at: event.target.value ? toDueDateISO(event.target.value, readStoredWebPreferences().dueTime) : null })}
            />
          </label>

          <label className="todo-editor-field">
            <span className="todo-editor-label"><Icon name="bell" size={16} /> Reminder</span>
            <select
              value={draft.reminder_intent}
              disabled={!draft.due_at}
              onChange={(event) => updateDraft({ reminder_intent: event.target.value as TodoEditorDraft["reminder_intent"] })}
            >
              <option value="soft">Quiet</option>
              <option value="due">Due</option>
              <option value="timeSensitive">Time-Sensitive</option>
            </select>
          </label>

          <label className="todo-editor-field">
            <span className="todo-editor-label"><Icon name={draft.collab_id ? "users" : "group"} size={16} /> Save to</span>
            <select value={draft.collab_id ?? "personal"} onChange={(event) => updateDraft({ collab_id: event.target.value === "personal" ? null : event.target.value })}>
              <option value="personal">Personal</option>
              {collabs.map((collab) => <option value={collab.id} key={collab.id}>{collab.name}</option>)}
            </select>
          </label>

          {showTags ? (
            <label className="todo-editor-field">
              <span className="todo-editor-label"><Icon name="tag" size={16} /> Tags</span>
              <input
                type="text"
                value={draft.tags.join(", ")}
                onChange={(event) => updateDraft({ tags: event.target.value.split(",").map((tag) => tag.trim()).filter(Boolean) })}
                placeholder="work, personal"
              />
            </label>
          ) : null}
        </div>

        {tagSuggestions.length ? (
          <div className="todo-editor-suggestions" aria-label="Existing tags">
            {tagSuggestions.map((tag) => <button type="button" key={tag.id} onClick={() => addTag(tag.name)}>+ {tag.name}</button>)}
          </div>
        ) : null}

        <label className="todo-editor-field todo-editor-notes-field">
          <span className="todo-editor-label"><Icon name="copy" size={16} /> Notes</span>
          <textarea value={draft.notes} onChange={(event) => updateDraft({ notes: event.target.value })} placeholder="Add notes to help you complete this toDō." rows={3} />
        </label>

        <section className="todo-editor-section" aria-labelledby={`${mode}-repeat-title`}>
          <div className="todo-editor-section-heading">
            <div>
              <h3 id={`${mode}-repeat-title`}><Icon name="repeat" size={17} /> Repeat</h3>
              <p>Keep a recurring toDō on your list.</p>
            </div>
            <input
              className="todo-editor-toggle"
              type="checkbox"
              checked={draft.is_recurring}
              onChange={(event) => updateDraft({ is_recurring: event.target.checked })}
              aria-label="Repeat toDō"
            />
          </div>
          {draft.is_recurring ? (
            <div className="todo-editor-repeat-fields">
              <label className="todo-editor-field"><span className="todo-editor-label">Every</span><input type="number" min={1} max={999} value={draft.recurrence_interval ?? 1} onChange={(event) => updateDraft({ recurrence_interval: Number(event.target.value) || 1 })} /></label>
              <label className="todo-editor-field"><span className="todo-editor-label">Unit</span><select value={draft.recurrence_unit ?? "days"} onChange={(event) => updateDraft({ recurrence_unit: event.target.value })}>{["minutes", "hours", "days", "weeks", "months", "years"].map((unit) => <option value={unit} key={unit}>{unit}</option>)}</select></label>
              <label className="todo-editor-field"><span className="todo-editor-label">Mode</span><select value={draft.recurrence_mode ?? "continuous"} onChange={(event) => updateDraft({ recurrence_mode: event.target.value as TodoEditorDraft["recurrence_mode"] })}><option value="continuous">Continuous</option><option value="finite">Fixed count</option></select></label>
              {draft.recurrence_mode === "finite" ? <label className="todo-editor-field"><span className="todo-editor-label">Count</span><input type="number" min={1} max={365} value={draft.recurrence_count ?? 1} onChange={(event) => updateDraft({ recurrence_count: Number(event.target.value) || 1 })} /></label> : null}
            </div>
          ) : null}
        </section>

        <section className="todo-editor-section" aria-labelledby={`${mode}-nanodos-title`}>
          <div className="todo-editor-section-heading">
            <div>
              <h3 id={`${mode}-nanodos-title`}><Icon name="task-list" size={17} /> NanoDos</h3>
              <p>Break this toDō into smaller steps.</p>
            </div>
            <button className="icon-action-button" type="button" onClick={addNanoDo} aria-label="Add NanoDo" title="Add NanoDo"><Icon name="plus" /></button>
          </div>
          {draft.nanoDos.length ? (
            <div className="todo-editor-nanodos">
              {draft.nanoDos.map((nanoDo, index) => (
                <div className="todo-editor-nanodo" key={nanoDo.id ?? `new-${index}`}>
                  <input type="checkbox" checked={nanoDo.is_done} onChange={(event) => updateNanoDo(index, { is_done: event.target.checked })} aria-label={`Complete NanoDo ${index + 1}`} />
                  <input type="text" value={nanoDo.task} onChange={(event) => updateNanoDo(index, { task: event.target.value })} placeholder="NanoDo" aria-label={`NanoDo ${index + 1}`} />
                  <button className="icon-action-button icon-action-button-quiet" type="button" onClick={() => removeNanoDo(index)} aria-label={`Remove NanoDo ${index + 1}`} title="Remove NanoDo"><Icon name="close" size={16} /></button>
                </div>
              ))}
              <label className="todo-editor-check-row"><input type="checkbox" checked={draft.complete_when_all_nanodos_done} onChange={(event) => updateDraft({ complete_when_all_nanodos_done: event.target.checked })} /><span>Complete toDō when all NanoDos are done</span></label>
            </div>
          ) : <p className="todo-editor-empty">No NanoDos yet.</p>}
        </section>

        {error ? <p className="inline-error" role="alert">{error}</p> : null}
        {isPartiallySaved ? <button className="secondary-button" type="button" onClick={() => window.location.reload()}>Reload this view</button> : null}
        <div className="todo-editor-actions">
          <button className="secondary-button" type="button" onClick={onCancel} disabled={isSaving}>Cancel</button>
          <button className="primary-button todo-editor-save" type="submit" disabled={!draft.task.trim() || isSaving || isPartiallySaved} aria-busy={isSaving}><Icon name="check" size={18} /> {isSaving ? "Saving…" : mode === "create" ? "Save toDō" : "Update toDō"}</button>
        </div>
      </form>
    </section>
  );
}

function draftFromTodo(todo?: TodoPresentation | null): TodoEditorDraft {
  return {
    task: todo?.task ?? "",
    notes: todo?.notes ?? "",
    due_at: todo?.due_at ?? null,
    reminder_intent: todo?.reminder_intent === "time_sensitive" ? "timeSensitive" : (todo?.reminder_intent as TodoEditorDraft["reminder_intent"]) ?? "soft",
    is_recurring: Boolean(todo?.is_recurring),
    recurrence_unit: todo?.recurrence_unit ?? null,
    recurrence_interval: todo?.recurrence_interval ?? null,
    recurrence_mode: todo?.recurrence_mode as TodoEditorDraft["recurrence_mode"] ?? null,
    recurrence_count: todo?.recurrence_count ?? null,
    collab_id: todo?.collab_id ?? null,
    tags: todo?.tags.map((tag) => tag.name) ?? [],
    nanoDos: todo?.nanoDos.map((nanoDo) => ({ id: nanoDo.id, task: nanoDo.task, is_done: nanoDo.is_done, due_at: nanoDo.due_at })) ?? [],
    complete_when_all_nanodos_done: Boolean(todo?.complete_when_all_nanodos_done),
  };
}

function toLocalDateTimeInput(value: string | null) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const pad = (part: number) => String(part).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function toDueDateISO(value: string, defaultTime: string) {
  const [datePart, timePart] = value.split("T");
  const parsed = new Date(`${datePart}T${timePart || defaultTime}`);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}
