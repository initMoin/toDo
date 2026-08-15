-- Account deletion for toDō.
--
-- The destructive operation is intentionally callable only by the service role.
-- The delete-account Edge Function authenticates the caller first, then invokes
-- this function with the verified auth.users id.

create or replace function public.delete_account_data(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if target_user_id is null then
    raise exception 'Account id is required' using errcode = '22004';
  end if;

  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Service authorization required' using errcode = '42501';
  end if;

  -- Remove rows that would otherwise be retained by SET NULL or that contain
  -- account-linked commerce evidence. The remaining personal rows are removed
  -- by the profile/auth.users cascades below.
  delete from public.apple_iap_transactions
  where account_id = target_user_id;

  delete from public.apple_app_transaction_links
  where account_id = target_user_id;

  delete from public.apple_purchase_account_links
  where account_id = target_user_id;

  delete from public.account_entitlements
  where account_id = target_user_id;

  -- Invitations sent or received by this account are private account data.
  -- Removing owned collabs cascades their shared todos and membership rows;
  -- leaving a collab removes only this user's membership.
  delete from public.collab_invitations
  where inviter_user_id = target_user_id
     or invitee_user_id = target_user_id;

  delete from public.collab_users
  where user_id = target_user_id;

  delete from public.collabs
  where owner_user_id = target_user_id;

  delete from public.profiles
  where id = target_user_id;
end;
$$;

revoke all on function public.delete_account_data(uuid) from public, anon, authenticated;
grant execute on function public.delete_account_data(uuid) to service_role;
