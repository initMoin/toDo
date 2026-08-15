-- Shared APNs provider-token cache for Edge Functions.
-- APNs rejects providers that rotate JWT provider tokens too frequently, and
-- Supabase can run multiple Edge Function instances in parallel. Persisting the
-- JWT lets separate invocations reuse the exact same provider token string.

create table if not exists public.apns_provider_auth_tokens (
  cache_key text primary key,
  token text not null,
  issued_at timestamptz not null,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);

alter table public.apns_provider_auth_tokens enable row level security;

drop policy if exists "apns_provider_auth_tokens_service_only" on public.apns_provider_auth_tokens;
create policy "apns_provider_auth_tokens_service_only"
on public.apns_provider_auth_tokens
for all
to service_role
using (true)
with check (true);

create index if not exists apns_provider_auth_tokens_expires_at_idx
on public.apns_provider_auth_tokens (expires_at);

create or replace function public.delete_expired_apns_provider_auth_tokens()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer;
begin
  delete from public.apns_provider_auth_tokens
  where expires_at < now();

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;
