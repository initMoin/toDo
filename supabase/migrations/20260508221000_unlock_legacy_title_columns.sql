-- Emergency compatibility unlock for hosted databases that still have legacy title columns.
-- The app writes `task`; any leftover `title` column must not block inserts.

begin;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'todos'
      and column_name = 'title'
  ) then
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'todos'
        and column_name = 'task'
    ) then
      update public.todos
      set title = coalesce(title, task, '')
      where title is null;
    else
      update public.todos
      set title = coalesce(title, '')
      where title is null;
    end if;

    alter table public.todos alter column title set default '';
    alter table public.todos alter column title drop not null;
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'nanodos'
      and column_name = 'title'
  ) then
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'nanodos'
        and column_name = 'task'
    ) then
      update public.nanodos
      set title = coalesce(title, task, '')
      where title is null;
    else
      update public.nanodos
      set title = coalesce(title, '')
      where title is null;
    end if;

    alter table public.nanodos alter column title set default '';
    alter table public.nanodos alter column title drop not null;
  end if;
end $$;

select pg_notify('pgrst', 'reload schema');

commit;
