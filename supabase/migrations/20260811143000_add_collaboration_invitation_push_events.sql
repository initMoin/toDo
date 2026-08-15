-- Notify the invitee and the owner when a collaboration invitation changes.
-- The existing sync_push_events webhook delivers the resulting APNs nudge.
-- This migration is intentionally forward-only and must be deployed separately.

alter table public.sync_push_events
  drop constraint if exists sync_push_events_source_table_check;

alter table public.sync_push_events
  add constraint sync_push_events_source_table_check
  check (
    source_table in (
      'todos',
      'tags',
      'nanodos',
      'todo_tags',
      'sync_tombstones',
      'collab_invitations'
    )
  );

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
  if tg_table_name = 'collab_invitations' then
    -- An invite can be created before its email belongs to an account. In
    -- that case there is no authenticated device to notify yet.
    if tg_op = 'DELETE' then
      return old;
    end if;

    if new.invitee_user_id is not null then
      insert into public.sync_push_events (
        user_id,
        source_table,
        record_id,
        mutation_type
      ) values (
        new.invitee_user_id,
        'collab_invitations',
        new.id,
        tg_op
      );
    end if;

    -- The owner needs a refresh when the invitee accepts, declines, cancels,
    -- or expires an invitation so its pending state cannot become stale.
    if tg_op = 'UPDATE'
       and (
         new.status is distinct from old.status
         or new.invitee_user_id is distinct from old.invitee_user_id
       )
       and new.inviter_user_id is not null
       and new.status in ('accepted', 'declined', 'canceled', 'expired') then
      insert into public.sync_push_events (
        user_id,
        source_table,
        record_id,
        mutation_type
      ) values (
        new.inviter_user_id,
        'collab_invitations',
        new.id,
        'UPDATE'
      );
    end if;

    return new;
  end if;

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

drop trigger if exists enqueue_collab_invitations_sync_push_event
on public.collab_invitations;

create trigger enqueue_collab_invitations_sync_push_event
after insert or update on public.collab_invitations
for each row execute function public.enqueue_todo_sync_push_event();
