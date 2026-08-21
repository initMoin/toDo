-- todos.sql

create table if not exists public.todos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  missive text not null,
  notes text,
  is_done boolean not null default false,
  due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.todos enable row level security;

create policy "Users can view own todos"
on public.todos
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own todos"
on public.todos
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own todos"
on public.todos
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own todos"
on public.todos
for delete
to authenticated
using (auth.uid() = user_id);