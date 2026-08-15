-- Reconcile Legacy access from the account's server-side creation date.
--
-- Legacy is not a StoreKit product and must not depend on a client-provided
-- date, an editable preference, or an AppTransaction sent by the app. The
-- release operator supplies the public 3.1 release instant once, after which
-- this idempotent service-role function grants both durable Legacy access and
-- Founding Supporter recognition to accounts that existed before that instant.
--
-- The function is deliberately not executable by authenticated users. Run it
-- from a controlled production SQL session after the release cutoff is known.

create or replace function public.reconcile_legacy_pre_release_accounts(
  release_cutoff timestamptz
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  qualified_accounts integer;
  release_source_id text;
begin
  if release_cutoff is null then
    raise exception 'release_cutoff is required';
  end if;

  if release_cutoff >= now() then
    raise exception 'release_cutoff must be in the past';
  end if;

  release_source_id := 'legacy_3_1_release_' || to_char(
    release_cutoff at time zone 'UTC',
    'YYYYMMDDHH24MISS'
  );

  select count(*)::integer
  into qualified_accounts
  from auth.users as account
  join public.profiles as profile on profile.id = account.id
  where account.email is not null
    and account.created_at < release_cutoff;

  -- Remove active grandfathering rows for accounts that do not meet the
  -- account-owned rule. Keep the rows as revoked audit history.
  update public.account_entitlements as entitlement
  set
    status = 'revoked',
    revoked_at = coalesce(entitlement.revoked_at, now()),
    updated_at = now()
  where entitlement.source_kind = 'grandfathering'
    and entitlement.entitlement_key in ('legacy_3_1', 'founding_supporter')
    and entitlement.status in ('active', 'grace')
    and not exists (
      select 1
      from auth.users as account
      join public.profiles as profile on profile.id = account.id
      where account.id = entitlement.account_id
        and account.email is not null
        and account.created_at < release_cutoff
    );

  -- Retire older grandfathering source rows for qualifying accounts so the
  -- effective view contains one active row per durable entitlement.
  update public.account_entitlements as entitlement
  set
    status = 'revoked',
    revoked_at = coalesce(entitlement.revoked_at, now()),
    updated_at = now()
  where entitlement.source_kind = 'grandfathering'
    and entitlement.source_id <> release_source_id
    and entitlement.entitlement_key in ('legacy_3_1', 'founding_supporter')
    and entitlement.status in ('active', 'grace')
    and exists (
      select 1
      from auth.users as account
      join public.profiles as profile on profile.id = account.id
      where account.id = entitlement.account_id
        and account.email is not null
        and account.created_at < release_cutoff
    );

  insert into public.account_entitlements (
    account_id,
    entitlement_key,
    source_kind,
    source_id,
    status,
    ownership_type,
    granted_at,
    revoked_at,
    updated_at
  )
  select
    account.id,
    entitlement.entitlement_key,
    'grandfathering',
    release_source_id,
    'active',
    'PRE_3_1_LEGACY_USER',
    now(),
    null,
    now()
  from auth.users as account
  join public.profiles as profile on profile.id = account.id
  cross join (
    values
      ('legacy_3_1'::text),
      ('founding_supporter'::text)
  ) as entitlement(entitlement_key)
  where account.email is not null
    and account.created_at < release_cutoff
  on conflict (account_id, entitlement_key, source_kind, source_id)
  do update set
    status = 'active',
    ownership_type = 'PRE_3_1_LEGACY_USER',
    revoked_at = null,
    updated_at = now();

  return qualified_accounts;
end;
$$;

revoke all on function public.reconcile_legacy_pre_release_accounts(timestamptz)
from public;
revoke all on function public.reconcile_legacy_pre_release_accounts(timestamptz)
from anon;
revoke all on function public.reconcile_legacy_pre_release_accounts(timestamptz)
from authenticated;
grant execute on function public.reconcile_legacy_pre_release_accounts(timestamptz)
to service_role;
