-- notification_preferences.sql

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  reminders_enabled boolean not null default true,
  quiet_hours_start time,
  quiet_hours_end time,
  timezone text not null default 'UTC',
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

create policy "Users can view own notification preferences"
on public.notification_preferences
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own notification preferences"
on public.notification_preferences
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own notification preferences"
on public.notification_preferences
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);