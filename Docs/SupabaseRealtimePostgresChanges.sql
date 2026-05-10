-- Enables Supabase Realtime Postgres Changes for ToDo Sync tables.
-- Apply in Supabase SQL Editor if Realtime is not already enabled for these tables.

do $$
begin
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

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'todo_tags'
  ) then
    alter publication supabase_realtime add table public.todo_tags;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sync_tombstones'
  ) then
    alter publication supabase_realtime add table public.sync_tombstones;
  end if;
end $$;
