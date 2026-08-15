-- Share toDō records inside a Collab while preserving creator ownership.
-- The database and product vocabulary both use Collab and User.

alter table public.todos
  add column if not exists collab_id uuid
  references public.collabs(id) on delete cascade;

create table if not exists public.sync_tombstones (
  user_id uuid not null references auth.users(id) on delete cascade,
  record_table text not null,
  record_id uuid not null,
  deleted_at timestamptz not null default now(),
  primary key (user_id, record_table, record_id)
);

alter table public.sync_tombstones
  add column if not exists collab_id uuid
  references public.collabs(id) on delete cascade;

create index if not exists todos_collab_id_idx
  on public.todos(collab_id)
  where collab_id is not null;

create index if not exists sync_tombstones_collab_id_deleted_at_idx
  on public.sync_tombstones(collab_id, deleted_at desc)
  where collab_id is not null;

create or replace function public.can_access_collab_todo(
  target_todo_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.todos todo
    where todo.id = target_todo_id
      and (
        todo.user_id = target_user_id
        or (
          todo.collab_id is not null
          and public.is_collab_user(todo.collab_id, target_user_id)
        )
      )
  );
$$;

create or replace function public.can_delete_collab_todo(
  target_todo_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.todos todo
    where todo.id = target_todo_id
      and (
        todo.user_id = target_user_id
        or (
          todo.collab_id is not null
          and public.is_collab_owner(todo.collab_id, target_user_id)
        )
      )
  );
$$;

create or replace function public.can_access_collab_tag(
  target_tag_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tags tag
    where tag.id = target_tag_id
      and tag.user_id = target_user_id
  )
  or exists (
    select 1
    from public.todo_tags relation
    where relation.tag_id = target_tag_id
      and public.can_access_collab_todo(relation.todo_id, target_user_id)
  );
$$;

create or replace function public.preserve_sync_record_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id then
    raise exception 'Record ownership cannot be transferred'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists preserve_todos_owner on public.todos;
create trigger preserve_todos_owner
before update on public.todos
for each row execute function public.preserve_sync_record_owner();

create or replace function public.preserve_todo_collab_ownership()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.collab_id is distinct from old.collab_id
     and old.user_id <> (select auth.uid()) then
    raise exception 'Only the toDō creator can change its Collab'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists preserve_todos_collab_ownership on public.todos;
create trigger preserve_todos_collab_ownership
before update on public.todos
for each row execute function public.preserve_todo_collab_ownership();

drop trigger if exists preserve_nanodos_owner on public.nanodos;
create trigger preserve_nanodos_owner
before update on public.nanodos
for each row execute function public.preserve_sync_record_owner();

alter table public.todos enable row level security;
alter table public.tags enable row level security;
alter table public.todo_tags enable row level security;
alter table public.nanodos enable row level security;
alter table public.sync_tombstones enable row level security;

drop policy if exists "Users can view own todos" on public.todos;
drop policy if exists "Users can insert own todos" on public.todos;
drop policy if exists "Users can update own todos" on public.todos;
drop policy if exists "Users can delete own todos" on public.todos;

create policy "todos_select_accessible"
on public.todos for select to authenticated
using (public.can_access_collab_todo(id, (select auth.uid())));

create policy "todos_insert_accessible"
on public.todos for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (
    collab_id is null
    or public.is_collab_user(collab_id, (select auth.uid()))
  )
);

create policy "todos_update_accessible"
on public.todos for update to authenticated
using (public.can_access_collab_todo(id, (select auth.uid())))
with check (
  public.can_access_collab_todo(id, (select auth.uid()))
  and (
    collab_id is null
    or public.is_collab_user(collab_id, (select auth.uid()))
  )
);

create policy "todos_delete_creator_or_collab_owner"
on public.todos for delete to authenticated
using (public.can_delete_collab_todo(id, (select auth.uid())));

drop policy if exists "tags_select_own" on public.tags;
create policy "tags_select_accessible"
on public.tags for select to authenticated
using (public.can_access_collab_tag(id, (select auth.uid())));

-- Tag names remain owned by their creator. Other Collab Users can attach an
-- accessible tag but cannot rename or delete somebody else's tag definition.
drop policy if exists "tags_insert_own" on public.tags;
create policy "tags_insert_own"
on public.tags for insert to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "tags_update_own" on public.tags;
create policy "tags_update_own"
on public.tags for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "tags_delete_own" on public.tags;
create policy "tags_delete_own"
on public.tags for delete to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "todo_tags_select_own" on public.todo_tags;
create policy "todo_tags_select_accessible"
on public.todo_tags for select to authenticated
using (public.can_access_collab_todo(todo_id, (select auth.uid())));

drop policy if exists "todo_tags_insert_own" on public.todo_tags;
create policy "todo_tags_insert_accessible"
on public.todo_tags for insert to authenticated
with check (
  public.can_access_collab_todo(todo_id, (select auth.uid()))
  and public.can_access_collab_tag(tag_id, (select auth.uid()))
);

drop policy if exists "todo_tags_delete_own" on public.todo_tags;
create policy "todo_tags_delete_accessible"
on public.todo_tags for delete to authenticated
using (public.can_access_collab_todo(todo_id, (select auth.uid())));

drop policy if exists "nanodos_select_own" on public.nanodos;
create policy "nanodos_select_accessible"
on public.nanodos for select to authenticated
using (public.can_access_collab_todo(todo_id, (select auth.uid())));

drop policy if exists "nanodos_insert_own" on public.nanodos;
create policy "nanodos_insert_accessible"
on public.nanodos for insert to authenticated
with check (
  user_id = (select auth.uid())
  and public.can_access_collab_todo(todo_id, (select auth.uid()))
);

drop policy if exists "nanodos_update_own" on public.nanodos;
create policy "nanodos_update_accessible"
on public.nanodos for update to authenticated
using (public.can_access_collab_todo(todo_id, (select auth.uid())))
with check (public.can_access_collab_todo(todo_id, (select auth.uid())));

drop policy if exists "nanodos_delete_own" on public.nanodos;
create policy "nanodos_delete_accessible"
on public.nanodos for delete to authenticated
using (public.can_access_collab_todo(todo_id, (select auth.uid())));

drop policy if exists "sync_tombstones_select_own" on public.sync_tombstones;
drop policy if exists "sync_tombstones_insert_own" on public.sync_tombstones;
drop policy if exists "sync_tombstones_update_own" on public.sync_tombstones;
drop policy if exists "sync_tombstones_delete_own" on public.sync_tombstones;

create policy "sync_tombstones_select_accessible"
on public.sync_tombstones for select to authenticated
using (
  user_id = (select auth.uid())
  or (
    collab_id is not null
    and public.is_collab_user(collab_id, (select auth.uid()))
  )
);

create policy "sync_tombstones_insert_accessible"
on public.sync_tombstones for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (
    collab_id is null
    or public.is_collab_user(collab_id, (select auth.uid()))
  )
);

create policy "sync_tombstones_update_own"
on public.sync_tombstones for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "sync_tombstones_delete_own"
on public.sync_tombstones for delete to authenticated
using (user_id = (select auth.uid()));

grant select, insert, update, delete on public.sync_tombstones to authenticated;

revoke all on function public.can_access_collab_todo(uuid, uuid) from public;
revoke all on function public.can_delete_collab_todo(uuid, uuid) from public;
revoke all on function public.can_access_collab_tag(uuid, uuid) from public;
grant execute on function public.can_access_collab_todo(uuid, uuid) to authenticated;
grant execute on function public.can_delete_collab_todo(uuid, uuid) to authenticated;
grant execute on function public.can_access_collab_tag(uuid, uuid) to authenticated;
revoke all on function public.is_collab_user(uuid, uuid) from public;
revoke all on function public.is_collab_owner(uuid, uuid) from public;
grant execute on function public.is_collab_user(uuid, uuid) to authenticated;
grant execute on function public.is_collab_owner(uuid, uuid) to authenticated;

revoke all on function public.preserve_sync_record_owner() from public;
revoke all on function public.preserve_todo_collab_ownership() from public;

-- Wake every User in the affected Collab. Personal changes still target only
-- the record owner. Realtime and RLS remain the source of actual data access.
create or replace function public.enqueue_todo_sync_push_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  resolved_owner_id uuid;
  resolved_collab_id uuid;
  resolved_record_id uuid;
begin
  if tg_table_name = 'todo_tags' then
    resolved_record_id := case when tg_op = 'DELETE' then old.todo_id else new.todo_id end;
    select todo.user_id, todo.collab_id
      into resolved_owner_id, resolved_collab_id
      from public.todos todo
      where todo.id = resolved_record_id;
  elsif tg_table_name = 'nanodos' then
    resolved_record_id := case when tg_op = 'DELETE' then old.id else new.id end;
    resolved_owner_id := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
    select todo.collab_id
      into resolved_collab_id
      from public.todos todo
      where todo.id = case when tg_op = 'DELETE' then old.todo_id else new.todo_id end;
  elsif tg_table_name = 'sync_tombstones' then
    resolved_owner_id := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
    resolved_collab_id := case when tg_op = 'DELETE' then old.collab_id else new.collab_id end;
    resolved_record_id := case when tg_op = 'DELETE' then old.record_id else new.record_id end;
  else
    resolved_owner_id := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
    resolved_record_id := case when tg_op = 'DELETE' then old.id else new.id end;
    if tg_table_name = 'todos' then
      resolved_collab_id := case when tg_op = 'DELETE' then old.collab_id else new.collab_id end;
    end if;
  end if;

  if resolved_owner_id is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  insert into public.sync_push_events (user_id, source_table, record_id, mutation_type)
  select recipient.user_id, tg_table_name, resolved_record_id, tg_op
  from (
    select resolved_owner_id as user_id
    union
    select member.user_id
    from public.collab_users member
    where (
      resolved_collab_id is not null
      and member.collab_id = resolved_collab_id
    )
    or (
      tg_table_name = 'tags'
      and member.collab_id in (
        select distinct todo.collab_id
        from public.todo_tags relation
        join public.todos todo on todo.id = relation.todo_id
        where relation.tag_id = resolved_record_id
          and todo.collab_id is not null
      )
    )
  ) recipient;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

comment on column public.todos.collab_id is
  'Optional shared Collab containing this toDō. SQL references retain legacy table names for compatibility.';

drop trigger if exists enqueue_sync_tombstones_sync_push_event
on public.sync_tombstones;

create trigger enqueue_sync_tombstones_sync_push_event
after insert or update or delete on public.sync_tombstones
for each row execute function public.enqueue_todo_sync_push_event();
