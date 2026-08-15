-- Server-authoritative Apple purchase records and account entitlements.
-- Clients may read their own effective entitlements but cannot write commerce state.

create table if not exists public.apple_iap_notification_events (
  notification_uuid text primary key,
  notification_type text not null,
  subtype text,
  environment text not null,
  bundle_id text,
  app_apple_id bigint,
  signed_payload text not null,
  decoded_payload jsonb not null,
  processing_status text not null default 'processing',
  processing_error text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint apple_iap_notification_environment_check
    check (environment in ('Sandbox', 'Production')),
  constraint apple_iap_notification_status_check
    check (processing_status in ('processing', 'processed', 'failed'))
);

create table if not exists public.apple_iap_transactions (
  transaction_id text primary key,
  original_transaction_id text not null,
  web_order_line_item_id text,
  app_account_token uuid,
  account_id uuid references public.profiles(id) on delete set null,
  product_id text not null,
  product_type text,
  bundle_id text not null,
  app_apple_id bigint,
  environment text not null,
  ownership_type text,
  offer_identifier text,
  offer_type integer,
  purchased_at timestamptz,
  original_purchased_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz,
  revocation_reason integer,
  signed_transaction text not null,
  decoded_transaction jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint apple_iap_transaction_environment_check
    check (environment in ('Sandbox', 'Production'))
);

create table if not exists public.apple_purchase_account_links (
  original_transaction_id text not null,
  account_id uuid not null references public.profiles(id) on delete cascade,
  link_kind text not null,
  ownership_type text,
  linked_at timestamptz not null default now(),
  linked_by text not null default 'verified_transaction',
  primary key (original_transaction_id, account_id),
  constraint apple_purchase_link_kind_check
    check (link_kind in ('purchaser', 'family_shared', 'support_recovery'))
);

-- A purchased original transaction has one purchaser account. Family Sharing may
-- grant additional beneficiary links without transferring purchaser ownership.
create unique index if not exists apple_purchase_single_purchaser_idx
on public.apple_purchase_account_links (original_transaction_id)
where link_kind = 'purchaser';

create table if not exists public.account_entitlements (
  account_id uuid not null references public.profiles(id) on delete cascade,
  entitlement_key text not null,
  source_kind text not null,
  source_id text not null,
  source_product_id text,
  source_transaction_id text,
  status text not null,
  ownership_type text,
  granted_at timestamptz not null default now(),
  expires_at timestamptz,
  web_read_only_until timestamptz,
  revoked_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (account_id, entitlement_key, source_kind, source_id),
  constraint account_entitlement_key_check
    check (entitlement_key in ('todo_plus', 'founding_supporter', 'legacy_3_1')),
  constraint account_entitlement_source_check
    check (source_kind in ('apple_iap', 'grandfathering', 'support')),
  constraint account_entitlement_status_check
    check (status in ('active', 'grace', 'expired', 'revoked'))
);

create index if not exists apple_iap_transactions_original_idx
on public.apple_iap_transactions (original_transaction_id);

create index if not exists apple_iap_transactions_account_idx
on public.apple_iap_transactions (account_id, updated_at desc);

create index if not exists apple_iap_transactions_token_idx
on public.apple_iap_transactions (app_account_token)
where app_account_token is not null;

create index if not exists account_entitlements_account_status_idx
on public.account_entitlements (account_id, status, expires_at);

alter table public.apple_iap_notification_events enable row level security;
alter table public.apple_iap_transactions enable row level security;
alter table public.apple_purchase_account_links enable row level security;
alter table public.account_entitlements enable row level security;

drop policy if exists "apple_iap_notifications_service_only" on public.apple_iap_notification_events;
create policy "apple_iap_notifications_service_only"
on public.apple_iap_notification_events
for all
to service_role
using (true)
with check (true);

drop policy if exists "apple_iap_transactions_select_own" on public.apple_iap_transactions;
create policy "apple_iap_transactions_select_own"
on public.apple_iap_transactions
for select
to authenticated
using ((select auth.uid()) = account_id);

drop policy if exists "apple_iap_transactions_service_write" on public.apple_iap_transactions;
create policy "apple_iap_transactions_service_write"
on public.apple_iap_transactions
for all
to service_role
using (true)
with check (true);

drop policy if exists "apple_purchase_links_select_own" on public.apple_purchase_account_links;
create policy "apple_purchase_links_select_own"
on public.apple_purchase_account_links
for select
to authenticated
using ((select auth.uid()) = account_id);

drop policy if exists "apple_purchase_links_service_write" on public.apple_purchase_account_links;
create policy "apple_purchase_links_service_write"
on public.apple_purchase_account_links
for all
to service_role
using (true)
with check (true);

drop policy if exists "account_entitlements_select_own" on public.account_entitlements;
create policy "account_entitlements_select_own"
on public.account_entitlements
for select
to authenticated
using ((select auth.uid()) = account_id);

drop policy if exists "account_entitlements_service_write" on public.account_entitlements;
create policy "account_entitlements_service_write"
on public.account_entitlements
for all
to service_role
using (true)
with check (true);

create or replace view public.current_account_entitlements
with (security_invoker = true)
as
select
  account_id,
  entitlement_key,
  status,
  case
    when status in ('active', 'grace')
      and (expires_at is null or expires_at > now()) then 'full'
    else 'read_only'
  end as access_mode,
  ownership_type,
  expires_at,
  web_read_only_until,
  source_kind,
  source_product_id,
  updated_at
from public.account_entitlements
where (
    status in ('active', 'grace')
    and (expires_at is null or expires_at > now())
  ) or (
    status in ('expired', 'revoked')
    and web_read_only_until > now()
  );

grant select on public.current_account_entitlements to authenticated;
