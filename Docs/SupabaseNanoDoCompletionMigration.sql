alter table public.todos
add column if not exists complete_when_all_nanodos_done boolean not null default false;
