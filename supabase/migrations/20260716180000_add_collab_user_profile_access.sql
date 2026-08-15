-- Privacy-safe profile projection for Users in the same Collab.
-- This function intentionally returns no email, provider, entitlement, time-zone,
-- task, or unrelated-Collab data.

alter table public.profiles
  drop constraint if exists profiles_display_name_length_check;

alter table public.profiles
  add constraint profiles_display_name_length_check
  check (
    display_name is null
    or char_length(btrim(display_name)) between 1 and 60
  ) not valid;

drop function if exists public.collab_user_profiles_for_collab(uuid, integer, integer);

create or replace function public.collab_user_profiles_for_collab(
  target_collab_id uuid,
  result_limit integer default 100,
  result_offset integer default 0
)
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  role text,
  collab_id uuid,
  collab_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_account_id uuid := auth.uid();
begin
  if current_account_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.collab_users viewer
    where viewer.collab_id = target_collab_id
      and viewer.user_id = current_account_id
  ) then
    raise exception 'Collab access required'
      using errcode = '42501';
  end if;

  return query
  select
    member.user_id,
    nullif(btrim(profile.display_name), ''),
    profile.avatar_url,
    member.role::text,
    collab.id,
    collab.name
  from public.collab_users member
  join public.collabs collab on collab.id = member.collab_id
  left join public.profiles profile on profile.id = member.user_id
  where member.collab_id = target_collab_id
  order by
    case when member.role::text = 'owner' then 0 else 1 end,
    lower(coalesce(nullif(btrim(profile.display_name), ''), member.user_id::text)),
    member.user_id
  limit least(greatest(result_limit, 1), 100)
  offset greatest(result_offset, 0);
end;
$$;

revoke all on function public.collab_user_profiles_for_collab(uuid, integer, integer) from public;
revoke all on function public.collab_user_profiles_for_collab(uuid, integer, integer) from anon;
grant execute on function public.collab_user_profiles_for_collab(uuid, integer, integer) to authenticated;

comment on function public.collab_user_profiles_for_collab(uuid, integer, integer) is
  'Returns the minimum User identity projection for members of one Collab.';
