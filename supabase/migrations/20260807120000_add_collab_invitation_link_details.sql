-- Recipient-only projection used by invitation deep links.
-- Do not expose email addresses or other private profile fields here.

create or replace function public.collab_invitation_details(target_invitation_id uuid)
returns table (
  invitation_id uuid,
  collab_id uuid,
  collab_name text,
  inviter_display_name text,
  inviter_username text,
  status text,
  expires_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
  current_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if current_account_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  return query
  select
    invitation.id,
    collab.id,
    collab.name,
    coalesce(
      nullif(btrim(profile.display_name), ''),
      nullif(btrim(concat_ws(' ', profile.given_name, profile.family_name)), '')
    ),
    profile.username,
    invitation.status,
    invitation.expires_at
  from public.collab_invitations invitation
  join public.collabs collab on collab.id = invitation.collab_id
  left join public.profiles profile on profile.id = invitation.inviter_user_id
  where invitation.id = target_invitation_id
    and invitation.status = 'pending'
    and invitation.expires_at > now()
    and (
      invitation.invitee_user_id = current_account_id
      or invitation.invitee_email = current_email
    );

  if not found then
    raise exception 'Invitation not found' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.collab_invitation_details(uuid) from public;
revoke all on function public.collab_invitation_details(uuid) from anon;
grant execute on function public.collab_invitation_details(uuid) to authenticated;

comment on function public.collab_invitation_details(uuid) is
  'Returns minimum invitation details only to the invited recipient.';
