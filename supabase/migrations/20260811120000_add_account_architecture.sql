begin;

-- A profile is the public account locator, while auth.users.id remains the
-- immutable owner of every account-scoped record.
alter table public.profiles
  add column if not exists account_setup_version smallint not null default 1;

alter table public.profiles
  drop constraint if exists profiles_username_format_check;

alter table public.profiles
  add constraint profiles_username_format_check
  check (
    username is null
    or (
      char_length(username) between 3 and 30
      and username = lower(username)
      and username !~ '\\s'
      and username ~ '^[a-z0-9._]+$'
      and left(username, 1) <> '.'
      and right(username, 1) <> '.'
    )
  );

do $$
begin
  if exists (
    select 1
    from public.profiles
    where username is not null
    group by lower(btrim(username))
    having count(*) > 1
  ) then
    raise exception 'Existing profile usernames are not unique. Resolve duplicates before enabling account usernames.'
      using errcode = '23505';
  end if;
end;
$$;

create unique index if not exists profiles_username_lower_unique_idx
on public.profiles (lower(btrim(username)))
where username is not null;

create table if not exists public.reserved_usernames (
  username text primary key,
  created_at timestamptz not null default now(),
  constraint reserved_usernames_format_check check (
    username = lower(username)
    and username ~ '^[a-z0-9._]+$'
  )
);

insert into public.reserved_usernames (username)
values
  ('account'),
  ('admin'),
  ('administrator'),
  ('android'),
  ('apple'),
  ('founder'),
  ('google'),
  ('help'),
  ('ipad'),
  ('iphone'),
  ('mac'),
  ('null'),
  ('settings'),
  ('support'),
  ('system'),
  ('todo'),
  ('todos'),
  ('watch'),
  ('web')
on conflict (username) do nothing;

-- This table is server-owned. Clients receive role information only through
-- the guarded read/function below; they never receive write privileges.
create table if not exists public.account_roles (
  account_id uuid primary key references public.profiles(id) on delete cascade,
  role text not null check (role in ('user', 'admin', 'founder')),
  granted_by uuid,
  granted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.reserved_usernames enable row level security;
alter table public.account_roles enable row level security;

revoke all on table public.reserved_usernames from anon, authenticated;
revoke all on table public.account_roles from anon, authenticated;

grant select on table public.account_roles to authenticated;

drop policy if exists account_roles_select_own on public.account_roles;
create policy account_roles_select_own
on public.account_roles
for select
to authenticated
using ((select auth.uid()) = account_id);

create or replace function public.prevent_direct_account_identity_changes()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (
    new.username is distinct from old.username
    or new.account_setup_version is distinct from old.account_setup_version
  ) and coalesce(current_setting('todo.account_setup_claim', true), '') <> 'on' then
    raise exception 'Account identity changes must use the account setup flow.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_account_identity on public.profiles;
create trigger protect_profile_account_identity
before update on public.profiles
for each row execute function public.prevent_direct_account_identity_changes();

create or replace function public.is_username_available(requested_username text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  candidate text := lower(btrim(coalesce(requested_username, '')));
begin
  if char_length(candidate) < 3
     or char_length(candidate) > 30
     or candidate !~ '^[a-z0-9._]+$'
     or left(candidate, 1) = '.'
     or right(candidate, 1) = '.' then
    return false;
  end if;

  if exists (
    select 1
    from public.reserved_usernames
    where username = candidate
  ) then
    return false;
  end if;

  return not exists (
    select 1
    from public.profiles
    where lower(btrim(username)) = candidate
  );
end;
$$;

revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to anon, authenticated;

create or replace function public.claim_account_username(requested_username text)
returns table (
  account_id uuid,
  username text,
  account_setup_version smallint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_account_id uuid := auth.uid();
  candidate text := lower(btrim(coalesce(requested_username, '')));
  existing_username text;
  existing_setup_version smallint;
begin
  if current_account_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if char_length(candidate) < 3
     or char_length(candidate) > 30
     or candidate !~ '^[a-z0-9._]+$'
     or left(candidate, 1) = '.'
     or right(candidate, 1) = '.' then
    raise exception 'That username is not available.' using errcode = '22023';
  end if;

  if exists (
    select 1 from public.reserved_usernames where username = candidate
  ) then
    raise exception 'That username is reserved.' using errcode = '23505';
  end if;

  select p.username, p.account_setup_version
    into existing_username, existing_setup_version
  from public.profiles p
  where p.id = current_account_id
  for update;

  if existing_username is not null
     and lower(btrim(existing_username)) <> candidate then
    raise exception 'This account already has a different username.'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.profiles p
    where p.id <> current_account_id
      and lower(btrim(p.username)) = candidate
  ) then
    raise exception 'That username is already in use.' using errcode = '23505';
  end if;

  perform set_config('todo.account_setup_claim', 'on', true);

  if existing_username is null then
    insert into public.profiles (id, username, account_setup_version)
    values (current_account_id, candidate, 2)
    on conflict (id) do update
      set username = excluded.username,
          account_setup_version = greatest(
            coalesce(public.profiles.account_setup_version, 1),
            2
          );
  else
    update public.profiles
    set account_setup_version = greatest(coalesce(existing_setup_version, 1), 2)
    where id = current_account_id;
  end if;

  return query
  select p.id, p.username, p.account_setup_version
  from public.profiles p
  where p.id = current_account_id;
exception
  when unique_violation then
    raise exception 'That username is already in use.' using errcode = '23505';
end;
$$;

revoke all on function public.claim_account_username(text) from public;
grant execute on function public.claim_account_username(text) to authenticated;

create or replace function public.current_account_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select ar.role
      from public.account_roles ar
      where ar.account_id = auth.uid()
    ),
    'user'
  );
$$;

revoke all on function public.current_account_role() from public;
grant execute on function public.current_account_role() to authenticated;

-- This operation is intentionally not callable by normal clients. It is the
-- controlled assignment hook for the verified founder account UUID.
create or replace function public.assign_founder_role(target_account_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
    raise exception 'Founder role assignment requires the service role.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles where id = target_account_id) then
    raise exception 'The founder account must already exist.' using errcode = '22023';
  end if;

  insert into public.account_roles (account_id, role, granted_by)
  values (target_account_id, 'founder', null)
  on conflict (account_id) do update
    set role = 'founder',
        updated_at = now();
end;
$$;

revoke all on function public.assign_founder_role(uuid) from public, anon, authenticated;
grant execute on function public.assign_founder_role(uuid) to service_role;

commit;
