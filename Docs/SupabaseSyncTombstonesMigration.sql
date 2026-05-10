-- Durable delete markers for ToDo Sync.
-- Apply in Supabase SQL Editor, then run the app build that writes tombstones.

begin;

create table if not exists public.sync_tombstones (
    user_id uuid not null references auth.users(id) on delete cascade,
    record_table text not null,
    record_id uuid not null,
    deleted_at timestamp with time zone not null default now(),
    created_at timestamp with time zone not null default now(),
    primary key (user_id, record_table, record_id),
    constraint sync_tombstones_record_table_check
        check (record_table in ('todos', 'nanodos', 'tags'))
);

alter table public.sync_tombstones enable row level security;

drop policy if exists "sync_tombstones_select_own" on public.sync_tombstones;
drop policy if exists "sync_tombstones_insert_own" on public.sync_tombstones;
drop policy if exists "sync_tombstones_update_own" on public.sync_tombstones;
drop policy if exists "sync_tombstones_delete_own" on public.sync_tombstones;

create policy "sync_tombstones_select_own"
on public.sync_tombstones
for select
using (auth.uid() = user_id);

create policy "sync_tombstones_insert_own"
on public.sync_tombstones
for insert
with check (auth.uid() = user_id);

create policy "sync_tombstones_update_own"
on public.sync_tombstones
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "sync_tombstones_delete_own"
on public.sync_tombstones
for delete
using (auth.uid() = user_id);

create index if not exists sync_tombstones_user_deleted_at_idx
on public.sync_tombstones (user_id, deleted_at desc);

select pg_notify('pgrst', 'reload schema');

commit;
