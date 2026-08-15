-- Web Push subscriptions and a small delivery outbox for toDō Web.
-- Apply this migration to the production Supabase project before enabling
-- notifications in do.yourtodo.today.

begin;

create table if not exists public.web_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  expiration_time bigint,
  user_agent text,
  is_active boolean not null default true,
  last_success_at timestamptz,
  last_error_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, endpoint)
);

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
  event_label text := case when tg_op = 'INSERT' then 'todo_created' else 'todo_updated' end;
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

commit;
