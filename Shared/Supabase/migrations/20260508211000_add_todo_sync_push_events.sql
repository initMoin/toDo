-- Outbox table for ToDo Sync push nudges.
-- Database Webhooks should call the `todo-sync-push` Edge Function on INSERT.

create table if not exists public.sync_push_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_table text not null,
  record_id uuid,
  mutation_type text not null,
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint sync_push_events_source_table_check
    check (source_table in ('todos', 'tags', 'nanodos', 'todo_tags', 'sync_tombstones')),
  constraint sync_push_events_mutation_type_check
    check (mutation_type in ('INSERT', 'UPDATE', 'DELETE'))
);

alter table public.sync_push_events enable row level security;

-- App users do not read or write the push outbox directly. Inserts happen from triggers,
-- and the Edge Function reads rows through a service-role webhook invocation.
drop policy if exists "sync_push_events_service_only" on public.sync_push_events;
create policy "sync_push_events_service_only"
on public.sync_push_events
for all
to service_role
using (true)
with check (true);

create index if not exists sync_push_events_user_created_at_idx
on public.sync_push_events (user_id, created_at desc);

create or replace function public.enqueue_todo_sync_push_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  resolved_user_id uuid;
  resolved_record_id uuid;
begin
  if tg_table_name = 'todo_tags' then
    if tg_op = 'DELETE' then
      resolved_record_id := old.todo_id;
    else
      resolved_record_id := new.todo_id;
    end if;

    select todos.user_id
      into resolved_user_id
      from public.todos
      where todos.id = resolved_record_id;
  else
    if tg_op = 'DELETE' then
      resolved_user_id := old.user_id;
      resolved_record_id := old.id;
    else
      resolved_user_id := new.user_id;
      resolved_record_id := new.id;
    end if;
  end if;

  if resolved_user_id is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  insert into public.sync_push_events (
    user_id,
    source_table,
    record_id,
    mutation_type
  ) values (
    resolved_user_id,
    tg_table_name,
    resolved_record_id,
    tg_op
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- Core sync records.
drop trigger if exists enqueue_todos_sync_push_event on public.todos;
create trigger enqueue_todos_sync_push_event
after insert or update or delete on public.todos
for each row execute function public.enqueue_todo_sync_push_event();

drop trigger if exists enqueue_tags_sync_push_event on public.tags;
create trigger enqueue_tags_sync_push_event
after insert or update or delete on public.tags
for each row execute function public.enqueue_todo_sync_push_event();

drop trigger if exists enqueue_nanodos_sync_push_event on public.nanodos;
create trigger enqueue_nanodos_sync_push_event
after insert or update or delete on public.nanodos
for each row execute function public.enqueue_todo_sync_push_event();

drop trigger if exists enqueue_todo_tags_sync_push_event on public.todo_tags;
create trigger enqueue_todo_tags_sync_push_event
after insert or update or delete on public.todo_tags
for each row execute function public.enqueue_todo_sync_push_event();

-- `sync_tombstones` is created by a later migration. Attach its trigger when
-- the table already exists; the later table migration attaches it otherwise.
do $$
begin
  if to_regclass('public.sync_tombstones') is not null then
    execute 'drop trigger if exists enqueue_sync_tombstones_sync_push_event on public.sync_tombstones';
    execute '
      create trigger enqueue_sync_tombstones_sync_push_event
      after insert or update or delete on public.sync_tombstones
      for each row execute function public.enqueue_todo_sync_push_event()
    ';
  end if;
end
$$;

-- Optional cleanup helper. Run manually or from a scheduled job later.
create or replace function public.delete_old_sync_push_events(retention interval default interval '7 days')
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer;
begin
  delete from public.sync_push_events
  where created_at < now() - retention;

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;
