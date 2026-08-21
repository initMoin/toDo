-- Personal collaboration foundations for toDō 3.1.
--
-- A collab is the personal shared-list boundary. Only owner and user
-- roles exist in 3.1. Free owners may have at most two accepted outgoing
-- users; verified toDō+ and legacy_3_1 accounts are unlimited.

create table if not exists public.collabs (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint collabs_name_length_check
    check (char_length(btrim(name)) between 1 and 80)
);

create table if not exists public.collab_users (
  collab_id uuid not null references public.collabs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null,
  invited_by_user_id uuid references auth.users(id) on delete set null,
  joined_at timestamptz not null default now(),
  primary key (collab_id, user_id),
  constraint collab_users_role_check
    check (role in ('owner', 'user'))
);

create table if not exists public.collab_invitations (
  id uuid primary key default gen_random_uuid(),
  collab_id uuid not null references public.collabs(id) on delete cascade,
  inviter_user_id uuid not null references auth.users(id) on delete cascade,
  invitee_email text not null,
  invitee_user_id uuid references auth.users(id) on delete set null,
  role text not null default 'user',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days'),
  responded_at timestamptz,
  constraint collab_invitations_email_check
    check (invitee_email = lower(btrim(invitee_email)) and position('@' in invitee_email) > 1),
  constraint collab_invitations_role_check
    check (role = 'user'),
  constraint collab_invitations_status_check
    check (status in ('pending', 'accepted', 'declined', 'canceled', 'expired'))
);

create index if not exists collabs_owner_user_id_idx
  on public.collabs(owner_user_id);

create index if not exists collab_users_user_id_idx
  on public.collab_users(user_id);

create index if not exists collab_users_inviter_idx
  on public.collab_users(invited_by_user_id)
  where role = 'user';

create index if not exists collab_invitations_invitee_user_idx
  on public.collab_invitations(invitee_user_id, status);

create index if not exists collab_invitations_invitee_email_idx
  on public.collab_invitations(invitee_email, status);

create unique index if not exists collab_invitations_one_pending_per_email
  on public.collab_invitations(collab_id, invitee_email)
  where status = 'pending';

drop trigger if exists set_collabs_updated_at on public.collabs;
create trigger set_collabs_updated_at
before update on public.collabs
for each row execute function public.set_updated_at();

drop trigger if exists set_collab_invitations_updated_at on public.collab_invitations;
create trigger set_collab_invitations_updated_at
before update on public.collab_invitations
for each row execute function public.set_updated_at();

create or replace function public.add_collab_owner_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.collab_users (collab_id, user_id, role, invited_by_user_id)
  values (new.id, new.owner_user_id, 'owner', null)
  on conflict (collab_id, user_id) do update set role = 'owner';
  return new;
end;
$$;

drop trigger if exists add_collab_owner_user on public.collabs;
create trigger add_collab_owner_user
after insert on public.collabs
for each row execute function public.add_collab_owner_user();

create or replace function public.account_has_unlimited_collaboration(target_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.account_entitlements entitlement
    where entitlement.account_id = target_account_id
      and entitlement.entitlement_key in ('todo_plus', 'legacy_3_1')
      and entitlement.status in ('active', 'grace')
      and (entitlement.expires_at is null or entitlement.expires_at > now())
  );
$$;

create or replace function public.accepted_outgoing_collaboration_count(target_owner_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.collab_users member
  join public.collabs collab on collab.id = member.collab_id
  where collab.owner_user_id = target_owner_id
    and member.role = 'user'
    and member.invited_by_user_id = target_owner_id;
$$;

create or replace function public.current_collaboration_access()
returns table (
  accepted_outgoing_count integer,
  outgoing_invitation_limit integer,
  has_unlimited_collaboration boolean,
  can_send_invitation boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
  accepted_count integer;
  has_unlimited boolean;
begin
  if current_account_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  accepted_count := public.accepted_outgoing_collaboration_count(current_account_id);
  has_unlimited := public.account_has_unlimited_collaboration(current_account_id);

  return query select
    accepted_count,
    case when has_unlimited then null else 2 end,
    has_unlimited,
    has_unlimited or accepted_count < 2;
end;
$$;

create or replace function public.send_collab_invitation(
  target_collab_id uuid,
  target_email text
)
returns public.collab_invitations
language plpgsql
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
  normalized_email text := lower(btrim(target_email));
  owner_id uuid;
  matched_invitee_id uuid;
  invitation public.collab_invitations;
begin
  if current_account_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select collab.owner_user_id into owner_id
  from public.collabs collab
  where collab.id = target_collab_id;

  if owner_id is null or owner_id <> current_account_id then
    raise exception 'Only the collab owner can send invitations' using errcode = '42501';
  end if;

  if position('@' in normalized_email) <= 1 then
    raise exception 'Enter a valid email address' using errcode = '22023';
  end if;

  if not public.account_has_unlimited_collaboration(current_account_id)
     and public.accepted_outgoing_collaboration_count(current_account_id) >= 2 then
    raise exception 'Free collaboration limit reached' using errcode = 'P0001';
  end if;

  select account.id into matched_invitee_id
  from auth.users account
  where lower(account.email) = normalized_email
  limit 1;

  if matched_invitee_id = current_account_id then
    raise exception 'You already own this collab' using errcode = '22023';
  end if;

  if matched_invitee_id is not null and exists (
    select 1
    from public.collab_users member
    where member.collab_id = target_collab_id
      and member.user_id = matched_invitee_id
  ) then
    raise exception 'This account is already in the collab' using errcode = '23505';
  end if;

  select existing.* into invitation
  from public.collab_invitations existing
  where existing.collab_id = target_collab_id
    and existing.invitee_email = normalized_email
    and existing.status = 'pending'
  for update;

  if invitation.id is not null then
    update public.collab_invitations
    set
      invitee_user_id = matched_invitee_id,
      expires_at = now() + interval '30 days',
      updated_at = now()
    where id = invitation.id
    returning * into invitation;
    return invitation;
  end if;

  insert into public.collab_invitations (
    collab_id,
    inviter_user_id,
    invitee_email,
    invitee_user_id
  ) values (
    target_collab_id,
    current_account_id,
    normalized_email,
    matched_invitee_id
  )
  returning * into invitation;

  return invitation;
end;
$$;

create or replace function public.accept_collab_invitation(target_invitation_id uuid)
returns public.collab_invitations
language plpgsql
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
  current_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  invitation public.collab_invitations;
  owner_id uuid;
begin
  if current_account_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select existing.* into invitation
  from public.collab_invitations existing
  where existing.id = target_invitation_id
  for update;

  if invitation.id is null then
    raise exception 'Invitation not found' using errcode = 'P0002';
  end if;

  if invitation.status = 'accepted' and invitation.invitee_user_id = current_account_id then
    return invitation;
  end if;

  if invitation.status <> 'pending' or invitation.expires_at <= now() then
    if invitation.status = 'pending' and invitation.expires_at <= now() then
      update public.collab_invitations
      set status = 'expired', responded_at = now()
      where id = invitation.id;
    end if;
    raise exception 'Invitation is no longer available' using errcode = 'P0001';
  end if;

  if invitation.invitee_user_id is distinct from current_account_id
     and invitation.invitee_email <> current_email then
    raise exception 'This invitation belongs to another account' using errcode = '42501';
  end if;

  select collab.owner_user_id into owner_id
  from public.collabs collab
  where collab.id = invitation.collab_id;

  -- Serialize acceptance for one owner so concurrent pending invitations cannot
  -- bypass the free account's two-user limit.
  perform pg_advisory_xact_lock(hashtextextended(owner_id::text, 0));

  if not public.account_has_unlimited_collaboration(owner_id)
     and public.accepted_outgoing_collaboration_count(owner_id) >= 2 then
    raise exception 'The collab owner has reached the free collaboration limit' using errcode = 'P0001';
  end if;

  insert into public.collab_users (
    collab_id,
    user_id,
    role,
    invited_by_user_id
  ) values (
    invitation.collab_id,
    current_account_id,
    'user',
    owner_id
  )
  on conflict (collab_id, user_id) do update set
    role = 'user',
    invited_by_user_id = owner_id;

  update public.collab_invitations
  set
    invitee_user_id = current_account_id,
    status = 'accepted',
    responded_at = now()
  where id = invitation.id
  returning * into invitation;

  return invitation;
end;
$$;

create or replace function public.decline_collab_invitation(target_invitation_id uuid)
returns public.collab_invitations
language plpgsql
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
  current_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  invitation public.collab_invitations;
begin
  select existing.* into invitation
  from public.collab_invitations existing
  where existing.id = target_invitation_id
  for update;

  if current_account_id is null
     or invitation.id is null
     or (
       invitation.invitee_user_id is distinct from current_account_id
       and invitation.invitee_email <> current_email
     ) then
    raise exception 'Invitation not found' using errcode = '42501';
  end if;

  if invitation.status = 'pending' then
    update public.collab_invitations
    set status = 'declined', responded_at = now()
    where id = invitation.id
    returning * into invitation;
  end if;

  return invitation;
end;
$$;

create or replace function public.cancel_collab_invitation(target_invitation_id uuid)
returns public.collab_invitations
language plpgsql
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
  invitation public.collab_invitations;
begin
  select existing.* into invitation
  from public.collab_invitations existing
  where existing.id = target_invitation_id
  for update;

  if current_account_id is null
     or invitation.id is null
     or invitation.inviter_user_id <> current_account_id then
    raise exception 'Invitation not found' using errcode = '42501';
  end if;

  if invitation.status = 'pending' then
    update public.collab_invitations
    set status = 'canceled', responded_at = now()
    where id = invitation.id
    returning * into invitation;
  end if;

  return invitation;
end;
$$;

create or replace function public.remove_collab_user(
  target_collab_id uuid,
  target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
begin
  if current_account_id is null or not exists (
    select 1 from public.collabs collab
    where collab.id = target_collab_id
      and collab.owner_user_id = current_account_id
  ) then
    raise exception 'Only the collab owner can remove users' using errcode = '42501';
  end if;

  delete from public.collab_users
  where collab_id = target_collab_id
    and user_id = target_user_id
    and role = 'user';
end;
$$;

create or replace function public.is_collab_owner(
  target_collab_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.collabs collab
    where collab.id = target_collab_id
      and collab.owner_user_id = target_user_id
  );
$$;

create or replace function public.is_collab_user(
  target_collab_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.collab_users member
    where member.collab_id = target_collab_id
      and member.user_id = target_user_id
  );
$$;

alter table public.collabs enable row level security;
alter table public.collab_users enable row level security;
alter table public.collab_invitations enable row level security;

drop policy if exists "collabs_select_member" on public.collabs;
create policy "collabs_select_member"
on public.collabs
for select
to authenticated
using (
  owner_user_id = (select auth.uid())
  or public.is_collab_user(id, (select auth.uid()))
);

drop policy if exists "collabs_insert_owner" on public.collabs;
create policy "collabs_insert_owner"
on public.collabs
for insert
to authenticated
with check (owner_user_id = (select auth.uid()));

drop policy if exists "collabs_update_owner" on public.collabs;
create policy "collabs_update_owner"
on public.collabs
for update
to authenticated
using (owner_user_id = (select auth.uid()))
with check (owner_user_id = (select auth.uid()));

drop policy if exists "collabs_delete_owner" on public.collabs;
create policy "collabs_delete_owner"
on public.collabs
for delete
to authenticated
using (owner_user_id = (select auth.uid()));

drop policy if exists "collab_users_select_collab_user" on public.collab_users;
create policy "collab_users_select_collab_user"
on public.collab_users
for select
to authenticated
using (
  user_id = (select auth.uid())
  or public.is_collab_owner(collab_id, (select auth.uid()))
);

drop policy if exists "collab_users_leave_self" on public.collab_users;
create policy "collab_users_leave_self"
on public.collab_users
for delete
to authenticated
using (user_id = (select auth.uid()) and role = 'user');

drop policy if exists "collab_invitations_select_participant" on public.collab_invitations;
create policy "collab_invitations_select_participant"
on public.collab_invitations
for select
to authenticated
using (
  inviter_user_id = (select auth.uid())
  or invitee_user_id = (select auth.uid())
  or invitee_email = lower(coalesce(auth.jwt() ->> 'email', ''))
);

revoke insert, update, delete on public.collab_users from authenticated;
revoke insert, update, delete on public.collab_invitations from authenticated;

grant select, insert, update, delete on public.collabs to authenticated;
grant select, delete on public.collab_users to authenticated;
grant select on public.collab_invitations to authenticated;

-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Keep every
-- privileged collaboration path closed unless the caller is authenticated or
-- the function is intentionally reserved for the service role.
revoke all on function public.add_collab_owner_user() from public;
revoke all on function public.current_collaboration_access() from public;
revoke all on function public.send_collab_invitation(uuid, text) from public;
revoke all on function public.accept_collab_invitation(uuid) from public;
revoke all on function public.decline_collab_invitation(uuid) from public;
revoke all on function public.cancel_collab_invitation(uuid) from public;
revoke all on function public.remove_collab_user(uuid, uuid) from public;
revoke all on function public.is_collab_owner(uuid, uuid) from public;
revoke all on function public.is_collab_user(uuid, uuid) from public;
revoke all on function public.account_has_unlimited_collaboration(uuid) from public;
revoke all on function public.accepted_outgoing_collaboration_count(uuid) from public;

grant execute on function public.current_collaboration_access() to authenticated;
grant execute on function public.send_collab_invitation(uuid, text) to authenticated;
grant execute on function public.accept_collab_invitation(uuid) to authenticated;
grant execute on function public.decline_collab_invitation(uuid) to authenticated;
grant execute on function public.cancel_collab_invitation(uuid) to authenticated;
grant execute on function public.remove_collab_user(uuid, uuid) to authenticated;
grant execute on function public.is_collab_owner(uuid, uuid) to authenticated;
grant execute on function public.is_collab_user(uuid, uuid) to authenticated;

grant execute on function public.account_has_unlimited_collaboration(uuid) to service_role;
grant execute on function public.accepted_outgoing_collaboration_count(uuid) to service_role;
