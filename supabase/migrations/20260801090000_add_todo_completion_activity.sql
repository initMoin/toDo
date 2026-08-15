-- Persist the transition into Done so activity history is based on completion,
-- not on a later edit to the completed toDō.
alter table public.todos
  add column if not exists completed_at timestamptz;

update public.todos
set completed_at = coalesce(completed_at, updated_at)
where lifecycle_state = 'done'
  and completed_at is null;

create index if not exists todos_user_completed_at_idx
  on public.todos (user_id, completed_at desc)
  where lifecycle_state = 'done';

comment on column public.todos.completed_at is
  'Timestamp of the transition into the done state; legacy done rows are backfilled from updated_at.';
