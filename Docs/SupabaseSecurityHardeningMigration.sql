-- Supabase RLS hardening for ToDo.
-- Apply in Supabase SQL Editor. This migration is idempotent for current known policies.

begin;

-- 1. Remove duplicate/broad policies and recreate authenticated-only policies.

drop policy if exists "Users manage own device tokens" on public.device_tokens;
drop policy if exists "device_tokens_select_own" on public.device_tokens;
drop policy if exists "device_tokens_insert_own" on public.device_tokens;
drop policy if exists "device_tokens_update_own" on public.device_tokens;
drop policy if exists "device_tokens_delete_own" on public.device_tokens;

create policy "device_tokens_select_own"
on public.device_tokens
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "device_tokens_insert_own"
on public.device_tokens
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "device_tokens_update_own"
on public.device_tokens
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "device_tokens_delete_own"
on public.device_tokens
for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "sync_tombstones_select_own" on public.sync_tombstones;
drop policy if exists "sync_tombstones_insert_own" on public.sync_tombstones;
drop policy if exists "sync_tombstones_update_own" on public.sync_tombstones;
drop policy if exists "sync_tombstones_delete_own" on public.sync_tombstones;

create policy "sync_tombstones_select_own"
on public.sync_tombstones
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "sync_tombstones_insert_own"
on public.sync_tombstones
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "sync_tombstones_update_own"
on public.sync_tombstones
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "sync_tombstones_delete_own"
on public.sync_tombstones
for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can view own todos" on public.todos;
drop policy if exists "Users can insert own todos" on public.todos;
drop policy if exists "Users can update own todos" on public.todos;
drop policy if exists "Users can delete own todos" on public.todos;
drop policy if exists "todos_select_own" on public.todos;
drop policy if exists "todos_insert_own" on public.todos;
drop policy if exists "todos_update_own" on public.todos;
drop policy if exists "todos_delete_own" on public.todos;

create policy "todos_select_own"
on public.todos
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "todos_insert_own"
on public.todos
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "todos_update_own"
on public.todos
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "todos_delete_own"
on public.todos
for delete
to authenticated
using ((select auth.uid()) = user_id);

-- 2. Tighten todo_tags so reads/deletes validate both sides of the relationship.

drop policy if exists "todo_tags_select_own" on public.todo_tags;
drop policy if exists "todo_tags_insert_own" on public.todo_tags;
drop policy if exists "todo_tags_delete_own" on public.todo_tags;

create policy "todo_tags_select_own"
on public.todo_tags
for select
to authenticated
using (
  exists (
    select 1
    from public.todos t
    where t.id = todo_tags.todo_id
      and t.user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.tags g
    where g.id = todo_tags.tag_id
      and g.user_id = (select auth.uid())
  )
);

create policy "todo_tags_insert_own"
on public.todo_tags
for insert
to authenticated
with check (
  exists (
    select 1
    from public.todos t
    where t.id = todo_tags.todo_id
      and t.user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.tags g
    where g.id = todo_tags.tag_id
      and g.user_id = (select auth.uid())
  )
);

create policy "todo_tags_delete_own"
on public.todo_tags
for delete
to authenticated
using (
  exists (
    select 1
    from public.todos t
    where t.id = todo_tags.todo_id
      and t.user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.tags g
    where g.id = todo_tags.tag_id
      and g.user_id = (select auth.uid())
  )
);

-- 3. Add service-only policies for service-owned tables that had RLS but no policy.
-- These remain inaccessible to normal clients unless a later feature needs owner-scoped reads.

drop policy if exists "device_push_tokens_service_only" on public.device_push_tokens;
create policy "device_push_tokens_service_only"
on public.device_push_tokens
for all
to service_role
using (true)
with check (true);

drop policy if exists "notification_events_service_only" on public.notification_events;
create policy "notification_events_service_only"
on public.notification_events
for all
to service_role
using (true)
with check (true);

-- 4. Add conservative text length constraints to reduce payload abuse.

alter table public.profiles
  drop constraint if exists profiles_display_name_length_check,
  add constraint profiles_display_name_length_check
    check (display_name is null or char_length(display_name) <= 120),
  drop constraint if exists profiles_username_length_check,
  add constraint profiles_username_length_check
    check (username is null or char_length(username) <= 40),
  drop constraint if exists profiles_given_name_length_check,
  add constraint profiles_given_name_length_check
    check (given_name is null or char_length(given_name) <= 80),
  drop constraint if exists profiles_family_name_length_check,
  add constraint profiles_family_name_length_check
    check (family_name is null or char_length(family_name) <= 80),
  drop constraint if exists profiles_avatar_url_length_check,
  add constraint profiles_avatar_url_length_check
    check (avatar_url is null or char_length(avatar_url) <= 2048),
  drop constraint if exists profiles_preferred_time_zone_length_check,
  add constraint profiles_preferred_time_zone_length_check
    check (preferred_time_zone is null or char_length(preferred_time_zone) <= 80);

alter table public.todos
  drop constraint if exists todos_task_length_check,
  add constraint todos_task_length_check
    check (char_length(task) <= 500),
  drop constraint if exists todos_notes_length_check,
  add constraint todos_notes_length_check
    check (notes is null or char_length(notes) <= 20000);

alter table public.nanodos
  drop constraint if exists nanodos_task_length_check,
  add constraint nanodos_task_length_check
    check (char_length(task) <= 500);

alter table public.tags
  drop constraint if exists tags_name_length_check,
  add constraint tags_name_length_check
    check (char_length(name) between 1 and 80);

alter table public.device_tokens
  drop constraint if exists device_tokens_platform_length_check,
  add constraint device_tokens_platform_length_check
    check (char_length(platform) <= 40),
  drop constraint if exists device_tokens_push_provider_length_check,
  add constraint device_tokens_push_provider_length_check
    check (char_length(push_provider) <= 40),
  drop constraint if exists device_tokens_app_bundle_id_length_check,
  add constraint device_tokens_app_bundle_id_length_check
    check (app_bundle_id is null or char_length(app_bundle_id) <= 255),
  drop constraint if exists device_tokens_environment_length_check,
  add constraint device_tokens_environment_length_check
    check (environment is null or char_length(environment) <= 40);

-- 5. Keep updated_at server-maintained for tables that expose it.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_device_tokens_updated_at on public.device_tokens;
create trigger set_device_tokens_updated_at
before update on public.device_tokens
for each row execute function public.set_updated_at();

drop trigger if exists set_notification_preferences_updated_at on public.notification_preferences;
create trigger set_notification_preferences_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

select pg_notify('pgrst', 'reload schema');

commit;
