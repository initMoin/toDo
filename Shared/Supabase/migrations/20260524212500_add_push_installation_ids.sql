-- Track the physical app install that registered each APNs token.
-- This prevents repeated TestFlight/debug installs from accumulating stale
-- active tokens that all receive the same sync and Live Activity pushes.

alter table public.device_tokens
  add column if not exists installation_id text;

alter table public.live_activity_tokens
  add column if not exists installation_id text;

create index if not exists device_tokens_installation_idx
on public.device_tokens(user_id, installation_id, platform, push_provider, environment, is_active);

create index if not exists live_activity_tokens_installation_idx
on public.live_activity_tokens(user_id, installation_id, token_type, environment, is_active);
