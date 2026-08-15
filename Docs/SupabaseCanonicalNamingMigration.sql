-- Supabase canonical naming migration for ToDo.
-- Apply in Supabase SQL Editor after confirming no production clients still depend on
-- the old column names. This migration is idempotent for the current known mismatch.

begin;

do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'todos'
          and column_name = 'missive'
    ) and not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'todos'
          and column_name = 'task'
    ) then
        alter table public.todos rename column missive to task;
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
    ) and not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'nanodos'
          and column_name = 'task'
    ) then
        alter table public.nanodos rename column title to task;
    end if;
end $$;

select pg_notify('pgrst', 'reload schema');

commit;
