alter table public.todos
add column if not exists due_time_zone text,
add column if not exists is_recurring boolean not null default false,
add column if not exists recurrence_unit text,
add column if not exists recurrence_interval integer,
add column if not exists recurrence_mode text,
add column if not exists recurrence_count integer,
add column if not exists recurrence_anchor_at timestamptz,
add column if not exists recurrence_end_at timestamptz;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'todos_recurrence_unit_check'
    ) then
        alter table public.todos
        add constraint todos_recurrence_unit_check
        check (
            recurrence_unit is null
            or recurrence_unit in ('seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years')
        );
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

create index if not exists todos_user_recurrence_idx
on public.todos(user_id, is_recurring, recurrence_anchor_at);
