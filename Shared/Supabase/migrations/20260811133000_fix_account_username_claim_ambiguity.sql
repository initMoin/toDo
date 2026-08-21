begin;

-- The function's output column is also named username. Qualify table columns
-- so PL/pgSQL does not resolve reserved_usernames.username ambiguously.
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
    select 1
    from public.reserved_usernames as reserved
    where reserved.username = candidate
  ) then
    raise exception 'That username is reserved.' using errcode = '23505';
  end if;

  select p.username, p.account_setup_version
    into existing_username, existing_setup_version
  from public.profiles as p
  where p.id = current_account_id
  for update;

  if existing_username is not null
     and lower(btrim(existing_username)) <> candidate then
    raise exception 'This account already has a different username.'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.profiles as p
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
  from public.profiles as p
  where p.id = current_account_id;
exception
  when unique_violation then
    raise exception 'That username is already in use.' using errcode = '23505';
end;
$$;

revoke all on function public.claim_account_username(text) from public;
grant execute on function public.claim_account_username(text) to authenticated;

commit;
