-- Enable Supabase Realtime Postgres Changes for ToDo Sync.
-- Required for open devices to receive database change events without a manual refresh.

do $$
begin
  if not exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'todos'
  ) then
    alter publication supabase_realtime add table public.todos;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'tags'
  ) then
    alter publication supabase_realtime add table public.tags;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'nanodos'
  ) then
    alter publication supabase_realtime add table public.nanodos;
  end if;

  -- if not exists (
  --   select 1 from pg_publication_tables
  --   where pubname = 'supabase_realtime'
  --     and schemaname = 'public'
  --     and tablename = 'sync_tombstones'
  -- ) then
  --   alter publication supabase_realtime add table public.sync_tombstones;
  -- end if;

  if to_regclass('public.sync_tombstones') is not null
    and not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'sync_tombstones'
    ) then
    execute 'alter publication supabase_realtime add table public.sync_tombstones';
  end if;
end $$;

-- Verification:
-- select schemaname, tablename
-- from pg_publication_tables
-- where pubname = 'supabase_realtime'
--   and schemaname = 'public'
--   and tablename in ('todos', 'tags', 'nanodos', 'sync_tombstones')
-- order by tablename;
