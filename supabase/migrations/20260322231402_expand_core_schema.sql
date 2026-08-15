create extension if not exists pgcrypto;

-- 1) Expand existing core tables to match the planned schema

alter table public.profiles
  add column if not exists username text unique,
  add column if not exists given_name text,
  add column if not exists family_name text,
  add column if not exists avatar_url text,
  add column if not exists preferred_time_zone text,
  add column if not exists updated_at timestamptz not null default now();

alter table public.todos
  add column if not exists notes text not null default '',
  add column if not exists lifecycle_state text not null default 'active',
  add column if not exists reminder_intent text not null default 'soft',
  add column if not exists due_time_zone text,
  add column if not exists is_recurring boolean not null default false,
  add column if not exists recurrence_unit text,
  add column if not exists recurrence_interval integer,
  add column if not exists recurrence_mode text,
  add column if not exists recurrence_count integer,
  add column if not exists recurrence_anchor_at timestamptz,
  add column if not exists recurrence_end_at timestamptz,
  add column if not exists sort_position numeric;

-- 2) Constraints for todos

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'todos_lifecycle_state_check'
  ) then
    alter table public.todos
      add constraint todos_lifecycle_state_check
      check (lifecycle_state in ('active', 'done', 'archived'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'todos_reminder_intent_check'
  ) then
    alter table public.todos
      add constraint todos_reminder_intent_check
      check (reminder_intent in ('soft', 'due', 'timeSensitive'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'todos_recurrence_mode_check'
  ) then
    alter table public.todos
      add constraint todos_recurrence_mode_check
      check (
        recurrence_mode is null
        or recurrence_mode in ('finite', 'continuous')
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'todos_recurrence_interval_check'
  ) then
    alter table public.todos
      add constraint todos_recurrence_interval_check
      check (
        recurrence_interval is null
        or recurrence_interval > 0
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'todos_recurrence_count_check'
  ) then
    alter table public.todos
      add constraint todos_recurrence_count_check
      check (
        recurrence_count is null
        or recurrence_count >= 1
      );
  end if;
end $$;

-- 3) New tables

create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'tags_user_id_name_key'
  ) then
    alter table public.tags
      add constraint tags_user_id_name_key
      unique (user_id, name);
  end if;
end $$;

create table if not exists public.todo_tags (
  todo_id uuid not null references public.todos(id) on delete cascade,
  tag_id uuid not null references public.tags(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (todo_id, tag_id)
);

create table if not exists public.nanodos (
  id uuid primary key default gen_random_uuid(),
  todo_id uuid not null references public.todos(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  is_done boolean not null default false,
  due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null,
  push_provider text not null,
  token text not null,
  app_bundle_id text,
  environment text,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (push_provider, token)
);

-- 4) Updated-at trigger function

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_todos_updated_at on public.todos;
create trigger set_todos_updated_at
before update on public.todos
for each row execute function public.set_updated_at();

drop trigger if exists set_tags_updated_at on public.tags;
create trigger set_tags_updated_at
before update on public.tags
for each row execute function public.set_updated_at();

drop trigger if exists set_nanodos_updated_at on public.nanodos;
create trigger set_nanodos_updated_at
before update on public.nanodos
for each row execute function public.set_updated_at();

drop trigger if exists set_device_tokens_updated_at on public.device_tokens;
create trigger set_device_tokens_updated_at
before update on public.device_tokens
for each row execute function public.set_updated_at();

-- 5) Auto-create profiles for new auth users

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    display_name,
    given_name,
    family_name
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.raw_user_meta_data->>'given_name',
    new.raw_user_meta_data->>'family_name'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- 6) Enable RLS on new tables

alter table public.tags enable row level security;
alter table public.todo_tags enable row level security;
alter table public.nanodos enable row level security;
alter table public.device_tokens enable row level security;

-- 7) Policies for tags

drop policy if exists "tags_select_own" on public.tags;
create policy "tags_select_own"
on public.tags
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tags_insert_own" on public.tags;
create policy "tags_insert_own"
on public.tags
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "tags_update_own" on public.tags;
create policy "tags_update_own"
on public.tags
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "tags_delete_own" on public.tags;
create policy "tags_delete_own"
on public.tags
for delete
to authenticated
using ((select auth.uid()) = user_id);

-- 8) Policies for todo_tags

drop policy if exists "todo_tags_select_own" on public.todo_tags;
create policy "todo_tags_select_own"
on public.todo_tags
for select
to authenticated
using (
  exists (
    select 1
    from public.todos t
    where t.id = todo_tags.todo_id
      and t.user_id = (select auth.uid())
  )
);

drop policy if exists "todo_tags_insert_own" on public.todo_tags;
create policy "todo_tags_insert_own"
on public.todo_tags
for insert
to authenticated
with check (
  exists (
    select 1
    from public.todos t
    where t.id = todo_tags.todo_id
      and t.user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.tags g
    where g.id = todo_tags.tag_id
      and g.user_id = (select auth.uid())
  )
);

drop policy if exists "todo_tags_delete_own" on public.todo_tags;
create policy "todo_tags_delete_own"
on public.todo_tags
for delete
to authenticated
using (
  exists (
    select 1
    from public.todos t
    where t.id = todo_tags.todo_id
      and t.user_id = (select auth.uid())
  )
);

-- 9) Policies for nanodos

drop policy if exists "nanodos_select_own" on public.nanodos;
create policy "nanodos_select_own"
on public.nanodos
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "nanodos_insert_own" on public.nanodos;
create policy "nanodos_insert_own"
on public.nanodos
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "nanodos_update_own" on public.nanodos;
create policy "nanodos_update_own"
on public.nanodos
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "nanodos_delete_own" on public.nanodos;
create policy "nanodos_delete_own"
on public.nanodos
for delete
to authenticated
using ((select auth.uid()) = user_id);

-- 10) Policies for device_tokens

drop policy if exists "device_tokens_select_own" on public.device_tokens;
create policy "device_tokens_select_own"
on public.device_tokens
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "device_tokens_insert_own" on public.device_tokens;
create policy "device_tokens_insert_own"
on public.device_tokens
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "device_tokens_update_own" on public.device_tokens;
create policy "device_tokens_update_own"
on public.device_tokens
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "device_tokens_delete_own" on public.device_tokens;
create policy "device_tokens_delete_own"
on public.device_tokens
for delete
to authenticated
using ((select auth.uid()) = user_id);

-- 11) Indexes

create index if not exists todos_user_id_idx on public.todos(user_id);
create index if not exists todos_user_lifecycle_idx on public.todos(user_id, lifecycle_state);
create index if not exists todos_user_due_at_idx on public.todos(user_id, due_at);
create index if not exists todos_user_updated_at_idx on public.todos(user_id, updated_at desc);

create index if not exists tags_user_id_idx on public.tags(user_id);
create index if not exists tags_user_name_idx on public.tags(user_id, lower(name));

create index if not exists nanodos_user_id_idx on public.nanodos(user_id);
create index if not exists nanodos_todo_id_idx on public.nanodos(todo_id);

create index if not exists device_tokens_user_id_idx on public.device_tokens(user_id);
create index if not exists device_tokens_active_idx on public.device_tokens(user_id, is_active);