-- Early adopters receive both Lifetime-equivalent toDō+ access and permanent
-- Founding Supporter recognition. Backfill accounts linked before this policy.

insert into public.account_entitlements (
  account_id,
  entitlement_key,
  source_kind,
  source_id,
  source_product_id,
  source_transaction_id,
  status,
  ownership_type,
  granted_at,
  expires_at,
  web_read_only_until,
  revoked_at,
  updated_at
)
select
  account_id,
  'founding_supporter',
  'grandfathering',
  source_id,
  source_product_id,
  source_transaction_id,
  status,
  ownership_type,
  granted_at,
  null,
  null,
  revoked_at,
  now()
from public.account_entitlements
where entitlement_key = 'legacy_3_1'
on conflict (account_id, entitlement_key, source_kind, source_id)
do update set
  status = excluded.status,
  ownership_type = excluded.ownership_type,
  revoked_at = excluded.revoked_at,
  updated_at = excluded.updated_at;
