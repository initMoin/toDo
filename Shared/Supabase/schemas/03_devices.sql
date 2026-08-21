-- devices.sql

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null,
  push_token text not null,
  timezone text not null default 'UTC',
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.devices enable row level security;

create policy "Users can view own devices"
on public.devices
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own devices"
on public.devices
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own devices"
on public.devices
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own devices"
on public.devices
for delete
to authenticated
using (auth.uid() = user_id);