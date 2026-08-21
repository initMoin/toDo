create table if not exists public.live_activity_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'ios',
  token_type text not null,
  token text not null,
  activity_id text,
  todo_id uuid references public.todos(id) on delete cascade,
  todo_identifier text,
  app_bundle_id text,
  environment text,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint live_activity_tokens_token_type_check
    check (token_type in ('push_to_start', 'update')),
  unique (token_type, token)
);

create index if not exists live_activity_tokens_user_type_idx
  on public.live_activity_tokens(user_id, token_type, is_active);

create index if not exists live_activity_tokens_user_todo_idx
  on public.live_activity_tokens(user_id, todo_id, token_type, is_active);

drop trigger if exists set_live_activity_tokens_updated_at on public.live_activity_tokens;
create trigger set_live_activity_tokens_updated_at
before update on public.live_activity_tokens
for each row
execute function public.set_updated_at();

alter table public.live_activity_tokens enable row level security;

drop policy if exists "Users can view own live activity tokens" on public.live_activity_tokens;
create policy "Users can view own live activity tokens"
  on public.live_activity_tokens
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own live activity tokens" on public.live_activity_tokens;
create policy "Users can insert own live activity tokens"
  on public.live_activity_tokens
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own live activity tokens" on public.live_activity_tokens;
create policy "Users can update own live activity tokens"
  on public.live_activity_tokens
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own live activity tokens" on public.live_activity_tokens;
create policy "Users can delete own live activity tokens"
  on public.live_activity_tokens
  for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on table public.live_activity_tokens to authenticated;
grant all on table public.live_activity_tokens to service_role;
