begin;

alter table public.todos
  add column if not exists trashed_at timestamptz;

alter table public.todos
  drop constraint if exists todos_lifecycle_state_check;

alter table public.todos
  add constraint todos_lifecycle_state_check
  check (lifecycle_state in ('active', 'done', 'archived', 'trashed'))
  not valid;

alter table public.todos
  validate constraint todos_lifecycle_state_check;

comment on column public.todos.trashed_at is
  'When the toDō entered the reversible Trash lifecycle. Null outside Trash.';

commit;
