-- profiles.sql

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  username text,
  account_setup_version smallint not null default 1,
  display_name text,
  given_name text,
  family_name text,
  avatar_url text,
  preferred_time_zone text not null default 'UTC',
  constraint profiles_display_name_length_check check (
    display_name is null
    or char_length(btrim(display_name)) between 1 and 60
  )
);

create unique index if not exists profiles_username_lower_unique_idx
on public.profiles (lower(btrim(username)))
where username is not null;

create table if not exists public.account_roles (
  account_id uuid primary key references public.profiles(id) on delete cascade,
  role text not null check (role in ('user', 'admin', 'founder')),
  granted_by uuid,
  granted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.account_roles enable row level security;

create policy "Users can view own profile"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy "Users can insert own profile"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = id);

create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "Users can view own account role"
on public.account_roles
for select
to authenticated
using ((select auth.uid()) = account_id);

create or replace function public.set_profiles_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_profiles_updated_at();
