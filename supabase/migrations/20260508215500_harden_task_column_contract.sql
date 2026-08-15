-- Harden the hosted Supabase schema around the current app naming contract.
-- The app writes/reads `task` for both todos and nanodos. Legacy schemas may still
-- contain `missive` or `title` columns that block inserts or break decoding.

begin;

-- ToDos: canonical column is public.todos.task.
do $$
declare
  has_task boolean;
  has_title boolean;
  has_missive boolean;
begin
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'todos'
      and column_name = 'task'
  ) into has_task;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'todos'
      and column_name = 'title'
  ) into has_title;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'todos'
      and column_name = 'missive'
  ) into has_missive;

  if has_missive and not has_task then
    alter table public.todos rename column missive to task;
    has_task := true;
    has_missive := false;
  end if;

  if has_title and not has_task then
    alter table public.todos rename column title to task;
    has_task := true;
    has_title := false;
  end if;

  if not has_task then
    alter table public.todos add column task text;
    has_task := true;
  end if;

  if has_title then
    update public.todos
    set task = coalesce(task, title)
    where task is null;

    alter table public.todos alter column title drop not null;
    alter table public.todos alter column title set default null;
  end if;

  if has_missive then
    update public.todos
    set task = coalesce(task, missive)
    where task is null;

    alter table public.todos alter column missive drop not null;
    alter table public.todos alter column missive set default null;
  end if;
end $$;

update public.todos
set task = ''
where task is null;

alter table public.todos
alter column task set default '',
alter column task set not null;

-- NanoDos: canonical column is public.nanodos.task.
do $$
declare
  has_task boolean;
  has_title boolean;
begin
  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'nanodos'
  ) then
    return;
  end if;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'nanodos'
      and column_name = 'task'
  ) into has_task;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'nanodos'
      and column_name = 'title'
  ) into has_title;

  if has_title and not has_task then
    alter table public.nanodos rename column title to task;
    has_task := true;
    has_title := false;
  end if;

  if not has_task then
    alter table public.nanodos add column task text;
    has_task := true;
  end if;

  if has_title then
    update public.nanodos
    set task = coalesce(task, title)
    where task is null;

    alter table public.nanodos alter column title drop not null;
    alter table public.nanodos alter column title set default null;
  end if;
end $$;

update public.nanodos
set task = ''
where task is null;

alter table public.nanodos
alter column task set default '',
alter column task set not null;

select pg_notify('pgrst', 'reload schema');

commit;
