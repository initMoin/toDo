-- Fix push-event trigger record ID resolution for tables without an `id` column.
-- `sync_tombstones` uses a composite primary key, so referencing new.id/old.id
-- causes sync writes to fail with: record "new" has no field "id".

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
  elsif tg_table_name = 'sync_tombstones' then
    if tg_op = 'DELETE' then
      resolved_user_id := old.user_id;
      resolved_record_id := old.record_id;
    else
      resolved_user_id := new.user_id;
      resolved_record_id := new.record_id;
    end if;
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
