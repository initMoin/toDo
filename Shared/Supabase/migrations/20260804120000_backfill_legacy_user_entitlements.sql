-- Grant the complete 3.1 legacy package to every account that exists when this
-- migration is applied. Future accounts receive no rows automatically.
--
-- The active entitlement rows are the server-owned eligibility flag:
--   legacy_3_1         = lifetime toDō+ access
--   founding_supporter = recognition tag/title
--
-- This migration is intentionally idempotent and does not rely on client claims
-- or Apple transaction verification.

insert into public.account_entitlements (
  account_id,
  entitlement_key,
  source_kind,
  source_id,
  status,
  ownership_type,
  granted_at,
  updated_at
)
select
  profile.id,
  entitlement.entitlement_key,
  'grandfathering',
  'pre_3_1_snapshot_20260804',
  'active',
  'PRE_3_1_LEGACY_USER',
  now(),
  now()
from public.profiles as profile
cross join (
  values
    ('legacy_3_1'::text),
    ('founding_supporter'::text)
) as entitlement(entitlement_key)
on conflict (account_id, entitlement_key, source_kind, source_id)
do update set
  status = 'active',
  ownership_type = 'PRE_3_1_LEGACY_USER',
  revoked_at = null,
  updated_at = now();
