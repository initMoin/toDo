-- Align legacy generated Supabase schema with the current app contract.
-- This is intentionally non-destructive where possible.

-- 1) Ensure todos uses `task`, not old `missive` or interim `title` columns.
do $$
declare
  has_task boolean;
  has_title boolean;
  has_missive boolean;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'todos'
      and column_name = 'task'
  ) into has_task;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'todos'
      and column_name = 'title'
  ) into has_title;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'todos'
      and column_name = 'missive'
  ) into has_missive;

  if has_missive and not has_task then
    execute 'alter table public.todos rename column missive to task';
    has_task := true;
    has_missive := false;
  end if;

  if has_title and not has_task then
    execute 'alter table public.todos rename column title to task';
    has_task := true;
    has_title := false;
  end if;

  if not has_task then
    execute 'alter table public.todos add column task text';
    has_task := true;
  end if;

  if has_title then
    execute 'update public.todos set task = coalesce(task, title) where task is null';
  end if;

  if has_missive then
    execute 'update public.todos set task = coalesce(task, missive) where task is null';
  end if;
end $$;

update public.todos
set task = ''
where task is null;

alter table public.todos
alter column task set not null;

-- 2) Preserve legacy completion data if lifecycle state was introduced later.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'todos'
      and column_name = 'is_done'
  ) then
    update public.todos
    set lifecycle_state = 'done'
    where is_done = true
      and lifecycle_state = 'active';
  end if;
end $$;

-- 3) Migrate legacy `devices` rows into `device_tokens` if they exist.
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'devices'
  ) and exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'device_tokens'
  ) then
    insert into public.device_tokens (
      user_id,
      platform,
      push_provider,
      token,
      environment,
      is_active,
      last_seen_at,
      created_at,
      updated_at
    )
    select
      devices.user_id,
      devices.platform,
      'apns',
      devices.push_token,
      null,
      true,
      coalesce(devices.last_seen_at, now()),
      devices.created_at,
      coalesce(devices.last_seen_at, devices.created_at, now())
    from public.devices
    on conflict (push_provider, token) do nothing;
  end if;
end $$;
