-- Correct hosted Supabase schema to match the current ToDo app contract.
-- The app writes/reads `public.todos.task`; legacy schemas may still have a required `title` column.

begin;

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
  end if;

  if has_missive then
    update public.todos
    set task = coalesce(task, missive)
    where task is null;
  end if;
end $$;

update public.todos
set task = ''
where task is null;

alter table public.todos
alter column task set not null;

-- Remove the legacy blocker. If this column remains NOT NULL, app inserts that only
-- provide `task` fail with `null value in column "title"`.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'todos'
      and column_name = 'title'
  ) then
    alter table public.todos alter column title drop not null;
    alter table public.todos alter column title set default null;
  end if;
end $$;

select pg_notify('pgrst', 'reload schema');

commit;
