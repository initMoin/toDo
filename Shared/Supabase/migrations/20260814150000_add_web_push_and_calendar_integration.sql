-- Web Push delivery and a private calendar feed for toDō Web.
--
-- Browser push subscriptions and calendar feed tokens are user-owned. The
-- delivery/feed Edge Functions use service_role only after validating their
-- own webhook or feed token; no privileged key belongs in browser code.

create table if not exists public.web_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  expiration_time bigint,
  user_agent text,
  timezone text not null default 'UTC',
  is_active boolean not null default true,
  last_seen_at timestamptz,
  last_success_at timestamptz,
  last_error_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, endpoint)
);

alter table public.web_push_subscriptions
  add column if not exists timezone text not null default 'UTC',
  add column if not exists last_seen_at timestamptz;

create index if not exists web_push_subscriptions_user_active_idx
  on public.web_push_subscriptions (user_id, is_active);

alter table public.web_push_subscriptions enable row level security;

drop policy if exists "web_push_subscriptions_select_own" on public.web_push_subscriptions;
drop policy if exists "web_push_subscriptions_insert_own" on public.web_push_subscriptions;
drop policy if exists "web_push_subscriptions_update_own" on public.web_push_subscriptions;
drop policy if exists "web_push_subscriptions_delete_own" on public.web_push_subscriptions;

create policy "web_push_subscriptions_select_own"
on public.web_push_subscriptions
for select to authenticated
using ((select auth.uid()) = user_id);

create policy "web_push_subscriptions_insert_own"
on public.web_push_subscriptions
for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "web_push_subscriptions_update_own"
on public.web_push_subscriptions
for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "web_push_subscriptions_delete_own"
on public.web_push_subscriptions
for delete to authenticated
using ((select auth.uid()) = user_id);

create table if not exists public.web_push_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  attempts integer not null default 0,
  last_error text
);

create index if not exists web_push_events_delivery_idx
  on public.web_push_events (processed_at, created_at);

alter table public.web_push_events enable row level security;
drop policy if exists "web_push_events_service_only" on public.web_push_events;
create policy "web_push_events_service_only"
on public.web_push_events
for all to service_role
using (true)
with check (true);

create or replace function public.set_web_push_subscription_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_web_push_subscription_updated_at on public.web_push_subscriptions;
create trigger set_web_push_subscription_updated_at
before update on public.web_push_subscriptions
for each row execute function public.set_web_push_subscription_updated_at();

create or replace function public.enqueue_web_push_for_todo_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_user_id uuid;
  event_label text := case
    when tg_op = 'INSERT' then 'todo_created'
    when new.is_done then 'todo_completed'
    else 'todo_updated'
  end;
  event_payload jsonb := jsonb_build_object(
    'todo_id', new.id,
    'task', new.task,
    'collab_id', new.collab_id,
    'is_done', new.is_done,
    'due_at', new.due_at
  );
begin
  if new.collab_id is null then
    insert into public.web_push_events (user_id, event_type, payload)
    values (new.user_id, event_label, event_payload);
  else
    for target_user_id in
      select collab_user.user_id
      from public.collab_users collab_user
      where collab_user.collab_id = new.collab_id
    loop
      insert into public.web_push_events (user_id, event_type, payload)
      values (target_user_id, event_label, event_payload);
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists enqueue_web_push_after_todo_change on public.todos;
create trigger enqueue_web_push_after_todo_change
after insert or update of task, notes, is_done, due_at, collab_id on public.todos
for each row execute function public.enqueue_web_push_for_todo_change();

create or replace function public.invoke_todo_web_push_webhook()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  webhook_url text;
  webhook_secret text;
begin
  select nullif(btrim(secret.decrypted_secret), '')
    into webhook_url
    from vault.decrypted_secrets secret
    where secret.name = 'todo_web_push_webhook_url'
    order by secret.updated_at desc
    limit 1;

  select nullif(btrim(secret.decrypted_secret), '')
    into webhook_secret
    from vault.decrypted_secrets secret
    where secret.name = 'todo_web_push_webhook_secret'
    order by secret.updated_at desc
    limit 1;

  if webhook_url is null or webhook_secret is null then
    raise warning 'Skipped todo-web-push webhook: required Vault configuration is missing';
    return new;
  end if;

  perform net.http_post(
    url := webhook_url,
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'web_push_events',
      'schema', 'public',
      'record', to_jsonb(new),
      'old_record', null
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-ToDo-Webhook-Secret', webhook_secret
    ),
    timeout_milliseconds := 5000
  );

  return new;
exception
  when others then
    raise warning 'Failed to enqueue todo-web-push webhook request: %', sqlerrm;
    return new;
end;
$$;

revoke all on function public.invoke_todo_web_push_webhook() from public, anon, authenticated;

drop trigger if exists todo_web_push_webhook on public.web_push_events;
create trigger todo_web_push_webhook
after insert on public.web_push_events
for each row execute function public.invoke_todo_web_push_webhook();

create table if not exists public.web_push_reminder_deliveries (
  user_id uuid not null references auth.users(id) on delete cascade,
  todo_id uuid not null references public.todos(id) on delete cascade,
  due_at timestamptz not null,
  delivered_at timestamptz not null default now(),
  primary key (user_id, todo_id, due_at)
);

alter table public.web_push_reminder_deliveries enable row level security;
drop policy if exists "web_push_reminder_deliveries_service_only" on public.web_push_reminder_deliveries;
create policy "web_push_reminder_deliveries_service_only"
on public.web_push_reminder_deliveries
for all to service_role
using (true)
with check (true);

create or replace function public.enqueue_due_web_push_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  todo_record record;
  target_user_id uuid;
  enqueued_count integer := 0;
begin
  for todo_record in
    select id, user_id, collab_id, task, due_at
    from public.todos
    where not is_done
      and due_at is not null
      and due_at <= now()
      and due_at > now() - interval '7 days'
      and coalesce(lifecycle_state, 'active') not in ('archived', 'trashed')
      and coalesce(reminder_intent, 'soft') in ('soft', 'due', 'timeSensitive')
  loop
    if todo_record.collab_id is null then
      target_user_id := todo_record.user_id;
      insert into public.web_push_reminder_deliveries (user_id, todo_id, due_at)
      values (target_user_id, todo_record.id, todo_record.due_at)
      on conflict do nothing;
      if found then
        insert into public.web_push_events (user_id, event_type, payload)
        values (
          target_user_id,
          'todo_due',
          jsonb_build_object(
            'todo_id', todo_record.id,
            'task', todo_record.task,
            'collab_id', null,
            'is_done', false,
            'due_at', todo_record.due_at
          )
        );
        enqueued_count := enqueued_count + 1;
      end if;
    else
      for target_user_id in
        select collab_user.user_id
        from public.collab_users collab_user
        where collab_user.collab_id = todo_record.collab_id
      loop
        insert into public.web_push_reminder_deliveries (user_id, todo_id, due_at)
        values (target_user_id, todo_record.id, todo_record.due_at)
        on conflict do nothing;
        if found then
          insert into public.web_push_events (user_id, event_type, payload)
          values (
            target_user_id,
            'todo_due',
            jsonb_build_object(
              'todo_id', todo_record.id,
              'task', todo_record.task,
              'collab_id', todo_record.collab_id,
              'is_done', false,
              'due_at', todo_record.due_at
            )
          );
          enqueued_count := enqueued_count + 1;
        end if;
      end loop;
    end if;
  end loop;

  return enqueued_count;
end;
$$;

revoke all on function public.enqueue_due_web_push_events() from public, anon, authenticated;
grant execute on function public.enqueue_due_web_push_events() to service_role;

do $schedule$
declare
  existing_job_id bigint;
begin
  if to_regprocedure('cron.schedule(text,text,text)') is null then
    raise notice 'pg_cron is unavailable; Web Push due reminders remain event-triggered only';
    return;
  end if;

  for existing_job_id in
    execute 'select jobid from cron.job where jobname = $1'
    using 'todo-web-push-due-reminders'
  loop
    execute 'select cron.unschedule($1)' using existing_job_id;
  end loop;

  execute $cron$
    select cron.schedule(
      'todo-web-push-due-reminders',
      '* * * * *',
      'select public.enqueue_due_web_push_events();'
    )
  $cron$;
end;
$schedule$;

alter table public.notification_preferences
  add column if not exists web_reminders_enabled boolean not null default true,
  add column if not exists web_reminder_sound text not null default 'default',
  add column if not exists web_custom_sound_name text,
  add column if not exists web_completion_sound text not null default 'off',
  add column if not exists web_badge_policy text not null default 'overdue',
  add column if not exists web_snooze_options jsonb not null default '{"minutes":[5,15,30],"hours":[1,2],"days":[1]}'::jsonb;

create table if not exists public.web_calendar_feeds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  last_accessed_at timestamptz,
  revoked_at timestamptz
);

create index if not exists web_calendar_feeds_user_active_idx
  on public.web_calendar_feeds (user_id, revoked_at);

alter table public.web_calendar_feeds enable row level security;
drop policy if exists "web_calendar_feeds_select_own" on public.web_calendar_feeds;
create policy "web_calendar_feeds_select_own"
on public.web_calendar_feeds
for select to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.create_web_calendar_feed_token()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  requesting_user_id uuid := auth.uid();
  raw_token text;
begin
  if requesting_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  raw_token := rtrim(
    replace(replace(encode(gen_random_bytes(32), 'base64'), '+', '-'), '/', '_'),
    '='
  );

  update public.web_calendar_feeds
  set revoked_at = now()
  where user_id = requesting_user_id
    and revoked_at is null;

  insert into public.web_calendar_feeds (user_id, token_hash)
  values (
    requesting_user_id,
    encode(digest(raw_token, 'sha256'), 'hex')
  );

  return raw_token;
end;
$$;

create or replace function public.revoke_web_calendar_feed()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.web_calendar_feeds
  set revoked_at = now()
  where user_id = auth.uid()
    and revoked_at is null;
end;
$$;

revoke all on function public.create_web_calendar_feed_token() from public, anon;
revoke all on function public.revoke_web_calendar_feed() from public, anon;
grant execute on function public.create_web_calendar_feed_token() to authenticated;
grant execute on function public.revoke_web_calendar_feed() to authenticated;

comment on table public.web_push_subscriptions is
  'Browser Push API subscriptions owned by one toDō account.';
comment on table public.web_calendar_feeds is
  'Revocable hashed tokens for private iCalendar feeds.';
