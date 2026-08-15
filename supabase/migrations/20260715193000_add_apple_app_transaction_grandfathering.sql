-- Binds an Apple-signed app acquisition to one toDō account. The Edge Function
-- uses this evidence to grant permanent toDō+ access to verified pre-3.1 users.

create table if not exists public.apple_app_transaction_links (
  app_transaction_id text primary key,
  account_id uuid not null references public.profiles(id) on delete cascade,
  bundle_id text not null,
  app_apple_id bigint,
  environment text not null,
  original_purchased_at timestamptz not null,
  original_app_version text,
  original_platform text,
  signed_app_transaction text not null,
  decoded_app_transaction jsonb not null,
  linked_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint apple_app_transaction_environment_check
    check (environment in ('Sandbox', 'Production'))
);

create index if not exists apple_app_transaction_account_idx
on public.apple_app_transaction_links (account_id, linked_at desc);

alter table public.apple_app_transaction_links enable row level security;

drop policy if exists "apple_app_transaction_links_select_own"
on public.apple_app_transaction_links;
create policy "apple_app_transaction_links_select_own"
on public.apple_app_transaction_links
for select
to authenticated
using ((select auth.uid()) = account_id);

drop policy if exists "apple_app_transaction_links_service_write"
on public.apple_app_transaction_links;
create policy "apple_app_transaction_links_service_write"
on public.apple_app_transaction_links
for all
to service_role
using (true)
with check (true);
